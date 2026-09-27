import 'package:vector_math/vector_math.dart';
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

/// A camera jump longer than this in one frame is a teleport (a tour stop,
/// the perf probe): eye adaptation snaps to the new view instead of ramping
/// from the old one.
const double kTeleportDistance = 1.0;

bool isTeleport(Vector3 before, Vector3 after) =>
    (after - before).length > kTeleportDistance;

/// Auto exposure (eye adaptation): the engine meters each frame and eases
/// the exposure within ±kAutoExposureRangeEv of the sky's schedule, so the
/// room brightens again after the bright balcony. The settings live in
/// composeLook.
class AutoExposureFeature extends HotelFeature {
  @override
  String get id => 'auto_exposure';
  @override
  String get label => 'Auto exposure (eye adaptation)';
  @override
  CostTier get tier => CostTier.cheap;

  Vector3? _lastEye;

  @override
  Future<void> mount(HotelContext ctx) async {
    ctx.look.autoExposure = true;
    ctx.applyLook();
    _lastEye = null; // The first tick snaps to the current view.
  }

  @override
  void tick(HotelContext ctx, double dt) {
    final eye = ctx.camera.position;
    final last = _lastEye;
    if (last == null || isTeleport(last, eye)) {
      ctx.scene.autoExposure.reset();
    }
    _lastEye = eye.clone();
  }

  @override
  void unmount(HotelContext ctx) {
    ctx.look.autoExposure = false;
    ctx.applyLook();
    _lastEye = null;
  }
}
