import 'package:flutter_scene/scene.dart';

import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import 'lamps_feature.dart';

/// The bathroom ceiling lights cast point-light shadows (flutter_scene 0.24),
/// so the door frame and the basin throw shadows into each bathroom and
/// through its doorway. Ultra only: six cube faces per light per frame, two
/// lights (one per room) against the atlas cap of four point casters.
class BathShadowFeature extends HotelFeature {
  @override
  String get id => 'bath_shadow';
  @override
  String get label => 'Bath light shadows (point)';
  @override
  CostTier get tier => CostTier.mid;
  @override
  bool get defaultOn => false;

  final Set<PointLight> _shadowed = {};

  void _apply() {
    for (final light in LampsFeature.bathLights) {
      if (_shadowed.add(light)) {
        light
          ..castsShadow = true
          ..shadowMapResolution = 512
          ..shadowNear = 0.05;
      }
    }
    // Lamps remounted: forget lights that no longer exist.
    _shadowed.retainAll(LampsFeature.bathLights);
  }

  @override
  Future<void> mount(HotelContext ctx) async => _apply();

  @override
  void tick(HotelContext ctx, double dt) => _apply();

  @override
  void unmount(HotelContext ctx) {
    for (final light in _shadowed) {
      light.castsShadow = false;
    }
    _shadowed.clear();
  }
}
