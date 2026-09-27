import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/features/area_lights_feature.dart';
import 'package:flutter_3d/features/sky_feature.dart';
import 'package:flutter_3d/hotel/hotel_context.dart';
import 'package:flutter_3d/math/floor_plan.dart';

class _Context extends Fake implements HotelContext {
  @override
  final Map<RoomId, Node> rooms = {};
  @override
  final ValueNotifier<double> timeOfDay = ValueNotifier(15);
  @override
  final ValueNotifier<int> lightingRevision = ValueNotifier(0);
  @override
  double weather = 0;
  @override
  List<Node> nodesNamed(String name) {
    final out = <Node>[];
    void walk(Node n) {
      if (n.name == name) out.add(n);
      for (final c in n.children) {
        walk(c);
      }
    }

    for (final r in rooms.values) {
      walk(r);
    }
    return out;
  }
}

/// Room A at identity; room B a `room` child under an x-mirror, as the
/// rooms feature builds them. Each contents node has more than one child,
/// like the real rooms, so `roomContentsRoot` stops there.
_Context _rooms() {
  Node contents(String name) => Node(name: name)
    ..add(Node(name: 'tv_screen'))
    ..add(Node(name: 'bed'));
  final ctx = _Context();
  ctx.rooms[RoomId.a] = contents('room_a');
  ctx.rooms[RoomId.b] = Node(name: 'room_b', localTransform: Matrix4.diagonal3Values(-1, 1, 1))
    ..add(contents('room'));
  return ctx;
}

void main() {
  test('night is dim, storms dim the day', () {
    expect(windowLightIntensity(0.012, 0), lessThan(windowLightIntensity(1, 0) * 0.05));
    expect(windowLightIntensity(1, 1), closeTo(windowLightIntensity(1, 0) * 0.4, 1e-9));
  });

  test('window lights sit in each window and shine into their own room', () async {
    final ctx = _rooms();
    final f = AreaLightsFeature();
    await f.mount(ctx);
    final windows = ctx.nodesNamed('window_light');
    expect(windows, hasLength(2));
    for (final w in windows) {
      final m = w.globalTransform;
      final pos = m.getTranslation();
      expect(pos.z, closeTo(FloorPlan.roomDepth - 0.02, 1e-6));
      final facing = (m.getRotation() * Vector3(0, 0, 1)) as Vector3;
      expect(facing.z, lessThan(-0.99), reason: 'emits along local +Z, turned to face into the room');
    }
    expect(windows.map((w) => w.globalTransform.getTranslation().x.sign).toSet(), {-1.0, 1.0});
    expect(ctx.nodesNamed('tv_glow'), hasLength(2));
    expect(ctx.lightingRevision.value, 1, reason: 'adding lights invalidates probe captures');
    f.unmount(ctx);
    expect(ctx.nodesNamed('window_light'), isEmpty);
    expect(ctx.nodesNamed('tv_glow'), isEmpty);
    expect(ctx.lightingRevision.value, 2, reason: 'removing lights invalidates probe captures');
  });

  test('the window light follows the time of day', () async {
    final ctx = _rooms();
    final f = AreaLightsFeature();
    await f.mount(ctx);
    RectAreaLight light() =>
        ctx.nodesNamed('window_light').first.getComponent<RectAreaLightComponent>()!.light;
    final day = light().intensity;
    expect(day, greaterThan(0));
    ctx.timeOfDay.value = 23;
    f.tick(ctx, 0.016);
    expect(light().intensity, lessThan(day * 0.05));
  });

  test('the window light colour follows the sky, tinted by the window glass', () async {
    final ctx = _rooms();
    final f = AreaLightsFeature();
    await f.mount(ctx);
    RectAreaLight light() =>
        ctx.nodesNamed('window_light').first.getComponent<RectAreaLightComponent>()!.light;
    Vector3 expectedAt(double hours) {
      final sky = skyAt(hours).lightColor;
      return Vector3(sky.x * kWindowLightColor.x, sky.y * kWindowLightColor.y,
          sky.z * kWindowLightColor.z);
    }

    final day = light().color.clone();
    final expectedDay = expectedAt(15);
    expect(day.x, closeTo(expectedDay.x, 1e-6));
    expect(day.y, closeTo(expectedDay.y, 1e-6));
    expect(day.z, closeTo(expectedDay.z, 1e-6));

    ctx.timeOfDay.value = 23;
    f.tick(ctx, 0.016);
    final night = light().color;
    final expectedNight = expectedAt(23);
    expect(night.x, closeTo(expectedNight.x, 1e-6));
    expect(night.y, closeTo(expectedNight.y, 1e-6));
    expect(night.z, closeTo(expectedNight.z, 1e-6));
    expect((night - day).length, greaterThan(0.01));
  });
}
