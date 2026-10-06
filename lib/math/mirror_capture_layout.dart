/// The pure parts of the custom bathroom mirrors: how big each capture is,
/// which plane it mirrors across, and who currently owns each capture.
library;

import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

/// The longest side of a mirror capture, and the shortest any side may be.
const int kMirrorCaptureMax = 512, kMirrorCaptureMin = 64;

/// A capture size for a [width] x [height] viewport: the same aspect, the
/// long side at [kMirrorCaptureMax], no side under [kMirrorCaptureMin]. An
/// empty or invalid viewport gets a square at the maximum.
(int, int) computeMirrorTargetSize(double width, double height) {
  if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
    return (kMirrorCaptureMax, kMirrorCaptureMax);
  }
  final scale = kMirrorCaptureMax / math.max(width, height);
  int side(double v) => (v * scale).round().clamp(kMirrorCaptureMin, kMirrorCaptureMax);
  return (side(width), side(height));
}

/// The world plane of a mirror whose surface passes through the origin of
/// [transform] and faces [localNormal] in its own frame. The normal goes
/// through the inverse transpose, so a mirrored parent (room B's
/// scale.x = -1) or a non-uniform scale still gives the true surface normal.
/// Null for a singular transform or a zero normal: there is no plane to
/// mirror across, and guessing one would reflect the wrong room.
Plane? computeMirrorPlane(Matrix4 transform, Vector3 localNormal) {
  if (localNormal.length2 < 1e-12) return null;
  final linear = transform.getRotation();
  if (linear.determinant().abs() < 1e-9) return null;
  final normal = (Matrix3.copy(linear)
        ..invert()
        ..transpose())
      .transformed(localNormal)
    ..normalize();
  final point = transform.getTranslation();
  return Plane.normalconstant(normal, -normal.dot(point));
}

/// Which capture each mirror has, by owner, so a feature that unmounts late
/// (a toggle, then a quick toggle back) cannot remove the registration of
/// the feature instance that replaced it.
class ReflectionCaptureRegistry<T> {
  final Map<Object, (Object, T)> _byKey = {};

  /// Registers [value] for [key] (a mirror), owned by [owner]. A later
  /// registration of the same key replaces it, whoever owned it.
  void register(Object owner, Object key, T value) => _byKey[key] = (owner, value);

  /// Removes [key]'s registration if [owner] still owns it.
  void unregister(Object owner, Object key) {
    final entry = _byKey[key];
    if (entry != null && identical(entry.$1, owner)) _byKey.remove(key);
  }

  /// Removes every registration [owner] still owns.
  void unregisterAll(Object owner) =>
      _byKey.removeWhere((_, entry) => identical(entry.$1, owner));

  /// [key]'s registered value, or null.
  T? operator [](Object key) => _byKey[key]?.$2;

  /// Every registered value.
  Iterable<T> get active => _byKey.values.map((e) => e.$2);
}
