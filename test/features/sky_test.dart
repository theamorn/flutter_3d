import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/features/sky_feature.dart';

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
    expect(s.skyEnergy, closeTo(1, 1e-9), reason: 'the look the exposure was tuned on');
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

  test('the sky never renders its light below 30° (the physical sky goes black there)', () {
    for (final h in hours()) {
      final d = skyAt(h).lightDirection;
      expect(d.length, closeTo(1, 1e-6), reason: 'at $h');
      expect(d.y, greaterThanOrEqualTo(kMinSkyElevation - 1e-6), reason: 'at $h');
    }
  });

  test('the rendered sky is as bright as scheduled, wherever its sun or moon stands', () {
    for (final h in hours()) {
      final s = skyAt(h);
      expect(rendered(s) / fullDay, closeTo(s.skyBrightness, 1e-6 + s.skyBrightness * 1e-6),
          reason: 'at $h');
    }
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
