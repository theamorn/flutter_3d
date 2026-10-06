import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/features/render_features.dart';
import 'package:flutter_3d/hotel/presets.dart';
import 'package:flutter_3d/hotel/feature_catalog.dart';

const aaModes = {'msaa', 'fxaa', 'smaa', 'taa'};
const scaleIds = {'render_scale_85', 'render_scale_75'};

void main() {
  test('each preset is a superset of the one below, outside the AA group', () {
    for (var i = 1; i < Preset.values.length; i++) {
      final hi = presetIds(Preset.values[i]).difference(aaModes);
      final lo = presetIds(Preset.values[i - 1]).difference(aaModes);
      expect(hi.containsAll(lo), true, reason: '${Preset.values[i]}');
    }
  });

  test('each preset turns on at most one anti-aliasing mode, its own', () {
    for (final p in Preset.values) {
      final aa = presetIds(p).intersection(aaModes);
      final mode = kPresetAa[p];
      expect(aa, mode == null ? isEmpty : {mode}, reason: '$p');
    }
  });

  test('every id in a preset exists and is toggleable', () {
    final toggleable = buildCatalog().where((f) => f.toggleable).map((f) => f.id).toSet();
    for (final p in Preset.values) {
      expect(toggleable.containsAll(presetIds(p)), true, reason: '$p');
    }
  });

  test('ultra enables every toggleable feature except the alternative AA modes, '
      'the 75% scale, dynamic GI and the GPU pacing pick', () {
    final toggleable = buildCatalog().where((f) => f.toggleable).map((f) => f.id).toSet();
    expect(
      presetIds(Preset.ultra),
      toggleable.difference(
          {'fxaa', 'smaa', 'taa', 'render_scale_75', 'dynamic_gi', 'gpu_pacing_2'}),
    );
  });

  test('no preset turns on dynamic GI: it is a manual pick', () {
    for (final p in Preset.values) {
      expect(presetIds(p), isNot(contains('dynamic_gi')), reason: '$p');
    }
  });

  test('each preset turns on at most one render scale, its own', () {
    for (final p in Preset.values) {
      final scales = presetIds(p).intersection(scaleIds);
      final scale = kPresetRenderScale[p];
      expect(scales, scale == null ? isEmpty : {scale}, reason: '$p');
    }
    expect(kPresetRenderScale[Preset.ultra], 'render_scale_85');
  });

  test('the anti-aliasing modes form one exclusive group', () {
    final aa = buildCatalog().where((f) => aaModes.contains(f.id)).toList();
    expect(aa.map((f) => f.id).toSet(), aaModes);
    for (final f in aa) {
      expect(f.exclusiveGroup, kAaGroup, reason: f.id);
    }
  });
}
