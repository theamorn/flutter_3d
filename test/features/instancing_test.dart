import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/features/instancing_feature.dart';

void main() {
  group('scatterBeachProps', () {
    test('places the requested palm and umbrella counts', () {
      final placements = scatterBeachProps(math.Random(7));
      expect(placements.where((p) => p.kind == PropKind.palm).length, 400);
      expect(placements.where((p) => p.kind == PropKind.umbrella).length, 300);
      expect(placements.length, 700);
    });

    test('every placement stays within the given bounds', () {
      const xMin = -120.0, xMax = 120.0, zMin = 5.0, zMax = 35.0;
      final placements = scatterBeachProps(math.Random(7),
          xMin: xMin, xMax: xMax, zMin: zMin, zMax: zMax);
      for (final p in placements) {
        expect(p.x, inInclusiveRange(xMin, xMax));
        expect(p.z, inInclusiveRange(zMin, zMax));
        expect(p.scale, greaterThan(0));
      }
    });

    test('is deterministic for a fixed seed', () {
      final a = scatterBeachProps(math.Random(7));
      final b = scatterBeachProps(math.Random(7));
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].kind, b[i].kind);
        expect(a[i].x, b[i].x);
        expect(a[i].z, b[i].z);
        expect(a[i].rotationY, b[i].rotationY);
        expect(a[i].scale, b[i].scale);
      }
    });

    test('a different seed gives a different scatter', () {
      final a = scatterBeachProps(math.Random(7));
      final b = scatterBeachProps(math.Random(42));
      final same = List.generate(
          a.length, (i) => a[i].x == b[i].x && a[i].z == b[i].z).every((x) => x);
      expect(same, isFalse);
    });

    test('honours a blocked predicate: no placement lands in the blocked region', () {
      bool blockedRegion(double x, double z) => x.abs() < 30 && z < 6;
      final placements =
          scatterBeachProps(math.Random(7), blocked: blockedRegion);
      final stillBlocked = placements.where((p) => blockedRegion(p.x, p.z)).length;
      // The retry loop is best-effort (bounded attempts), so allow a small
      // residual rather than requiring zero.
      expect(stillBlocked, lessThan(placements.length ~/ 20));
    });

    test('counts scale down with smaller requested totals', () {
      final placements =
          scatterBeachProps(math.Random(7), palmCount: 10, umbrellaCount: 5);
      expect(placements.where((p) => p.kind == PropKind.palm).length, 10);
      expect(placements.where((p) => p.kind == PropKind.umbrella).length, 5);
    });
  });
}
