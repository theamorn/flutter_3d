import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

/// Rain thickens the mist: 1× clear, 2.5× in a full storm.
double fogThickness(double weather) => 1 + 1.5 * weather.clamp(0.0, 1.0);

/// Volumetric fog, engine-native: exponential height fog that is thick over
/// the sea and thin at the rooms, a glow toward the sun, and god-ray shafts
/// (the sun's volumetric shadows; they need Sun shadows on). The settings
/// live in composeLook.
class VolumetricFogFeature extends HotelFeature {
  @override
  String get id => 'volumetric_fog';
  @override
  String get label => 'Volumetric fog + light shafts (needs Sun shadows)';
  @override
  CostTier get tier => CostTier.expensive;
  @override
  bool get defaultOn => false;

  @override
  Future<void> mount(HotelContext ctx) async {
    ctx.look
      ..volumetricFog = true
      ..volumetricFogThickness = fogThickness(ctx.weather);
    ctx.applyLook();
  }

  @override
  void tick(HotelContext ctx, double dt) {
    final thickness = fogThickness(ctx.weather);
    if ((thickness - ctx.look.volumetricFogThickness).abs() < 0.02) return;
    ctx.look.volumetricFogThickness = thickness;
    ctx.applyLook();
  }

  @override
  void unmount(HotelContext ctx) {
    ctx.look
      ..volumetricFog = false
      ..volumetricFogThickness = 1.0;
    ctx.applyLook();
  }
}
