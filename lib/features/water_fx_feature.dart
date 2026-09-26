// STUB, replaced by Task 19.
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

class WaterFxFeature extends HotelFeature {
  @override
  String get id => 'water_fx';
  @override
  String get label => 'Faucet + shower particles';
  @override
  CostTier get tier => CostTier.mid;
  @override
  bool get defaultOn => false;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}
