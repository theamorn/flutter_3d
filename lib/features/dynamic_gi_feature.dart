import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import '../math/floor_plan.dart';

const double _depth =
    FloorPlan.roomDepth + FloorPlan.balconyDepth + FloorPlan.wallT;

/// The live probe grid's box: both rooms and balconies, floor to ceiling.
final Vector3 kGiCenter = Vector3(0, FloorPlan.ceiling / 2, _depth / 2);
final Vector3 kGiHalfExtents = Vector3(
  FloorPlan.roomWidth + FloorPlan.wallT,
  FloorPlan.ceiling / 2 + 0.1,
  _depth / 2,
);

/// 12 × 4 × 7 probes: about 1.5, 1.0 and 1.3 m apart.
final Vector3 kGiResolution = Vector3(12, 4, 7);

/// Dynamic GI ("Lumen-lite"): the engine's irradiance field, a light-probe
/// grid fed from each rendered frame and converging over a few frames, so
/// bounce light follows the sun, lamps and reading lights. With the baked
/// light probes on, this owns the diffuse term and the probes keep the
/// reflections. The settings live in composeLook.
class DynamicGiFeature extends HotelFeature {
  @override
  String get id => 'dynamic_gi';
  @override
  String get label => 'Dynamic GI (Lumen-lite probe grid)';
  @override
  CostTier get tier => CostTier.expensive;
  @override
  bool get defaultOn => false;

  Node? _volume;

  @override
  Future<void> mount(HotelContext ctx) async {
    final volume = _volume = Node(
      name: 'gi_volume',
      localTransform: Matrix4.translation(kGiCenter),
    )..addComponent(IrradianceVolumeComponent(
        extents: kGiHalfExtents.clone(),
        resolution: kGiResolution.clone(),
      ));
    ctx.scene.add(volume);
    ctx.look.dynamicGi = true;
    ctx.applyLook();
  }

  @override
  void unmount(HotelContext ctx) {
    final volume = _volume;
    if (volume != null) ctx.scene.remove(volume);
    _volume = null;
    ctx.look.dynamicGi = false;
    ctx.applyLook();
  }
}
