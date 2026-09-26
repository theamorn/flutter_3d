import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/features/rain_glass_feature.dart';
import 'package:flutter_3d/hotel/feature.dart';

void main() {
  test('keeps the catalog contract: default-off, expensive, id rain_glass', () {
    final f = RainGlassFeature();
    expect(f.id, 'rain_glass');
    expect(f.defaultOn, false);
    expect(f.tier, CostTier.expensive);
    expect(f.toggleable, true);
  });

  test('dry weather keeps the original glass; rain puts the shader on', () {
    expect(rainGlassWanted(0), false,
        reason: 'with rain off the glass stays the cheap original material');
    expect(rainGlassWanted(kRainGlassMinWeather), false);
    expect(rainGlassWanted(0.01), true);
    expect(rainGlassWanted(1), true);
  });

  test('the shader clock advances by dt and wraps without losing its phase', () {
    expect(advanceRainGlassClock(1.5, 0.25), 1.75);
    expect(advanceRainGlassClock(kRainGlassClockWrap - 0.25, 0.5),
        closeTo(0.25, 1e-9));
    var t = 0.0;
    for (var i = 0; i < 100000; i++) {
      t = advanceRainGlassClock(t, 1 / 20);
    }
    expect(t, greaterThanOrEqualTo(0));
    expect(t, lessThan(kRainGlassClockWrap));
    expect(t, closeTo(5000 % kRainGlassClockWrap, 1e-6));
  });
}
