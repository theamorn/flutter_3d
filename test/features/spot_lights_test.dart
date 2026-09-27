import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/features/interaction_registry.dart';
import 'package:flutter_3d/features/spot_lights_feature.dart';
import 'package:flutter_3d/hotel/hotel_context.dart';
import 'package:flutter_3d/math/floor_plan.dart';

class _Context extends Fake implements HotelContext {
  @override
  final Map<RoomId, Node> rooms = {};
  @override
  final InteractionRegistry interactions = InteractionRegistry();
  @override
  final ValueNotifier<int> lightingRevision = ValueNotifier(0);
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
  ..add(Node(name: 'reading_light_left')..add(Node(name: 'reading_light_shade')))
  ..add(Node(name: 'reading_light_right')..add(Node(name: 'reading_light_shade')));

HotelContext rooms() => _Context()
  ..rooms[RoomId.a] = (Node(name: 'room_a')..add(fixtures()))
  ..rooms[RoomId.b] = (Node(name: 'room_b', localTransform: Matrix4.diagonal3Values(-1, 1, 1))
    ..add(fixtures()));

SpotLightComponent spot(Node fixture) => fixture.children
    .firstWhere((c) => c.name == 'reading_light_source')
    .getComponent<SpotLightComponent>()!;

void main() {
  test('four shadowed reading lights, each aimed into its own room', () async {
    final ctx = rooms();
    await SpotLightsFeature().mount(ctx);
    final a = ctx.nodesNamed('reading_light_left').first;
    final b = ctx.nodesNamed('reading_light_left').last;
    expect(spot(a).light.castsShadow, isTrue);
    expect(spot(a).worldDirection.y, lessThan(0), reason: 'down at the pillows');
    expect(spot(a).worldDirection.x, greaterThan(0), reason: 'room A: away from the x = −8 wall');
    expect(spot(b).worldDirection.x, lessThan(0), reason: 'room B mirrored: away from x = +8');
    expect(ctx.interactions.all, hasLength(4));
  });

  test('a tap switches one light and bumps the lighting revision', () async {
    final ctx = rooms();
    await SpotLightsFeature().mount(ctx);
    final tap = ctx.interactions.all.first;
    final light = spot(tap.node).light;
    expect(light.intensity, 6);
    expect(ctx.lightingRevision.value, 1, reason: 'adding the lights invalidates probes');
    tap.onTap();
    expect(light.intensity, 0);
    expect(ctx.lightingRevision.value, 2);
  });

  test('mount and unmount bump the lighting revision for probe recapture', () async {
    final ctx = rooms();
    final f = SpotLightsFeature();
    await f.mount(ctx);
    expect(ctx.lightingRevision.value, 1);
    f.unmount(ctx);
    expect(ctx.lightingRevision.value, 2);
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
