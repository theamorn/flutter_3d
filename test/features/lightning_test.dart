import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/features/lightning_feature.dart';
import 'package:flutter_3d/features/ocean_feature.dart' show kSeaLevel;
import 'package:flutter_3d/features/sky_feature.dart' show kDayExposure, kNightExposure;
import 'package:flutter_3d/math/schedulers.dart';

void main() {
  group('buildBoltPoints', () {
    test('6 passes produce 65 points', () {
      final points = buildBoltPoints(10, 150, math.Random(1));
      expect(points.length, 65);
    });

    test('endpoints are fixed at the top and the sea', () {
      final points = buildBoltPoints(-37.5, 188, math.Random(7));
      expect(points.first, Vector3(-37.5, kBoltTopY, 188));
      expect(points.last, Vector3(-37.5, kSeaLevel, 188));
      expect(kSeaLevel, -90);
    });

    test('same seed gives the same bolt (deterministic)', () {
      final a = buildBoltPoints(5, 160, math.Random(42));
      final b = buildBoltPoints(5, 160, math.Random(42));
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].x, closeTo(b[i].x, 1e-9));
        expect(a[i].y, closeTo(b[i].y, 1e-9));
        expect(a[i].z, closeTo(b[i].z, 1e-9));
      }
    });

    test('different seeds give different bolts', () {
      final a = buildBoltPoints(5, 160, math.Random(1));
      final b = buildBoltPoints(5, 160, math.Random(2));
      // Some interior point must differ; the endpoints are always equal.
      final anyDifferent =
          List.generate(a.length, (i) => i).any((i) => (a[i] - b[i]).length2 > 1e-9);
      expect(anyDifferent, isTrue);
    });

    test('interior points stay near the straight line (bounded kick)', () {
      final x = 20.0, z = 170.0;
      final points = buildBoltPoints(x, z, math.Random(3));
      // Max possible lateral displacement is bounded by geometric series of
      // kick * initial segment length (390 m) — generous bound, not tight.
      const maxOffset = kBoltKick * 390 * 2;
      for (final p in points) {
        final lateral = math.sqrt(math.pow(p.x - x, 2) + math.pow(p.z - z, 2));
        expect(lateral, lessThan(maxOffset));
      }
    });
  });

  group('pickBoltXZ / buildStrikeBolt', () {
    test('picks within the window-front range', () {
      final rng = math.Random(11);
      for (var i = 0; i < 200; i++) {
        final pos = pickBoltXZ(rng);
        expect(pos.x, inInclusiveRange(kBoltXMin, kBoltXMax));
        expect(pos.z, inInclusiveRange(kBoltZMin, kBoltZMax));
      }
    });

    test('buildStrikeBolt is seeded-deterministic end to end', () {
      final a = buildStrikeBolt(math.Random(99));
      final b = buildStrikeBolt(math.Random(99));
      expect(a.length, 65);
      expect(a.first.x, b.first.x);
      expect(a.first.z, b.first.z);
      expect(a.first.x, inInclusiveRange(kBoltXMin, kBoltXMax));
      expect(a.first.z, inInclusiveRange(kBoltZMin, kBoltZMax));
      expect(a.first.y, kBoltTopY);
      expect(a.last.y, kSeaLevel);
    });
  });

  group('darknessForExposure', () {
    test('day exposure maps to 0.3', () {
      expect(darknessForExposure(kDayExposure), closeTo(0.3, 1e-9));
    });

    test('night exposure maps to 1.0', () {
      expect(darknessForExposure(kNightExposure), closeTo(1.0, 1e-9));
    });

    test('monotonically increases with exposure', () {
      final low = darknessForExposure(0.5);
      final mid = darknessForExposure(1.0);
      final high = darknessForExposure(2.0);
      expect(low, lessThan(mid));
      expect(mid, lessThan(high));
    });

    test('clamps outside the day..night exposure range', () {
      expect(darknessForExposure(0.01), closeTo(0.3, 1e-9));
      expect(darknessForExposure(100), closeTo(1.0, 1e-9));
    });
  });

  group('peakEnvelopeTime', () {
    test('the envelope at the reported peak time is the maximum', () {
      final scheduler = LightningScheduler(random: math.Random(5));
      final pulses = scheduler.pulsesForStrike();
      final peakT = peakEnvelopeTime(pulses);
      final peakE = LightningScheduler.envelope(peakT, pulses);
      for (var t = 0.0; t < 0.7; t += 0.01) {
        expect(LightningScheduler.envelope(t, pulses), lessThanOrEqualTo(peakE + 1e-9));
      }
      expect(peakE, greaterThan(0.5));
    });
  });
}
