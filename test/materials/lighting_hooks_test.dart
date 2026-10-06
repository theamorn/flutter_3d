import 'dart:io';

import 'package:flutter_3d/island/super_ultra/stone_lighting.dart';
// The engine's own .fmat compiler (pure Dart, no GPU), imported the way
// test/materials/fmat_precision_test.dart does.
// ignore: implementation_imports
import 'package:flutter_scene/src/fmat/fmat.dart';
// ignore: implementation_imports
import 'package:flutter_scene/src/fmat/fmat_emitter.dart' show lightingHooksIn;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

const _cloth = 'assets/materials/cloth_hooks.fmat';
const _stone = 'assets/materials/campfire_stone.fmat';

FmatCompilation _compile(String path) =>
    compileFmat(File(path).readAsStringSync(), fileName: path);

/// The material's fragment body as authored (not the engine includes, which
/// read the light context themselves).
String _body(String path) => _compile(path).material.fragmentSource;

double _luma(Vector3 c) => c.dot(Vector3(0.2126, 0.7152, 0.0722));

void main() {
  group('cloth_hooks.fmat', () {
    test('defines Light, Ambient and Composite, and the engine sees all three', () {
      final c = _compile(_cloth);
      expect(c.material.shadingModel, FmatShadingModel.lit);
      expect(lightingHooksIn(c.material.fragmentSource),
          {'Light', 'Ambient', 'Composite'});
      for (final define in [
        'FLUTTER_SCENE_HOOK_LIGHT',
        'FLUTTER_SCENE_HOOK_AMBIENT',
        'FLUTTER_SCENE_HOOK_COMPOSITE',
      ]) {
        expect(c.glsl, contains('#define $define'), reason: define);
      }
      // Engine indirect stays on: the cloth only rescales it.
      expect(c.material.environmentLighting, isTrue);
    });

    test('binds the room photo and normal textures as sampler parameters', () {
      final params = {
        for (final p in _compile(_cloth).material.parameters) p.name: p.type
      };
      expect(params['base_color_texture'], FmatType.sampler2d);
      expect(params['normal_texture'], FmatType.sampler2d);
      expect(params['base_color_factor'], FmatType.vec4);
    });

    test('wraps diffuse by 0.2 and caps the specular through roughness', () {
      final body = _body(_cloth);
      expect(body, contains('kClothWrap = 0.2'));
      // The specular lobe's roughness is floored, not its gain raised.
      expect(body, contains('max(material.roughness'));
    });
  });

  group('campfire_stone.fmat', () {
    test('supplies its own indirect light through Light, Ambient and Composite', () {
      final c = _compile(_stone);
      expect(c.material.shadingModel, FmatShadingModel.lit);
      expect(lightingHooksIn(c.material.fragmentSource), {'Light', 'Ambient', 'Composite'});
      final params = {
        for (final p in c.material.parameters) p.name: p.type
      };
      expect(params['sky_upper'], FmatType.vec4);
      expect(params['sky_lower'], FmatType.vec4);
    });

    test('replaces the engine image-based light instead of scaling it', () {
      // environment_lighting: false (the engine's own switch for this) draws
      // nothing on Adreno/Vulkan in flutter_scene 0.24.0 (device check,
      // 2026-10-06), so the environment stays bound and Ambient() overwrites
      // both of its terms with the stones' gradient.
      final c = _compile(_stone);
      expect(c.material.environmentLighting, isTrue);
      final body = c.material.fragmentSource;
      expect(body, contains('ambient.irradiance = '));
      expect(body, contains('ambient.radiance = '));
      expect(body, isNot(contains('ambient.irradiance *=')));
    });
  });

  group('both hooked materials', () {
    for (final path in [_cloth, _stone]) {
      test('$path keeps highp and uses the engine signatures', () {
        final body = _body(path);
        expect(body, contains('precision highp float;'));
        expect(body, contains('LightTerms Light(MaterialInputs material, LightContext light)'));
        expect(body,
            contains('highp vec4 Composite(MaterialInputs material, LightingResult result)'));
        expect(_compile(path).glsl, contains('precision highp float;'));
      });

      test('$path never applies a light\'s shadow or attenuation twice', () {
        // LightContext.radiance already carries the shadow, distance and cone
        // attenuation; a hook that multiplies any of them in again darkens
        // the lit side twice.
        final body = _body(path);
        expect(body, contains('light.radiance'));
        for (final term in ['light.shadow', 'light.distance_attenuation', 'light.cone_attenuation']) {
          expect(body, isNot(contains(term)), reason: term);
        }
      });

      test('$path premultiplies by alpha exactly once, in Composite', () {
        final body = _body(path);
        expect(RegExp(r'result\.alpha').allMatches(body), hasLength(1));
        // Surface() hands over straight alpha; the engine premultiplies only
        // through Composite's return value.
        expect(body, isNot(contains('base_color.rgb * material.base_color.a')));
      });
    }
  });

  group('stoneLightingFor', () {
    test('no ambient means no indirect light at all (no self-lit stones)', () {
      final l = stoneLightingFor(ambient: 0, night: 0, weather: 0);
      expect(l.upper.length, 0);
      expect(l.lower.length, 0);
    });

    test('day sky is brighter than the night sky at the same ambient', () {
      final day = stoneLightingFor(ambient: 0.8, night: 0, weather: 0);
      final night = stoneLightingFor(ambient: 0.8, night: 1, weather: 0);
      expect(_luma(day.upper), greaterThan(_luma(night.upper)));
    });

    test('the ground bounce is dimmer than the sky above', () {
      for (final night in [0.0, 0.5, 1.0]) {
        final l = stoneLightingFor(ambient: 1, night: night, weather: 0);
        expect(_luma(l.lower), lessThan(_luma(l.upper)), reason: 'night $night');
      }
    });

    test('rain greys the sky term', () {
      double spread(Vector3 c) =>
          [c.x, c.y, c.z].reduce((a, b) => a > b ? a : b) -
          [c.x, c.y, c.z].reduce((a, b) => a < b ? a : b);
      final clear = stoneLightingFor(ambient: 1, night: 0, weather: 0);
      final storm = stoneLightingFor(ambient: 1, night: 0, weather: 1);
      expect(spread(storm.upper) / _luma(storm.upper),
          lessThan(spread(clear.upper) / _luma(clear.upper)));
    });

    test('stays finite and non-negative for any input, clamping out-of-range ones', () {
      for (final ambient in [-1.0, 0.0, 0.25, 1.0, 5.0, double.nan]) {
        for (final night in [-1.0, 0.0, 1.0, 2.0]) {
          for (final weather in [-1.0, 0.0, 1.0, 3.0]) {
            final l = stoneLightingFor(ambient: ambient, night: night, weather: weather);
            for (final v in [...l.upper.storage, ...l.lower.storage, l.multiplier]) {
              expect(v.isFinite, isTrue, reason: '$ambient $night $weather');
              expect(v, greaterThanOrEqualTo(0));
            }
          }
        }
      }
    });

    test('the comparison defaults to the custom indirect', () {
      expect(StoneIndirectMode.initial, StoneIndirectMode.custom);
      expect(StoneIndirectMode.values, [StoneIndirectMode.engine, StoneIndirectMode.custom]);
    });
  });
}
