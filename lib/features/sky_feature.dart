// STUB, replaced by Task 12.
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

class SkyFeature extends HotelFeature {
  @override
  String get id => 'sky';
  @override
  String get label => 'Sky + time of day + IBL';
  @override
  CostTier get tier => CostTier.cheap;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}
