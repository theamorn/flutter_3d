// STUB, replaced by Task 21.
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

class RainGlassFeature extends HotelFeature {
  @override
  String get id => 'rain_glass';
  @override
  String get label => 'Rain on the window (refraction)';
  @override
  CostTier get tier => CostTier.expensive;
  @override
  bool get defaultOn => false;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}
