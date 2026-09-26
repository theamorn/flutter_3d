// STUB, replaced by Task 23.
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

class MirrorFeature extends HotelFeature {
  @override
  String get id => 'mirror';
  @override
  String get label => 'Bathroom mirror (planar reflection)';
  @override
  CostTier get tier => CostTier.expensive;
  @override
  bool get defaultOn => false;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}

class SeaReflectionFeature extends HotelFeature {
  @override
  String get id => 'sea_reflection';
  @override
  String get label => 'Sea planar reflection';
  @override
  CostTier get tier => CostTier.expensive;
  @override
  bool get defaultOn => false;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}
