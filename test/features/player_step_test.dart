import 'dart:math' as math;
import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/features/player_feature.dart';
import 'package:flutter_3d/math/colliders.dart';
import 'package:flutter_3d/math/floor_plan.dart';
import 'package:flutter_3d/math/fp_movement.dart';

/// Holds [stick] for [seconds] at 60 fps.
FpState walk(FpState s, Offset stick, double seconds,
    {Map<String, List<Box2>> dynamic = const {}}) {
  for (var i = 0; i < (seconds * 60).round(); i++) {
    s = stepPlayer(s,
        stick: stick, look: Offset.zero, dt: 1 / 60, colliders: playerColliders(dynamic));
  }
  return s;
}

void main() {
  test('pushing the stick up from the spawn point walks toward the window', () {
    final s = walk(FpState(Vector2(-4, 3), 0, 0), const Offset(0, 1), 0.5);
    expect(s.xz.x, closeTo(-4, 1e-6));
    expect(s.xz.y, closeTo(3 + kWalkSpeed * 0.5, 1e-4));
  });

  test('walking diagonally into the bed slides along it and never enters it', () {
    final bed = FloorPlan.furnitureA['bed']!;
    // Facing between −X (the bed) and +Z (the window).
    var s = FpState(Vector2(bed.maxX + 0.4, 3.6), -math.pi / 4, 0);
    s = walk(s, const Offset(0, 1), 1.5);
    expect(s.xz.x, greaterThanOrEqualTo(bed.maxX + kPlayerRadius - 1e-4));
    expect(s.xz.y, greaterThan(3.6 + 0.5), reason: 'slid along the bed toward +Z');
  });

  test('the look drag is applied before the step', () {
    // Drag right a quarter turn, then walk: the step goes toward +X.
    final s = stepPlayer(FpState(Vector2(-4, 3), 0, 0),
        stick: const Offset(0, 1),
        look: const Offset(math.pi / 2 / kLookSensitivity, 0),
        dt: 0.1,
        colliders: playerColliders(const {}));
    expect(s.yaw, closeTo(math.pi / 2, 1e-9));
    expect(s.xz.x, closeTo(-4 + kWalkSpeed * 0.1, 1e-4));
    expect(s.xz.y, closeTo(3, 1e-4));
  });

  test('dynamic colliders (a closed door leaf) block the doorway', () {
    const door = Box2(-0.05, FloorPlan.doorZ0, 0.05, FloorPlan.doorZ1);
    final start = FpState(Vector2(-1, 2.45), math.pi / 2, 0); // facing +X
    final open = walk(start, const Offset(0, 1), 2);
    final closed = walk(start, const Offset(0, 1), 2, dynamic: {'door': [door]});
    expect(open.xz.x, greaterThan(0.5), reason: 'through the open gap into room B');
    expect(closed.xz.x, lessThanOrEqualTo(-0.05 - kPlayerRadius + 1e-4));
  });

  test('the camera sits at eye height and looks along the facing', () {
    final cam = PerspectiveCamera();
    final s = FpState(Vector2(-2, 4), 0.3, -0.2);
    aimCamera(cam, s);
    expect((cam.position - Vector3(-2, FloorPlan.eyeHeight, 4)).length, lessThan(1e-6));
    expect(((cam.target - cam.position) - forwardOf(0.3, -0.2)).length, lessThan(1e-6));
  });
}
