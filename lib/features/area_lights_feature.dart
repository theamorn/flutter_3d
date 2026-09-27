import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

/// Area lights (TV glow, window light). Task 8 builds it; until then it does
/// nothing.
class AreaLightsFeature extends HotelFeature {
  @override
  String get id => 'area_lights';
  @override
  String get label => 'Area lights (TV glow, window light)';
  @override
  CostTier get tier => CostTier.cheap;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}
