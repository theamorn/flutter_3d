import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/features/render_features.dart';
import 'package:flutter_3d/hotel/feature.dart';
import 'package:flutter_3d/hotel/feature_catalog.dart';
import 'package:flutter_3d/hotel/feature_registry.dart';
import 'package:flutter_3d/hotel/presets.dart';

class _Scale extends HotelFeature {
  _Scale(this.id);
  @override
  final String id;
  @override
  String get label => id;
  @override
  CostTier get tier => CostTier.free;
  @override
  bool get defaultOn => false;
  @override
  String? get exclusiveGroup => kRenderScaleGroup;
  @override
  Future<void> mount(Object? ctx) async {}
  @override
  void unmount(Object? ctx) {}
}

void main() {
  test('unmounting a scale returns to full resolution only if it is still in charge', () {
    expect(renderScaleAfterUnmount(0.85, 0.85), 1.0);
    // The other scale mounted first (per-feature chains interleave): keep it.
    expect(renderScaleAfterUnmount(0.75, 0.85), 0.75);
  });

  test('the render scales are one exclusive group, off by default', () {
    final scales = buildCatalog().whereType<RenderScaleFeature>().toList();
    expect({for (final f in scales) f.id: f.scale}, {
      'render_scale_85': 0.85,
      'render_scale_75': 0.75,
    });
    for (final f in scales) {
      expect(f.exclusiveGroup, kRenderScaleGroup, reason: f.id);
      expect(f.defaultOn, isFalse, reason: f.id);
    }
  });

  test('presets swap render scales cleanly: ultra at 85%, the rest at full', () async {
    final r = FeatureRegistry(
      [for (final id in ['render_scale_85', 'render_scale_75']) _Scale(id)],
      mountContext: null,
    );
    Set<String> on() => {for (final f in r.features) if (r.isMounted(f.id)) f.id};
    await applyPreset(r, Preset.ultra);
    expect(on(), {'render_scale_85'});
    await r.setEnabled('render_scale_75', true);
    expect(on(), {'render_scale_75'});
    await applyPreset(r, Preset.ultra);
    expect(on(), {'render_scale_85'});
    await applyPreset(r, Preset.high);
    expect(on(), <String>{});
  });
}
