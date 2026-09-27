import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_3d/hotel/look.dart';

void main() {
  test('flags map onto EnvironmentSettings', () {
    final s = LookState()
      ..bloom = true
      ..ao = true
      ..fog = true
      ..toneMapping = false;
    final e = composeLook(s);
    expect(e.bloomEnabled, true);
    expect(e.lensFlareEnabled, true);
    expect(e.ambientOcclusionEnabled, true);
    expect(e.ambientOcclusionMethod, AmbientOcclusionMethod.groundTruth);
    expect(e.fogEnabled, true);
    expect(e.toneMapping, ToneMappingMode.linear);
  });

  test('sky fields are always passed through (engine rule 1)', () {
    final s = LookState();
    final e = composeLook(s);
    expect(e.skybox, same(s.skybox));
    expect(e.skyEnvironment, same(s.skyEnvironment));
  });

  test('bloom threshold is in display terms: it scales with 1 / exposure', () {
    // The engine thresholds linear radiance before exposure is applied, so a
    // fixed 1.0 at exposure 0.35 would bloom everything brighter than 0.35.
    final day = composeLook(LookState()..exposure = 0.35);
    final night = composeLook(LookState()..exposure = 2.5);
    expect(day.bloomThreshold * 0.35, closeTo(1.0, 1e-9));
    expect(night.bloomThreshold * 2.5, closeTo(1.0, 1e-9));
  });

  test('weather exposure multiplies sky exposure and adjusts bloom threshold', () {
    final look = LookState()
      ..exposure = 0.35
      ..weatherExposureScale = 0.65;
    final day = composeLook(look);
    expect(day.exposure, closeTo(0.2275, 1e-9));
    expect(day.bloomThreshold * day.exposure, closeTo(1.0, 1e-9));

    look.exposure = 2.5;
    final night = composeLook(look);
    expect(night.exposure, closeTo(1.625, 1e-9));
    expect(night.bloomThreshold * night.exposure, closeTo(1.0, 1e-9));
  });

  test('volumetric fog: height fog, sun glow and forced shafts', () {
    final plain = composeLook(LookState()..fog = true);
    expect(plain.fogHeightFalloff, 0);
    expect(plain.fogSunInScatter, 0);
    expect(plain.godRaysEnabled, isFalse);

    final v = composeLook(LookState()..volumetricFog = true);
    expect(v.fogEnabled, isTrue, reason: 'on even with the plain fog switch off');
    expect(v.fogHeight, kVolumetricFogHeight);
    expect(v.fogHeightFalloff, kVolumetricFogFalloff);
    expect(v.fogSunInScatter, kVolumetricSunInScatter);
    expect(v.godRaysEnabled, isTrue);
    expect(v.godRaysDensity, kVolumetricGodRaysDensity);
    expect(v.godRaysMaxDistance, kVolumetricGodRaysMaxDistance);

    final storm = composeLook(LookState()
      ..volumetricFog = true
      ..volumetricFogThickness = 2.5);
    expect(storm.fogDensity, closeTo(kVolumetricFogDensity * 2.5, 1e-12));
  });

  test('the rooms, 90 m above the sea, see under a tenth of its fog', () {
    expect(math.exp(-kVolumetricFogFalloff * (0 - kVolumetricFogHeight)), lessThan(0.1));
  });

  test('auto exposure and dynamic GI flags', () {
    final off = composeLook(LookState());
    expect(off.autoExposureEnabled, isFalse);
    expect(off.globalIlluminationEnabled, isFalse);
    final on = composeLook(LookState()
      ..autoExposure = true
      ..dynamicGi = true);
    expect(on.autoExposureEnabled, isTrue);
    expect(on.autoExposureMinEv, -kAutoExposureRangeEv);
    expect(on.autoExposureMaxEv, kAutoExposureRangeEv);
    expect(on.globalIlluminationEnabled, isTrue);
    expect(on.globalIlluminationVolumeMode, IrradianceVolumeMode.component);
    expect(on.globalIlluminationVisibilityBias, kGiVisibilityBias);
  });
}
