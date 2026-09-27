import 'package:flutter/foundation.dart';
import 'package:flutter_3d/features/rain_feature.dart';
import 'package:flutter_3d/hotel/feature.dart';
import 'package:flutter_3d/hotel/feature_registry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the GPU-owning RainFeature in the registry.
class _Rain extends HotelFeature {
  @override
  String get id => 'rain';
  @override
  String get label => id;
  @override
  CostTier get tier => CostTier.expensive;
  @override
  bool get defaultOn => false;
  @override
  Future<void> mount(Object? ctx) async {}
  @override
  void unmount(Object? ctx) {}
}

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

  test('the rain button switches the rain feature on, and off only fades it', () async {
    final registry = FeatureRegistry([_Rain()], mountContext: null);
    final requested = ValueNotifier(false);
    await registry.mountDefaults();
    expect(registry.isEnabled('rain'), false); // off in the Effects menu

    await requestRain(registry, requested, true);
    expect(requested.value, true);
    expect(registry.isEnabled('rain'), true); // someone now consumes it

    await requestRain(registry, requested, false);
    expect(requested.value, false);
    expect(registry.isEnabled('rain'), true); // stays mounted to fade out
  });
}
