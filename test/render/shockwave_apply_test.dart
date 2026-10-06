import 'dart:ui' show Size;

import 'package:flutter_3d/render/shockwave_apply.dart';
import 'package:flutter_scene/scene.dart' show PerspectiveCamera;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  final camera = PerspectiveCamera(
    position: Vector3(0, 2, 10),
    target: Vector3(0, 2, 0),
  );
  const viewport = Size(400, 800);

  test('a strike straight ahead lands in the middle of the screen', () {
    final uv = strikeScreenUv(camera, Vector3(0, 2, -50), viewport)!;
    expect(uv.$1, closeTo(0.5, 1e-6));
    expect(uv.$2, closeTo(0.5, 1e-6));
  });

  test('a strike behind the camera has no screen position', () {
    expect(strikeScreenUv(camera, Vector3(0, 2, 40), viewport), isNull);
  });

  test('a strike off to the side is dropped, not clamped to the edge', () {
    expect(strikeScreenUv(camera, Vector3(500, 2, 0), viewport), isNull);
    expect(strikeScreenUv(camera, Vector3(0, 400, 0), viewport), isNull);
  });

  test('an empty viewport projects nothing', () {
    expect(strikeScreenUv(camera, Vector3(0, 2, -50), Size.zero), isNull);
  });
}
