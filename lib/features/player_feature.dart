// STUB, replaced by Task 10.
import 'package:flutter/widgets.dart';
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

class PlayerFeature extends HotelFeature {
  @override
  String get id => 'player';
  @override
  String get label => 'First-person walk';
  @override
  CostTier get tier => CostTier.free;
  @override
  bool get toggleable => false;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}

  /// Flutter widgets layered over the SceneView (placed by HotelPage).
  static Widget overlay(HotelContext ctx) => const SizedBox.shrink();
}
