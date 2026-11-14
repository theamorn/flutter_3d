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
      // Backlit subsurface cloth transmission + grazing sheen rim.
      expect(body, contains('LightTerms Light(MaterialInputs material, LightContext light)'));
      expect(body, contains('back_trans'));
      expect(body, contains('sheen_rim'));
    });
  });

  group('grass.fmat', () {
    final c = _compile('assets/materials/grass.fmat');

    test('uses 2D simplex noise macro meadow patches and campfire subsurface glow', () {
      expect(c.material.shadingModel, FmatShadingModel.lit);
      expect(_params(c)['campfire'], FmatType.vec4);
      expect(c.material.vertexSource, contains('snoise('));
      expect(c.material.vertexSource, contains('v_macro = macro'));
      expect(c.material.fragmentSource, contains('precision highp float;'));
      expect(c.material.fragmentSource, contains('fire_trans'));
    });
  });

  group('crt_screen.fmat', () {
    final c = _compile('assets/materials/crt_screen.fmat');

    test('is a lit glass tube shader with scanlines, phosphor mask, and VHS tracking', () {
      expect(c.material.shadingModel, FmatShadingModel.lit);
      expect(_params(c)['screen_texture'], FmatType.sampler2d);
      expect(_params(c)['vhs_intensity'], FmatType.float_);
      expect(_params(c)['scanline_count'], FmatType.float_);
      expect(c.material.fragmentSource, contains('precision highp float;'));
      expect(c.material.fragmentSource, contains('CrtCurve('));
      expect(c.material.fragmentSource, contains('material.emissive ='));
    });
  });

  group('materialize_wireframe.fmat', () {
    final c = _compile('assets/materials/materialize_wireframe.fmat');

    test('is a transparent unlit wireframe laser-scan shader with 3D simplex noise', () {
      expect(c.material.shadingModel, FmatShadingModel.unlit);
      expect(_params(c)['sweep'], FmatType.vec4);
      expect(_params(c)['wire_color'], FmatType.vec4);
      expect(_params(c)['glow_color'], FmatType.vec4);
      // LineSegmentsGeometry uses the engine's fixed LineSegmentsVertex shader
      // (which writes only standardVaryings locn0..locn6), so this material
      // must not declare custom varyings or a vertex block (which would cause
      // Metal pipeline creation to fail at draw time).
      expect(c.material.varyings, isEmpty);
      expect(c.material.vertexSource, isNull);
      expect(c.vertexGlsl, isEmpty);
      expect(c.material.fragmentSource, contains('precision highp float;'));
      expect(c.material.fragmentSource, contains('GetWorldPosition()'));
      expect(c.material.fragmentSource, contains('NoiseSimplex3('));
    });
  });

  group('foliage_sway.fmat', () {
    final c = _compile('assets/materials/foliage_sway.fmat');

    test('bends with height in the wind and keeps the imported colour', () {
      expect(c.material.shadingModel, FmatShadingModel.lit);
      expect(_params(c)['wind'], FmatType.vec4);
      expect(_params(c)['sway'], FmatType.vec4);
      expect(_params(c)['base_color'], FmatType.vec4);
      expect(_params(c)['sun_dir'], FmatType.vec4);
      expect(_params(c)['sun_color'], FmatType.vec4);
      final vertex = c.material.vertexSource!;
      expect(vertex, contains('vertex.model_transform'));
      expect(vertex, contains('height * height'));
      expect(vertex, contains('v_height = height'));
      expect(c.material.fragmentSource, contains('precision highp float;'));
      expect(c.material.fragmentSource, contains('forward_scatter'));
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
