import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_scene/scene.dart' show PerspectiveCamera;
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/math/picking.dart';

void main() {
  final eye = Vector3(0, 1.6, 0), target = Vector3(0, 1.6, 5), up = Vector3(0, 1, 0);
  const vp = Size(400, 800);

  test('centre of screen points at target', () {
    final r = screenRay(screen: const Offset(200, 400), viewport: vp,
        eye: eye, target: target, up: up, fovY: 60 * degrees2Radians);
    expect(r.direction.z, closeTo(1, 1e-6));
    expect(r.origin, eye);
  });

  test('top edge is +fovY/2 above forward', () {
    final r = screenRay(screen: const Offset(200, 0), viewport: vp,
        eye: eye, target: target, up: up, fovY: 60 * degrees2Radians);
    final elev = r.direction.y / r.direction.xz.length;
    expect(elev, closeTo(0.57735, 1e-4)); // tan 30°
  });

  test('nearest hit wins', () {
    expect(nearest([null, 3.0, 1.5, 2.0]), 2);
    expect(nearest([null, null]), isNull);
  });

  test('matches the engine camera ray (facing +Z, screen-right is +X)', () {
    final cam = PerspectiveCamera(
        position: eye, target: target, up: up, fovRadiansY: 60 * degrees2Radians);
    for (final pt in const [Offset(350, 400), Offset(50, 100), Offset(200, 700)]) {
      final mine = screenRay(screen: pt, viewport: vp,
          eye: eye, target: target, up: up, fovY: 60 * degrees2Radians).direction;
      final engine = cam.screenPointToRay(pt, vp).direction.normalized();
      expect(mine.x, closeTo(engine.x, 1e-4), reason: '$pt');
      expect(mine.y, closeTo(engine.y, 1e-4), reason: '$pt');
      expect(mine.z, closeTo(engine.z, 1e-4), reason: '$pt');
    }
  });
}
