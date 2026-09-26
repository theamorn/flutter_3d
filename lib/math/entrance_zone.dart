import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

/// Door centres in the two mirrored rooms.
const double kEntranceX = -1.8, kEntranceZ = 0.0;

class EntranceZone {
  bool inside = false;

  /// Enter close to either door, then keep the state until clearly away.
  bool update(Vector2 xz) {
    final dx = math.min((xz.x - kEntranceX).abs(), (xz.x + kEntranceX).abs());
    final distance = math.sqrt(
      dx * dx + (xz.y - kEntranceZ) * (xz.y - kEntranceZ),
    );
    if (inside) {
      if (distance > 1.5) inside = false;
    } else if (distance < 1.2) {
      inside = true;
    }
    return inside;
  }
}
