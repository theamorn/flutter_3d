import 'feature_registry.dart';

enum Preset { low, medium, high, ultra }

const _low = {'sky', 'ocean', 'tone_mapping', 'portal_culling', 'occlusion', 'instancing'};
const _medium = {..._low, 'fog', 'shadows', 'lamps', 'water_fx'};
const _high = {..._medium, 'bloom', 'ao', 'msaa', 'rain', 'lightning'};
const _ultra = {..._high, 'god_rays', 'ssr', 'rain_glass', 'mirror', 'sea_reflection'};

/// Toggleable feature ids that are ON for [p]. Each tier ⊇ the one below.
Set<String> presetIds(Preset p) => switch (p) {
      Preset.low => _low,
      Preset.medium => _medium,
      Preset.high => _high,
      Preset.ultra => _ultra,
    };

/// Enables the listed features and disables the other toggleables.
Future<void> applyPreset(FeatureRegistry r, Preset p) {
  final on = presetIds(p);
  return Future.wait([
    for (final f in r.features.where((f) => f.toggleable))
      r.setEnabled(f.id, on.contains(f.id)),
  ]);
}
