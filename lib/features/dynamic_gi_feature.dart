import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

/// Dynamic GI, a live light-probe grid. Task 12 builds it; until then it
/// does nothing.
class DynamicGiFeature extends HotelFeature {
  @override
  String get id => 'dynamic_gi';
  @override
  String get label => 'Dynamic GI (Lumen-lite probe grid)';
  @override
  CostTier get tier => CostTier.expensive;
  @override
  bool get defaultOn => false;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}
