// STUB, replaced by Task 18.
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

class CurtainsFeature extends HotelFeature {
  @override
  String get id => 'curtains';
  @override
  String get label => 'Curtains';
  @override
  CostTier get tier => CostTier.free;
  @override
  bool get toggleable => false;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}
