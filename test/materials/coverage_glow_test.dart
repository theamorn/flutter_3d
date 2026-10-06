import 'dart:io';

// The engine's own .fmat compiler (pure Dart, no GPU).
// ignore: implementation_imports
import 'package:flutter_scene/src/fmat/fmat.dart';
import 'package:flutter_test/flutter_test.dart';

FmatCompilation _compile(String path) =>
    compileFmat(File(path).readAsStringSync(), fileName: path);

Map<String, FmatType> _params(FmatCompilation c) =>
    {for (final p in c.material.parameters) p.name: p.type};

void main() {
  group('additive_glow.fmat', () {
    final c = _compile('assets/materials/additive_glow.fmat');

    test('adds light without writing depth', () {
      expect(c.material.blending, FmatBlending.additive);
      expect(c.material.depthWrite, isFalse);
      expect(c.material.shadingModel, FmatShadingModel.unlit);
    });

    test('faces the camera and fades where it meets real geometry', () {
      expect(c.material.vertexSource, contains('camera_position'));
      expect(c.material.engineInputs, contains('scene_depth'));
      expect(_params(c)['glow'], FmatType.vec4);
    });

    test('keeps highp and compiles', () {
      expect(c.material.fragmentSource, contains('precision highp float;'));
      expect(c.glsl, isNotEmpty);
      expect(c.vertexGlsl, isNotEmpty);
    });
  });
}

