import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/hotel/presets.dart';
import 'package:flutter_3d/hotel/feature_catalog.dart';

void main() {
  test('each preset is a superset of the one below', () {
    for (var i = 1; i < Preset.values.length; i++) {
      expect(presetIds(Preset.values[i]).containsAll(presetIds(Preset.values[i - 1])), true);
    }
  });

  test('every id in a preset exists and is toggleable', () {
    final toggleable = buildCatalog().where((f) => f.toggleable).map((f) => f.id).toSet();
    for (final p in Preset.values) {
      expect(toggleable.containsAll(presetIds(p)), true, reason: '$p');
    }
  });

  test('ultra enables every toggleable feature', () {
    final toggleable = buildCatalog().where((f) => f.toggleable).map((f) => f.id).toSet();
    expect(presetIds(Preset.ultra), toggleable);
  });
}
