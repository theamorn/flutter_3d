import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/features/ocean_feature.dart';
import 'package:flutter_3d/features/sky_feature.dart';
import 'package:flutter_3d/hotel/look.dart';
import 'package:flutter_3d/math/floor_plan.dart';

Iterable<double> hours({double step = 0.05}) sync* {
  for (var h = 0.0; h <= 24.0; h += step) {
    yield h;
  }
}

/// How bright flutter_scene 0.23's physical sky renders (flutter_scene_sky_
/// physical.frag): inscatter ∝ (energy · (1 − e^−elevation))^1.5.
double rendered(SkyState s) =>
    math.pow(s.skyEnergy * (1 - math.exp(-math.asin(s.lightDirection.y))), 1.5).toDouble();

void main() {
  final fullDay = rendered(skyAt(15));

  test('15:00: the afternoon sun lights the sky, high in the west (+X)', () {
    final s = skyAt(15);
    expect(s.night, false);
    expect(s.lightDirection.y, greaterThan(0.5));
    expect(s.lightDirection.x, greaterThan(0));
    expect(s.lightIntensity, greaterThan(1));
    expect(s.skyBrightness, 1);
    expect(rendered(s), closeTo(math.pow(1 - math.exp(-math.asin(kTunedSunHeight)), 1.5), 1e-6),
        reason: 'the sky the day exposure was tuned under');
    expect(s.exposure, closeTo(kDayExposure, 1e-9));
  });

  test('noon sun stands over the sea side (+Z), so it shines in the window', () {
    expect(skyAt(12).lightDirection.z, greaterThan(0));
  });

  test('23:00: the moon lights a dim sky from above; the eye adapts', () {
    final s = skyAt(23);
    expect(s.night, true);
    expect(s.lightDirection.y, greaterThan(0), reason: 'the moon is up');
    expect(s.skyBrightness, closeTo(kNightSkyBrightness, 1e-12));
    expect(s.lightIntensity, greaterThan(0));
    expect(s.lightIntensity, lessThan(0.5));
    expect(s.exposure, closeTo(kNightExposure, 1e-9));
    expect(kNightExposure, greaterThan(kDayExposure));
  });

  test('the sky never renders its light below the horizon (the physical sky goes black there)', () {
    for (final h in hours()) {
      final d = skyAt(h).lightDirection;
      expect(d.length, closeTo(1, 1e-6), reason: 'at $h');
      expect(d.y, greaterThanOrEqualTo(kMinSkyElevation - 1e-6), reason: 'at $h');
    }
  });

  group('sun and moon path', () {
    test('the sun rises from the sea on the left, peaks over the sea at noon, sets on the right', () {
      final rise = sunDirectionAt(6), noon = sunDirectionAt(12), set = sunDirectionAt(18);
      expect(rise.y, closeTo(0, 1e-6));
      expect(rise.x, lessThan(-0.5), reason: 'left of the sea view (−X)');
      expect(rise.z, greaterThan(0.3), reason: 'out over the sea (+Z)');
      expect(set.y, closeTo(0, 1e-6));
      expect(set.x, greaterThan(0.5), reason: 'right of the sea view (+X)');
      expect(set.z, greaterThan(0.3));
      expect(noon.x, closeTo(0, 1e-6));
      expect(noon.z, greaterThan(0));
      for (final h in hours()) {
        final d = sunDirectionAt(h);
        expect(d.length, closeTo(1, 1e-6));
        expect(d.y, lessThanOrEqualTo(noon.y + 1e-9), reason: 'noon is the highest, at $h');
        final up = h > 6 + 1e-9 && h < 18 - 1e-9;
        if (up) expect(d.y, greaterThan(0), reason: 'day at $h');
        if (h < 6 - 1e-9 || h > 18 + 1e-9) expect(d.y, lessThan(0), reason: 'night at $h');
      }
    });

    test('the moon takes the same path twelve hours later: up exactly while the sun is down', () {
      for (final h in hours()) {
        final moon = moonDirectionAt(h), sun = sunDirectionAt(h);
        final later = sunDirectionAt(h + 12);
        expect((moon - later).length, lessThan(1e-6), reason: 'at $h');
        expect(moon.y, closeTo(-sun.y, 1e-6), reason: 'at $h');
      }
      expect(moonDirectionAt(0).y, greaterThan(0.8), reason: 'high at midnight');
    });

    test('the sky\'s own disk always hides behind the drawn sun or moon', () {
      for (final h in hours()) {
        final s = skyAt(h);
        final body = s.night ? moonDirectionAt(h) : sunDirectionAt(h);
        final apart = math.acos(s.lightDirection.dot(body).clamp(-1.0, 1.0));
        expect(apart + kSkyDiskRadius, lessThan(kDiscRadius), reason: 'at $h');
      }
    });

    test('the discs sit past the fog cutoff and inside the far plane; the sea stays fogged', () {
      expect(kCelestialDistance, greaterThan(kFogCutoffDistance));
      // Every point of a disc is at most distance / cos(radius) away.
      expect(kCelestialDistance / math.cos(kDiscRadius), lessThan(900), reason: 'camera fovFar');
      var farthestSea = 0.0;
      for (final x in [-FloorPlan.roomWidth, FloorPlan.roomWidth]) {
        for (final z in [-FloorPlan.wallT, FloorPlan.roomDepth + FloorPlan.balconyDepth]) {
          final eye = Vector3(x, FloorPlan.eyeHeight, z);
          for (final cx in [kSea.min.x, kSea.max.x]) {
            for (final cz in [kSea.min.z, kSea.max.z]) {
              farthestSea = math.max(farthestSea, (Vector3(cx, kSeaLevel, cz) - eye).length);
            }
          }
        }
      }
      expect(farthestSea, lessThan(kFogCutoffDistance));
    });

    test('a disc faces the camera, centred along its direction', () {
      final eye = Vector3(-3, 1.6, 4);
      final dir = sunDirectionAt(8);
      final m = celestialDiscTransform(eye, dir);
      final centre = m.transformed3(Vector3.zero());
      expect((centre - (eye + dir * kCelestialDistance)).length, lessThan(1e-2));
      // The disc geometry faces +Y: after the transform it faces the eye.
      final normal = (m.transformed3(Vector3(0, 1, 0)) - centre)..normalize();
      expect(normal.dot(-dir), closeTo(1, 1e-4));
      final rim = m.transformed3(Vector3(1, 0, 0)) - centre;
      expect(rim.length, closeTo(kCelestialDistance * math.tan(kDiscRadius), 1e-2));
    });
  });

  test('the rendered sky is as bright as scheduled, wherever its sun or moon stands', () {
    for (final h in hours()) {
      final s = skyAt(h);
      expect(rendered(s) / fullDay, closeTo(s.skyBrightness, 1e-6 + s.skyBrightness * 1e-6),
          reason: 'at $h');
    }
  });

  test('by night the haze thins, so the moon wears a tight halo, not a hazy glow', () {
    expect(skyAt(23).mieCoefficient, lessThan(skyAt(15).mieCoefficient / 4));
    expect(skyAt(15).mieCoefficient, kDayMie);
  });

  test('dusk is never darker than midnight (no black frames while dragging)', () {
    double onScreen(double h) => skyAt(h).skyBrightness * skyAt(h).exposure;
    for (final h in hours()) {
      expect(onScreen(h), greaterThanOrEqualTo(onScreen(0) - 1e-9), reason: 'at $h');
    }
  });

  test('dragging through sunset never jumps the lighting', () {
    var prev = skyAt(16.0);
    for (var h = 16.05; h <= 20.0; h += 0.05) {
      final s = skyAt(h);
      expect(s.exposure / prev.exposure, inInclusiveRange(1 / 1.1, 1.1),
          reason: 'exposure at $h');
      expect(s.skyBrightness / prev.skyBrightness, inInclusiveRange(1 / 1.25, 1.25),
          reason: 'sky at $h');
      expect((s.lightIntensity - prev.lightIntensity).abs(), lessThan(0.2),
          reason: 'light at $h');
      if (s.lightDirection.dot(prev.lightDirection) < 0.99) {
        // The sun hands the sky over to the moon only while both are dark.
        expect(s.lightIntensity, lessThan(0.1), reason: 'handover at $h');
        expect(prev.lightIntensity, lessThan(0.1), reason: 'handover at $h');
      }
      prev = s;
    }
  });
}
