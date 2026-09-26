// STUB, replaced by Task 24.
import 'package:flutter/widgets.dart';
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

class ScreensFeature extends HotelFeature {
  @override
  String get id => 'screens';
  @override
  String get label => 'TV + PC screens';
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
