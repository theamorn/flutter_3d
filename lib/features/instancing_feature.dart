// STUB, replaced by Task 26.
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

class InstancingFeature extends HotelFeature {
  @override
  String get id => 'instancing';
  @override
  String get label => 'Instanced beach props';
  @override
  CostTier get tier => CostTier.cheap;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}
