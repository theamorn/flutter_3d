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
}
