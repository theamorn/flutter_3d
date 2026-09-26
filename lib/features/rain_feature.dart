// STUB, replaced by Task 20.
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

class RainFeature extends HotelFeature {
  @override
  String get id => 'rain';
  @override
  String get label => 'Rain outside';
  @override
  CostTier get tier => CostTier.expensive;
  @override
  bool get defaultOn => false;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}
