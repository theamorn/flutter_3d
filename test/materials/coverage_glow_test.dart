import 'dart:io';

// The engine's own .fmat compiler (pure Dart, no GPU).
// ignore: implementation_imports
import 'package:flutter_scene/src/fmat/fmat.dart';
// ignore: implementation_imports
import 'package:flutter_scene/src/fmat/fmat_emitter.dart' show materialHasDepthSurface;
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

  group('grass_coverage.fmat', () {
    final covered = _compile('assets/materials/grass_coverage.fmat');
    final original = _compile('assets/materials/grass.fmat');

    test('is an opaque alpha-to-coverage cutout with its own depth surface', () {
      expect(covered.material.blending, FmatBlending.opaque);
      expect(covered.material.alphaToCoverage, isTrue);
      expect(materialHasDepthSurface(covered.material), isTrue);
    });

    test('keeps every grass parameter, so wind, player and light still drive it', () {
      expect(_params(covered), containsPair('time', FmatType.float_));
      for (final p in original.material.parameters) {
        expect(_params(covered)[p.name], p.type, reason: p.name);
      }
    });

    test('keeps the world-space wind and player push in its vertex stage', () {
      final vertex = covered.material.vertexSource!;
      expect(vertex, contains('material_params.wind'));
      expect(vertex, contains('material_params.player'));
      expect(vertex, contains('vertex.world_position.xz += bend * k'));
    });

    test('fades a narrow band at the blade edges and tip from the UVs', () {
      final body = covered.material.fragmentSource;
      expect(body, contains('GetUV0()'));
      expect(body, contains('precision highp float;'));
      expect(covered.glsl, isNotEmpty);
    });
  });
}
