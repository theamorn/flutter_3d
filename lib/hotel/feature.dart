import 'hotel_context.dart';

enum CostTier { free, cheap, mid, expensive }

abstract class HotelFeature {
  String get id;
  String get label;
  CostTier get tier;
  bool get toggleable => true;
  bool get defaultOn => true;

  /// Build and attach nodes. May be async (asset loads). Must attach
  /// everything under nodes it can later remove in [unmount].
  Future<void> mount(HotelContext ctx);

  /// Remove every node/component/light added in [mount] and restore any
  /// shared state it changed (LookState flags, scene settings).
  void unmount(HotelContext ctx);

  /// Called every frame while mounted. dt in seconds.
  void tick(HotelContext ctx, double dt) {}
}
