import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

/// Auto exposure (eye adaptation). Task 5 builds it; until then it does
/// nothing.
class AutoExposureFeature extends HotelFeature {
  @override
  String get id => 'auto_exposure';
  @override
  String get label => 'Auto exposure (eye adaptation)';
  @override
  CostTier get tier => CostTier.cheap;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}
