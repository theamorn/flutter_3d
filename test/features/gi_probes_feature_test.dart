import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/features/gi_probes_feature.dart';
import 'package:flutter_3d/hotel/feature.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  test('probe markers are a manual free feature', () {
    final feature = GiProbesFeature();
    expect(feature.id, 'gi_probes');
    expect(feature.defaultOn, isFalse);
    expect(feature.tier, CostTier.free);
  });

  test(
    'probe layout compares values, snapshots vectors, and clears disabled GI',
    () {
      final layout = GiProbeLayout();
      final origin = Vector3(1, 2, 3);
      final spacing = Vector3(2, 3, 4);
      final counts = Vector3(2, 2, 2);
      IrradianceProbeGrid grid() =>
          IrradianceProbeGrid(origin: origin, spacing: spacing, counts: counts);
      expect(layout.update(true, grid()), isTrue);
      expect(layout.positions.length, 8);
      expect(layout.positions.last, Vector3(3, 5, 7));
      expect(layout.update(true, grid()), isFalse);
      origin.x = 5;
      expect(layout.update(true, grid()), isTrue);
      expect(layout.positions.first, Vector3(5, 2, 3));
      spacing.z = 5;
      expect(layout.update(true, grid()), isTrue);
      expect(layout.positions.last, Vector3(7, 5, 8));
      counts.x = 3;
      expect(layout.update(true, grid()), isTrue);
      expect(layout.positions.length, 12);
      expect(layout.update(false, grid()), isTrue);
      expect(layout.positions, isEmpty);
      expect(layout.update(false, grid()), isFalse);
      expect(layout.update(true, grid()), isTrue);
      expect(layout.update(true, null), isTrue);
      expect(layout.positions, isEmpty);
    },
  );
}
