// STUB, replaced by Task 9.
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

class RoomsFeature extends HotelFeature {
  @override
  String get id => 'rooms';
  @override
  String get label => 'Rooms';
  @override
  CostTier get tier => CostTier.free;
  @override
  bool get toggleable => false;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}
