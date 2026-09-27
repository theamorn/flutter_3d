import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

/// Reading spot lights. Task 10 builds it; until then it does nothing.
class SpotLightsFeature extends HotelFeature {
  @override
  String get id => 'spot_lights';
  @override
  String get label => 'Reading spot lights (shadowed)';
  @override
  CostTier get tier => CostTier.mid;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}
