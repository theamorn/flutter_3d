import 'dart:math' as math;
import 'dart:ui';
import 'package:vector_math/vector_math.dart';

class PickRay {
  PickRay(this.origin, this.direction);
  final Vector3 origin, direction;
}

/// Ray through [screen] (logical px) for a perspective camera.
PickRay screenRay({
  required Offset screen,
  required Size viewport,
  required Vector3 eye,
  required Vector3 target,
  required Vector3 up,
  required double fovY,
}) {
  final fwd = (target - eye).normalized();
  final right = fwd.cross(up).normalized(); // fwd +Z, up +Y → right is −X
  final camUp = right.cross(fwd).normalized();
  final ndcX = screen.dx / viewport.width * 2 - 1;
  final ndcY = 1 - screen.dy / viewport.height * 2;
  final t = math.tan(fovY / 2);
  final aspect = viewport.width / viewport.height;
  final dir = (fwd + right * (ndcX * t * aspect) + camUp * (ndcY * t)).normalized();
  return PickRay(eye.clone(), dir);
}

/// Of candidate hits (distance or null), the index of the nearest non-null, or null.
int? nearest(List<double?> distances) {
  int? best;
  for (var i = 0; i < distances.length; i++) {
    final v = distances[i];
    if (v != null && (best == null || v < distances[best]!)) best = i;
  }
  return best;
}
