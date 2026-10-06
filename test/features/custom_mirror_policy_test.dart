import 'package:flutter_3d/features/custom_mirror_feature.dart';
import 'package:flutter_3d/features/reflection_features.dart';
import 'package:flutter_3d/hotel/feature_catalog.dart';
import 'package:flutter_3d/hotel/presets.dart';
import 'package:flutter_scene/scene.dart' show kRenderLayerAll, kRenderLayerDefault;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the built-in and custom mirrors are alternatives', () {
    final catalog = buildCatalog();
    final builtIn = catalog.singleWhere((f) => f.id == 'mirror');
    final custom = catalog.singleWhere((f) => f.id == 'mirror_custom');
    expect(builtIn.exclusiveGroup, kBathroomReflectionGroup);
    expect(custom.exclusiveGroup, kBathroomReflectionGroup);
  });

  test('ultra picks the custom HDR mirror, never both', () {
    final ultra = presetIds(Preset.ultra);
    expect(ultra, contains('mirror_custom'));
    expect(ultra, isNot(contains('mirror')));
    for (final p in Preset.values) {
      expect(presetIds(p).containsAll({'mirror', 'mirror_custom'}), isFalse, reason: '$p');
    }
  });

  test('the receiver layer keeps a mirror out of every custom capture', () {
    expect(kCustomMirrorLayer, 1 << 5);
    expect(kCustomMirrorCaptureMask & kCustomMirrorLayer, 0);
    expect(kCustomMirrorCaptureMask & kRenderLayerDefault, isNot(0));
    expect(kCustomMirrorCaptureMask & kSeaLayer, isNot(0),
        reason: 'the sea still shows in the mirror');
    // The screen view still draws the mirror itself.
    expect(kRenderLayerAll & kCustomMirrorLayer, isNot(0));
    expect(kCustomMirrorLayer & (kSeaLayer | kSeaReflectedLayer), 0);
  });
}
