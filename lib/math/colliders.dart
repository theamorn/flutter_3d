import 'dart:math' as math;
import 'package:vector_math/vector_math.dart';

/// Axis-aligned box on the XZ plane.
class Box2 {
  const Box2(this.minX, this.minZ, this.maxX, this.maxZ);
  final double minX, minZ, maxX, maxZ;

  /// This box reflected through x = 0 (room A → room B).
  Box2 mirrored() => Box2(-maxX, minZ, -minX, maxZ);

  bool contains(Vector2 p) =>
      p.x >= minX && p.x <= maxX && p.y >= minZ && p.y <= maxZ;

  @override
  String toString() => 'Box2($minX,$minZ → $maxX,$maxZ)';
}

/// Pushes a circle (centre [p], radius [r]) out of [b]. Returns the corrected centre.
Vector2 _pushOut(Vector2 p, double r, Box2 b) {
  final cx = p.x.clamp(b.minX, b.maxX).toDouble();
  final cz = p.y.clamp(b.minZ, b.maxZ).toDouble();
  final dx = p.x - cx, dz = p.y - cz;
  final d2 = dx * dx + dz * dz;
  if (d2 >= r * r) return p;
  if (d2 > 1e-12) {
    final d = math.sqrt(d2);
    return Vector2(cx + dx / d * r, cz + dz / d * r);
  }
  // Centre inside the box: exit through the nearest face.
  final exits = <double>[p.x - b.minX, b.maxX - p.x, p.y - b.minZ, b.maxZ - p.y];
  var k = 0;
  for (var i = 1; i < 4; i++) {
    if (exits[i] < exits[k]) k = i;
  }
  return switch (k) {
    0 => Vector2(b.minX - r, p.y),
    1 => Vector2(b.maxX + r, p.y),
    2 => Vector2(p.x, b.minZ - r),
    _ => Vector2(p.x, b.maxZ + r),
  };
}

/// Moves a circle from [from] toward [to], sliding along boxes; never ends inside one.
Vector2 moveCircle(Vector2 from, Vector2 to, double radius, Iterable<Box2> boxes) {
  final list = boxes.toList();
  final delta = to - from;
  // Sub-step so no step exceeds half the radius (no tunnelling through thin walls).
  final steps = math.max(1, (delta.length / (radius * 0.5)).ceil());
  var p = from.clone();
  for (var s = 0; s < steps; s++) {
    p += delta / steps.toDouble();
    for (var iter = 0; iter < 3; iter++) {
      for (final b in list) {
        p = _pushOut(p, radius, b);
      }
    }
  }
  return p;
}
