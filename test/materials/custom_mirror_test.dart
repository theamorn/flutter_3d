import 'dart:io';

// The engine's own .fmat compiler (pure Dart, no GPU).
// ignore: implementation_imports
import 'package:flutter_scene/src/fmat/fmat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const path = 'assets/materials/mirror_capture.fmat';
  final c = compileFmat(File(path).readAsStringSync(), fileName: path);
  final params = {for (final p in c.material.parameters) p.name: p.type};

  test('is unlit and samples its own capture, not the built-in reflector', () {
    expect(c.material.shadingModel, FmatShadingModel.unlit);
    expect(c.material.engineInputs, isNot(contains('planar_reflection')));
    expect(params['capture'], FmatType.sampler2d);
    expect(params['capture_view_projection'], FmatType.mat4);
  });

  test('falls back to the plain mirror colour until a capture is bound', () {
    expect(params['base_color'], FmatType.vec4);
    expect(params['capture_ready'], FmatType.float_);
    expect(c.material.fragmentSource, contains('capture_ready'));
  });

  test('outputs the linear HDR capture as is, with highp', () {
    final body = c.material.fragmentSource;
    expect(body, contains('precision highp float;'));
    // No tone mapping or gamma here: the screen view tone-maps once.
    for (final banned in ['pow(', 'LinearToSRGB', 'SRGBToLinear', 'ToneMap']) {
      expect(body, isNot(contains(banned)), reason: banned);
    }
    expect(c.glsl, isNotEmpty);
  });
}
