import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/features/render_features.dart';
import 'package:flutter_3d/hotel/feature.dart';
import 'package:flutter_3d/hotel/feature_registry.dart';
import 'package:flutter_3d/hotel/presets.dart';

class _Aa extends HotelFeature {
  _Aa(this.id);
  @override
  final String id;
  @override
  String get label => id;
  @override
  CostTier get tier => CostTier.cheap;
  @override
  bool get defaultOn => false;
  @override
  String? get exclusiveGroup => kAaGroup;
  @override
  Future<void> mount(Object? ctx) async {}
  @override
  void unmount(Object? ctx) {}
}

void main() {
  test('unmounting a mode turns AA off only if that mode is still in charge', () {
    expect(aaAfterUnmount(AntiAliasingMode.msaa, AntiAliasingMode.msaa), AntiAliasingMode.none);
    // The new mode mounted first (per-feature chains interleave): keep it.
    expect(aaAfterUnmount(AntiAliasingMode.fxaa, AntiAliasingMode.msaa), AntiAliasingMode.fxaa);
  });

  test('presets swap anti-aliasing modes cleanly', () async {
    final r = FeatureRegistry([for (final id in ['msaa', 'fxaa', 'smaa', 'taa']) _Aa(id)],
        mountContext: null);
    Set<String> on() => {for (final f in r.features) if (r.isMounted(f.id)) f.id};
    await applyPreset(r, Preset.high);
    expect(on(), {'msaa'});
    await applyPreset(r, Preset.medium);
    expect(on(), {'fxaa'});
    await applyPreset(r, Preset.low);
    expect(on(), <String>{});
    await applyPreset(r, Preset.high);
    expect(on(), {'msaa'});
  });
}
