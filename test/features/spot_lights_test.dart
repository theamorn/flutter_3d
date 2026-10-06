import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/render/shadow_channels.dart';
import 'package:flutter_3d/features/interaction_registry.dart';
import 'package:flutter_3d/features/spot_lights_feature.dart';
import 'package:flutter_3d/hotel/hotel_context.dart';
import 'package:flutter_3d/math/floor_plan.dart';

class _Context extends Fake implements HotelContext {
  @override
  int shadowCasterOverflowCount = 0;
  @override
  final Map<RoomId, Node> rooms = {};
  @override
  final InteractionRegistry interactions = InteractionRegistry();
  @override
  int fixtureCasterMask = kFixtureExcludedCasterMask;
  @override
  final ValueNotifier<int> lightingRevision = ValueNotifier(0);
  @override
  final PerspectiveCamera camera = PerspectiveCamera(
    position: Vector3(-4, 1.6, 3),
  );
  @override
  List<Node> nodesNamed(String name) {
    final out = <Node>[];
    void walk(Node n) {
      if (n.name == name) out.add(n);
      for (final c in n.children) {
        walk(c);
      }
    }

    for (final id in RoomId.values) {
      final r = rooms[id];
      if (r != null) walk(r);
    }
    return out;
  }
}

Node fixtures() => Node(name: 'room')
  ..add(
    Node(name: 'reading_light_left')..add(Node(name: 'reading_light_shade')),
  )
  ..add(
    Node(name: 'reading_light_right')..add(Node(name: 'reading_light_shade')),
  );

HotelContext rooms() => _Context()
  ..rooms[RoomId.a] = (Node(name: 'room_a')..add(fixtures()))
  ..rooms[RoomId.b] = (Node(
    name: 'room_b',
    localTransform: Matrix4.diagonal3Values(-1, 1, 1),
  )..add(fixtures()));

SpotLightComponent spot(Node fixture) => fixture.children
    .firstWhere((c) => c.name == 'reading_light_source')
    .getComponent<SpotLightComponent>()!;

void main() {
  test('overflow logging reports changes once, including recovery', () {
    final ctx = _Context();
    final feature = SpotLightsFeature();
    final messages = <String?>[];
    final previous = debugPrint;
    debugPrint = (message, {wrapWidth}) => messages.add(message);
    try {
      feature.tick(ctx, 0.016);
      ctx.shadowCasterOverflowCount = 2;
      feature.tick(ctx, 0.016);
      feature.tick(ctx, 0.016);
      ctx.shadowCasterOverflowCount = 0;
      feature.tick(ctx, 0.016);
      expect(messages, [
        'spot lights: 2 shadowed light(s) over the atlas cap',
        'spot lights: 0 shadowed light(s) over the atlas cap',
      ]);
    } finally {
      debugPrint = previous;
    }
  });

  test(
    'the reading lights are small bulbs with a shadow frustum on the core',
    () {
      expect(kReadingBulbRadius, closeTo(0.03, 1e-9));
      expect(kReadingShadowFov, lessThan(2 * kReadingLightOuter * 1.05));
      expect(kReadingShadowFov, greaterThan(2 * kReadingLightInner));
    },
  );

  test('reading lights leave their own shade out of the shadow map', () async {
    final ctx = rooms();
    final feature = SpotLightsFeature();
    await feature.mount(ctx);
    for (final fixture in ctx.nodesNamed('reading_light_left')) {
      expect(spot(fixture).light.shadowCasterChannelMask, kFixtureExcludedCasterMask);
      expect(spot(fixture).light.channelMask, kDirectLightMask);
    }
    ctx.fixtureCasterMask = kIncludeFixtureCasterMask;
    feature.tick(ctx, 0.016);
    for (final fixture in ctx.nodesNamed('reading_light_left')) {
      expect(spot(fixture).light.shadowCasterChannelMask, kIncludeFixtureCasterMask);
    }
    feature.unmount(ctx);
  });

  test('four shadowed reading lights, each aimed into its own room', () async {
    final ctx = rooms();
    await SpotLightsFeature().mount(ctx);
    final a = ctx.nodesNamed('reading_light_left').first;
    final b = ctx.nodesNamed('reading_light_left').last;
    expect(spot(a).light.radius, 0.03);
    expect(spot(a).light.shadowFieldOfView, 1.0);
    expect(spot(a).light.castsShadow, isTrue);
    expect(
      spot(a).worldDirection.y,
      lessThan(0),
      reason: 'down at the pillows',
    );
    expect(
      spot(a).worldDirection.x,
      greaterThan(0),
      reason: 'room A: away from the x = −8 wall',
    );
    expect(
      spot(b).worldDirection.x,
      lessThan(0),
      reason: 'room B mirrored: away from x = +8',
    );
    expect(ctx.interactions.all, hasLength(4));
  });

  test('a tap switches one light and bumps the lighting revision', () async {
    final ctx = rooms();
    await SpotLightsFeature().mount(ctx);
    final tap = ctx.interactions.all.first;
    final light = spot(tap.node).light;
    expect(light.intensity, 6);
    expect(
      ctx.lightingRevision.value,
      1,
      reason: 'adding the lights invalidates probes',
    );
    tap.onTap();
    expect(light.intensity, 0);
    expect(ctx.lightingRevision.value, 2);
  });

  test(
    'mount and unmount bump the lighting revision for probe recapture',
    () async {
      final ctx = rooms();
      final f = SpotLightsFeature();
      await f.mount(ctx);
      expect(ctx.lightingRevision.value, 1);
      f.unmount(ctx);
      expect(ctx.lightingRevision.value, 2);
    },
  );

  test('only the camera room\'s reading lights cast shadows', () async {
    // Keep shadows in the camera room to save work for hidden lights.
    final ctx = rooms();
    final f = SpotLightsFeature();
    await f.mount(ctx);
    List<bool> shadowed(RoomId id) => [
      for (final name in ['reading_light_left', 'reading_light_right'])
        spot(ctx.nodesNamed(name)[id.index]).light.castsShadow,
    ];
    expect(shadowed(RoomId.a), [true, true]);
    expect(shadowed(RoomId.b), [false, false]);

    ctx.camera.position.setValues(4, 1.6, 3); // walk into room B
    f.tick(ctx, 0.016);
    expect(shadowed(RoomId.a), [false, false]);
    expect(shadowed(RoomId.b), [true, true]);
  });

  test('unmount removes the lights and the taps', () async {
    final ctx = rooms();
    final f = SpotLightsFeature();
    await f.mount(ctx);
    f.unmount(ctx);
    expect(ctx.nodesNamed('reading_light_source'), isEmpty);
    expect(ctx.interactions.all, isEmpty);
  });
}
