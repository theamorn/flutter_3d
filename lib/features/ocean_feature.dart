// STUB, replaced by Task 13.
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

class OceanFeature extends HotelFeature {
  @override
  String get id => 'ocean';
  @override
  String get label => 'Ocean + beach view';
  @override
  CostTier get tier => CostTier.cheap;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}
