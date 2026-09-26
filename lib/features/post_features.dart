// STUB, replaced by Task 14.
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

class ToneMappingFeature extends HotelFeature {
  @override
  String get id => 'tone_mapping';
  @override
  String get label => 'ACES tone mapping';
  @override
  CostTier get tier => CostTier.free;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}

class FogFeature extends HotelFeature {
  @override
  String get id => 'fog';
  @override
  String get label => 'Atmospheric fog';
  @override
  CostTier get tier => CostTier.cheap;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}

class BloomFeature extends HotelFeature {
  @override
  String get id => 'bloom';
  @override
  String get label => 'Bloom + lens flare';
  @override
  CostTier get tier => CostTier.expensive;
  @override
  bool get defaultOn => false;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}

class AoFeature extends HotelFeature {
  @override
  String get id => 'ao';
  @override
  String get label => 'GTAO ambient occlusion';
  @override
  CostTier get tier => CostTier.expensive;
  @override
  bool get defaultOn => false;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}

class GodRaysFeature extends HotelFeature {
  @override
  String get id => 'god_rays';
  @override
  String get label => 'God rays';
  @override
  CostTier get tier => CostTier.expensive;
  @override
  bool get defaultOn => false;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}

class SsrFeature extends HotelFeature {
  @override
  String get id => 'ssr';
  @override
  String get label => 'Screen-space reflections';
  @override
  CostTier get tier => CostTier.expensive;
  @override
  bool get defaultOn => false;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}
