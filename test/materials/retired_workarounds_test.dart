import 'dart:io';

// ignore: implementation_imports
import 'package:flutter_scene/src/fmat/fmat.dart';
import 'package:flutter_test/flutter_test.dart';

FmatCompilation compile(String path) =>
    compileFmat(File(path).readAsStringSync(), fileName: path);

void main() {
  test('rain glass is unlit with a bounded scene-color reach', () {
    final c = compile('assets/materials/rain_glass.fmat');
    expect(c.material.shadingModel, FmatShadingModel.unlit);
    expect(c.material.engineInputs, ['scene_color']);
    expect(c.material.sceneColorReach, isNotNull);
  });

  test('heat haze is unlit with a bounded scene-color reach', () {
    final c = compile('assets/materials/heat_haze.fmat');
    expect(c.material.shadingModel, FmatShadingModel.unlit);
    expect(c.material.sceneColorReach, isNotNull);
  });

  test('heat haze and page curl place vertices through the model transform', () {
    for (final p in [
      'assets/materials/heat_haze.fmat',
      'assets/materials/page_curl.fmat',
    ]) {
      expect(File(p).readAsStringSync(), contains('vertex.model_transform'),
          reason: p);
      expect(compile(p).glsl, isNotEmpty, reason: p);
    }
  });

  test('page curl no longer rebuilds a basis from the tangent', () {
    expect(File('assets/materials/page_curl.fmat').readAsStringSync(),
        isNot(contains('world_tangent')));
  });
}
