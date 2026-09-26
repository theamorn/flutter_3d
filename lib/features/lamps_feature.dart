// STUB, replaced by Task 16.
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

class LampsFeature extends HotelFeature {
  @override
  String get id => 'lamps';
  @override
  String get label => 'Dynamic lamp lights';
  @override
  CostTier get tier => CostTier.mid;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}
