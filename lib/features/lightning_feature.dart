// STUB, replaced by Task 22.
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

class LightningFeature extends HotelFeature {
  @override
  String get id => 'lightning';
  @override
  String get label => 'Lightning storm';
  @override
  CostTier get tier => CostTier.mid;
  @override
  bool get defaultOn => false;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}
