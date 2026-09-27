import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

/// Cached static shadows. Task 6 builds it; until then it does nothing.
class StaticShadowsFeature extends HotelFeature {
  @override
  String get id => 'static_shadows';
  @override
  String get label => 'Cached static shadows';
  @override
  CostTier get tier => CostTier.free;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}
