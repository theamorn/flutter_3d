import 'dart:math' as math;

import 'package:flutter_3d/render/wind.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  test('blows the way the island grass already bends', () {
    expect(kWindDirection.length, closeTo(1, 1e-6)); // float32 vectors
    final grass = math.atan2(0.07, 0.16);
    expect(math.atan2(kWindDirection.y, kWindDirection.x), closeTo(grass, 0.02));
  });

  test('a storm blows harder than fair weather, and gusts stay in 0..1', () {
    for (final t in [0.0, 1.3, 17.0, 400.0]) {
      final calm = windFor(weather: 0, time: t);
      final storm = windFor(weather: 1, time: t);
      expect(storm.speed, greaterThan(calm.speed), reason: '$t');
      expect(calm.gust, inInclusiveRange(0, 1));
      expect(storm.gust, inInclusiveRange(0, 1));
    }
  });

  test('is a pure function of weather and time, finite for any input', () {
    expect(windFor(weather: 0.4, time: 9).speed, windFor(weather: 0.4, time: 9).speed);
    for (final w in [-2.0, double.nan, 0.5, 9.0]) {
      for (final t in [-5.0, 0.0, 1e6, double.nan]) {
        final wind = windFor(weather: w, time: t);
        for (final v in [wind.speed, wind.gust, ...wind.shaderParams.storage]) {
          expect(v.isFinite, isTrue, reason: '$w $t');
        }
      }
    }
  });

  test('the grass keeps the exact wind it had before the shared model', () {
    for (final w in [0.0, 0.5, 1.0]) {
      final gust = 1.0 + 1.3 * w;
      final v = grassWindVector(w);
      expect(v.x, closeTo(0.16 * gust, 1e-6));
      expect(v.y, closeTo(0.07 * gust, 1e-6));
      expect(v.z, closeTo(1.0 + 0.6 * w, 1e-6));
      expect(v.w, 0);
    }
  });

  test('rain on a window drifts along the pane toward where the wind blows', () {
    final storm = windFor(weather: 1, time: 3);
    // The hotel panes' u runs toward world +X in both rooms (room B's u is
    // flipped back by the builder); a pane with u the other way drifts the
    // other way in u, so its drops still go downwind. The wind blows +X.
    final along = rainGlassSkew(storm, uAxis: Vector3(1, 0, 0));
    final against = rainGlassSkew(storm, uAxis: Vector3(-1, 0, 0));
    expect(along, greaterThan(0.05));
    expect(against, closeTo(-along, 1e-6));
    final roomB = along;
    // A pane whose u runs along the wind's minor axis drifts less.
    expect(rainGlassSkew(storm, uAxis: Vector3(0, 0, 1)).abs(), lessThan(roomB));
    expect(rainGlassSkew(windFor(weather: 0, time: 3), uAxis: Vector3(1, 0, 0)), lessThan(roomB));
    expect(rainGlassSkew(storm, uAxis: Vector3(0, 1, 0)), 0, reason: 'no horizontal axis');
  });

  test('falling rain drifts downwind, harder in a storm, never up or down', () {
    final calm = rainDriftAcceleration(windFor(weather: 0, time: 4));
    final storm = rainDriftAcceleration(windFor(weather: 1, time: 4));
    expect(storm.y, 0);
    expect(storm.length, greaterThan(calm.length));
    final dir = Vector2(storm.x, storm.z)..normalize();
    expect(dir.dot(kWindDirection), closeTo(1, 1e-6));
    expect(storm.length, lessThan(6), reason: 'streaks lean, they do not fly sideways');
  });

  test('the shader parameters carry direction times speed, gust and a clock', () {
    final wind = windFor(weather: 0.3, time: 12.5);
    final p = wind.shaderParams;
    expect(p.x, closeTo(kWindDirection.x * wind.speed, 1e-6));
    expect(p.y, closeTo(kWindDirection.y * wind.speed, 1e-6));
    expect(p.z, closeTo(wind.gust, 1e-6));
    expect(p.w, closeTo(12.5, 1e-6));
  });
}
