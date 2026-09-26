import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/math/fp_movement.dart';

void main() {
  test('yaw 0 looks +Z, yaw +90° looks +X', () {
    final f0 = forwardOf(0, 0);
    expect(f0.z, closeTo(1, 1e-9));
    final f90 = forwardOf(math.pi / 2, 0);
    expect(f90.x, closeTo(1, 1e-9));
  });

  test('full forward stick for 1 s moves kWalkSpeed along forward', () {
    final s = FpState(Vector2(0, 0), 0, 0);
    final p = desiredStep(s, const Offset(0, 1), 1.0);
    expect(p.y, closeTo(kWalkSpeed, 1e-6)); // Vector2 is float32
    expect(p.x, closeTo(0, 1e-9));
  });

  test('strafe right at yaw 0 moves toward -X (right-hand when facing +Z)', () {
    final p = desiredStep(FpState(Vector2(0, 0), 0, 0), const Offset(1, 0), 1.0);
    expect(p.x, closeTo(-kWalkSpeed, 1e-6)); // Vector2 is float32
  });

  test('diagonal stick is not faster than full stick', () {
    final p = desiredStep(FpState(Vector2(0, 0), 0, 0), const Offset(1, 1), 1.0);
    expect(p.length, lessThanOrEqualTo(kWalkSpeed + 1e-9));
  });

  test('pitch clamps to ±80°', () {
    var s = FpState(Vector2.zero(), 0, 0);
    s = applyLook(s, const Offset(0, -100000));
    expect(s.pitch, closeTo(kMaxPitch, 1e-9));
  });

  test('drag right turns right (toward -X when facing +Z)', () {
    final s = applyLook(FpState(Vector2.zero(), 0, 0), const Offset(10, 0));
    // Facing +Z with +Y up, "right" is -X. Turning right must move forward toward -X.
    expect(forwardOf(s.yaw, 0).x, lessThan(0));
  });
}
