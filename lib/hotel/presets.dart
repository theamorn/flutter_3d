import 'feature_registry.dart';

enum Preset { low, medium, high, ultra }

const _low = {'sky', 'ocean', 'tone_mapping', 'portal_culling', 'occlusion', 'instancing'};
const _medium = {
  ..._low, 'fog', 'shadows', 'lamps', 'water_fx',
  'light_probes', 'auto_exposure', 'static_shadows', 'area_lights',
};
const _high = {..._medium, 'bloom', 'ao', 'rain', 'lightning', 'spot_lights'};
const _ultra = {
  ..._high, 'god_rays', 'ssr', 'rain_glass', 'mirror', 'sea_reflection',
  'dynamic_gi', 'volumetric_fog',
};

/// Each tier's one anti-aliasing mode (the `aa` exclusive group), or none.
/// SMAA and TAA are manual picks.
const Map<Preset, String?> kPresetAa = {
  Preset.low: null,
  Preset.medium: 'fxaa',
  Preset.high: 'msaa',
  Preset.ultra: 'msaa',
};

/// Toggleable feature ids that are ON for [p]. Each tier is a superset of the
/// one below, apart from its anti-aliasing mode.
Set<String> presetIds(Preset p) {
  final base = switch (p) {
    Preset.low => _low,
    Preset.medium => _medium,
    Preset.high => _high,
    Preset.ultra => _ultra,
  };
  return {...base, ?kPresetAa[p]};
}

/// Enables the listed features and disables the other toggleables.
Future<void> applyPreset(FeatureRegistry r, Preset p) {
  final on = presetIds(p);
  return Future.wait([
    for (final f in r.features.where((f) => f.toggleable))
      r.setEnabled(f.id, on.contains(f.id)),
  ]);
}
