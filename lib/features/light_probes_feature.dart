import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

/// Baked light probes: each room's captured lighting as its ambient and
/// reflections. Task 11 builds it; until then it does nothing.
class LightProbesFeature extends HotelFeature {
  @override
  String get id => 'light_probes';
  @override
  String get label => 'Baked light probes (room ambient + reflections)';
  @override
  CostTier get tier => CostTier.cheap;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}
