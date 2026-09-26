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
}
