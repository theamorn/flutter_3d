import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

/// Volumetric fog and light shafts. Task 7 builds it; until then it does
/// nothing.
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
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}
