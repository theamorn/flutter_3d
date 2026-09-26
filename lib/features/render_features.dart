// STUB, replaced by Task 15.
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

class ShadowsFeature extends HotelFeature {
  @override
  String get id => 'shadows';
  @override
  String get label => 'Sun shadows';
  @override
  CostTier get tier => CostTier.mid;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}

class MsaaFeature extends HotelFeature {
  @override
  String get id => 'msaa';
  @override
  String get label => 'MSAA anti-aliasing';
  @override
  CostTier get tier => CostTier.mid;
  @override
  bool get defaultOn => false;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}
