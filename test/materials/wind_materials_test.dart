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
  group('flag.fmat', () {
    final c = _compile('assets/materials/flag.fmat');

    test('is two-sided lit cloth moved in its vertex stage by the wind', () {
      expect(c.material.shadingModel, FmatShadingModel.lit);
      expect(c.material.culling, FmatCulling.none);
      expect(_params(c)['wind'], FmatType.vec4);
      expect(c.material.vertexSource, contains('material_params.wind'));
      expect(c.vertexGlsl, isNotEmpty);
    });

    test('stays pinned at the pole: every displacement scales with the distance along the fly', () {
      final vertex = c.material.vertexSource!;
      expect(vertex, contains('float along = '));
      expect(vertex, contains('* along'));
      // It recomputes its normal from the wave, so the folds shade.
      expect(vertex, contains('vertex.world_normal = '));
    });

    test('keeps highp in its fragment body', () {
      expect(c.material.fragmentSource, contains('precision highp float;'));
    });

    test('flies the Thai flag: red, white, double blue, white, red', () {
      List<double> color(String name) => [
            for (final v in c.material.parameters.firstWhere((p) => p.name == name).defaultValue! as List)
              (v as num).toDouble(),
          ];
      // The official sRGB colours (#A51931, #F4F5F8, #2D2A4A), linear.
      expect(color('color_a').take(3), [0.3763, 0.0097, 0.0307]);
      expect(color('color_b').take(3), [0.9047, 0.9131, 0.9387]);
      expect(color('color_c').take(3), [0.0262, 0.0232, 0.0685]);
      // Stripe edges at 1/6, 2/6, 4/6 and 5/6 of the height.
      final body = c.material.fragmentSource;
      for (final edge in ['1.0 / 6.0', '2.0 / 6.0', '4.0 / 6.0', '5.0 / 6.0']) {
        expect(body, contains(edge), reason: edge);
      }
    });
  });

  group('foliage_sway.fmat', () {
    final c = _compile('assets/materials/foliage_sway.fmat');

    test('bends with height in the wind and keeps the imported colour', () {
      expect(c.material.shadingModel, FmatShadingModel.lit);
      expect(_params(c)['wind'], FmatType.vec4);
      expect(_params(c)['sway'], FmatType.vec4);
      expect(_params(c)['base_color'], FmatType.vec4);
      final vertex = c.material.vertexSource!;
      expect(vertex, contains('vertex.model_transform'));
      expect(vertex, contains('height * height'));
      expect(c.material.fragmentSource, contains('precision highp float;'));
    });
  });

  test('rain_glass.fmat slants its drops with the wind, downwind', () {
    final c = _compile('assets/materials/rain_glass.fmat');
    expect(_params(c)['wind_skew'], FmatType.float_);
    // The drop pattern is looked up at u' = u - skew * v: a drop keeps its
    // u', so its real u grows by skew for each unit it slides down (+v),
    // the way rainGlassSkew promises. Adding instead would drift upwind.
    expect(c.material.fragmentSource, contains('uv.x -= material_params.wind_skew * uv.y;'));
  });
}
