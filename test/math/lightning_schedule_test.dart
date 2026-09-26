import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/math/schedulers.dart';

void main() {
  test('strikes are at least minGap apart', () {
    final s = LightningScheduler(random: math.Random(1));
    final times = <double>[];
    var t = 0.0;
    for (var i = 0; i < 60 * 120; i++) {
      t += 1 / 60;
      if (s.tick(1 / 60, enabled: true)) times.add(t);
    }
    expect(times.length, greaterThan(5));
    for (var i = 1; i < times.length; i++) {
      expect(times[i] - times[i - 1], greaterThanOrEqualTo(4.5 - 1e-9));
    }
  });

  test('disabled never strikes', () {
    final s = LightningScheduler(random: math.Random(1));
    for (var i = 0; i < 6000; i++) { expect(s.tick(1 / 60, enabled: false), false); }
  });

  test('envelope: at most 3 pulses, 0 after 0.7 s, peaks ≤ 1', () {
    final s = LightningScheduler(random: math.Random(2));
    final pulses = s.pulsesForStrike();
    expect(pulses.length, inInclusiveRange(2, 3));
    var peak = 0.0;
    for (var t = 0.0; t < 0.7; t += 0.001) {
      peak = math.max(peak, LightningScheduler.envelope(t, pulses));
    }
    expect(peak, lessThanOrEqualTo(1.0));
    expect(LightningScheduler.envelope(0.75, pulses), 0.0);
  });
}
