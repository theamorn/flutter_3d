import 'dart:math' as math;
import 'dart:ui';
import 'package:vector_math/vector_math.dart';

class FpState {
  FpState(this.xz, this.yaw, this.pitch);
  final Vector2 xz;
  final double yaw, pitch;
}

/// m/s at full stick.
const double kWalkSpeed = 1.4;

/// Radians per logical pixel of drag.
const double kLookSensitivity = 0.005;
const double kMaxPitch = 80 * degrees2Radians;

/// yaw 0 → looking toward +Z; positive yaw turns toward +X.
Vector3 forwardOf(double yaw, double pitch) => Vector3(
    math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch));

/// stick: x = strafe right, y = forward (+1 = up on the joystick).
/// Returns the desired xz (pre-collision).
Vector2 desiredStep(FpState s, Offset stick, double dt) {
  var v = Vector2(stick.dx, stick.dy);
  if (v.length > 1) v = v.normalized();
  final fwd = Vector2(math.sin(s.yaw), math.cos(s.yaw));
  final right = Vector2(-fwd.y, fwd.x); // facing +Z (yaw 0) → right is −X
  return s.xz + (fwd * v.y + right * v.x) * (kWalkSpeed * dt);
}

/// Drag right → turn right; drag up → look up.
FpState applyLook(FpState s, Offset d) => FpState(
      s.xz,
      s.yaw - d.dx * kLookSensitivity,
      (s.pitch - d.dy * kLookSensitivity).clamp(-kMaxPitch, kMaxPitch).toDouble(),
    );
