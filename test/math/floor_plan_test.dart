import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/math/floor_plan.dart';
import 'package:flutter_3d/math/colliders.dart';

void main() {
  test('roomOf splits at x=0', () {
    expect(FloorPlan.roomOf(Vector2(-0.1, 3)), RoomId.a);
    expect(FloorPlan.roomOf(Vector2(0.1, 3)), RoomId.b);
  });

  test('colliders are symmetric in x', () {
    final boxes = FloorPlan.staticColliders();
    for (final b in boxes) {
      final m = b.mirrored();
      expect(boxes.any((o) =>
          (o.minX - m.minX).abs() < 1e-9 && (o.maxX - m.maxX).abs() < 1e-9 &&
          (o.minZ - m.minZ).abs() < 1e-9 && (o.maxZ - m.maxZ).abs() < 1e-9), true,
          reason: 'missing mirror of $b');
    }
  });

  test('you can walk from room A to room B through the open door gap', () {
    var p = Vector2(-1.0, 2.45);
    for (var i = 0; i < 40; i++) {
      p = moveCircle(p, p + Vector2(0.05, 0), 0.25, FloorPlan.staticColliders());
    }
    expect(p.x, greaterThan(0.5));
  });

  test('you cannot walk through the shared wall outside the door', () {
    var p = Vector2(-1.0, 4.5);
    for (var i = 0; i < 40; i++) {
      p = moveCircle(p, p + Vector2(0.05, 0), 0.25, FloorPlan.staticColliders());
    }
    expect(p.x, lessThan(0));
  });

  test('balcony railing keeps you inside z < 7.8', () {
    var p = Vector2(-4, 6.5);
    for (var i = 0; i < 60; i++) {
      p = moveCircle(p, p + Vector2(0, 0.05), 0.25, FloorPlan.staticColliders());
    }
    expect(p.y, lessThan(7.8));
  });

  test('staticColliders = room A walls + furniture, their mirrors, and the shared wall', () {
    expect(FloorPlan.staticColliders().length,
        2 * (FloorPlan.wallsA.length + FloorPlan.furnitureA.length) + FloorPlan.sharedWall.length);
  });

  test('the entrance door is clear of furniture', () {
    // Design: door_entrance on the corridor wall (z = 0), x ∈ [−2.3, −1.3].
    for (final e in FloorPlan.furnitureA.entries) {
      final b = e.value;
      final blocks = b.maxX > FloorPlan.entranceX0 && b.minX < FloorPlan.entranceX1 && b.minZ < 0.6;
      expect(blocks, false, reason: '${e.key} $b stands in front of the entrance door');
    }
  });
}
