import 'package:flutter_3d/features/rain_feature.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rain begins outside the window and moves down at 11 m/s', () {
    final rain = createRainSystem()..spawner.rate = 1500;
    rain.step(1 / 60);
    final s = rain.storage;
    expect(s.aliveCount, greaterThan(0));
    for (var i = 0; i < s.aliveCount; i++) {
      expect(s.posX[i], inInclusiveRange(-15, 15));
      expect(s.posZ[i] + rainEmitterZ, inInclusiveRange(6.5, 36.5));
      expect(s.posY[i] + rainEmitterY, lessThan(15));
      expect(s.velY[i], closeTo(-11, 1e-6));
      expect(s.size[i], inInclusiveRange(0.014, 0.024));
      expect(s.colorA[i], closeTo(0.55, 1e-6));
    }
  });

  test('zero rain rate drains the live particles', () {
    final rain = createRainSystem()..spawner.rate = 1500;
    rain.step(0.25);
    expect(rain.storage.aliveCount, greaterThan(0));
    rain.spawner.rate = 0;
    for (var i = 0; i < 8; i++) {
      rain.step(0.25);
    }
    expect(rain.storage.aliveCount, 0);
  });

  test('balcony splash rate is ten percent and stays on balcony', () {
    final splash = createSplashSystem()..spawner.rate = 150;
    splash.step(1 / 60);
    final s = splash.storage;
    expect(s.aliveCount, greaterThan(0));
    for (var i = 0; i < s.aliveCount; i++) {
      expect(s.posX[i], inInclusiveRange(-8, 8));
      expect(s.posZ[i] + splashEmitterZ, inInclusiveRange(6.12, 7.8));
      expect(s.posY[i], greaterThanOrEqualTo(0));
    }
  });
}
