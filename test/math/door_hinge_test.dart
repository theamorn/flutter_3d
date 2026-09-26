import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/math/door_hinge.dart';
import 'package:flutter_3d/math/floor_plan.dart';
import 'package:flutter_3d/math/colliders.dart';
import 'package:flutter_3d/features/player_feature.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  test('hinge reaches 100 degrees in about 0.7 seconds and stays there', () {
    var angle = 0.0;
    for (var i = 0; i < 42; i++) {
      angle = stepHinge(angle, true, 1 / 60);
    }
    expect(angle, kDoorOpenAngle);
    expect(stepHinge(angle, true, 1), kDoorOpenAngle);
  });

  test('hinge closes without crossing zero', () {
    var angle = kDoorOpenAngle;
    for (var i = 0; i < 42; i++) {
      angle = stepHinge(angle, false, 1 / 60);
    }
    expect(angle, 0);
    expect(stepHinge(angle, false, 1), 0);
  });

  test('collider blocks the doorway until the leaf clears 60 degrees', () {
    final closed = doorColliders(0).single;
    expect(closed.minX, -0.05);
    expect(closed.maxX, 0.05);
    expect(closed.minZ, FloorPlan.doorZ0);
    expect(closed.maxZ, FloorPlan.doorZ1);
    expect(doorColliders(59 * degrees2Radians), isNotEmpty);
    expect(doorColliders(60 * degrees2Radians), isEmpty);
    expect(doorColliders(kDoorOpenAngle), isEmpty);
  });

  test('a stationary player in the closing leaf is pushed to their side', () {
    final closing = doorColliders(59 * degrees2Radians);
    final a = moveCircle(
      Vector2(-0.02, 2.45),
      Vector2(-0.02, 2.45),
      kPlayerRadius,
      closing,
    );
    final b = moveCircle(
      Vector2(0.02, 2.45),
      Vector2(0.02, 2.45),
      kPlayerRadius,
      closing,
    );
    expect(a.x, lessThanOrEqualTo(-0.05 - kPlayerRadius + 1e-6));
    expect(b.x, greaterThanOrEqualTo(0.05 + kPlayerRadius - 1e-6));
  });
}
