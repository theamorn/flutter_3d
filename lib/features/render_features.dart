import 'package:flutter_scene/scene.dart';
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import '../hotel/look.dart';

/// Shadow range, metres: both rooms and balconies from anywhere inside, so
/// the two cascades spend their resolution on the rooms, not the beach.
const double kShadowDistance = 25;

/// How much a sun shadow also darkens the sky's image-based light. The sky
/// IBL has no occlusion, so without this a room under a ceiling reads as
/// lit as the sunny balcony. 0.5 won the A/B against 0 and 0.8 on the sim.
const double kShadowAmbient = 0.5;

/// Keeps the sky's sun (LookState.sunLight) casting shadows while enabled,
/// including a sun the sky creates later when it is remounted.
class SunShadows {
  bool _enabled = false;
  SunLight? _configured;

  bool get enabled => _enabled;

  void enable(LookState look) {
    _enabled = true;
    look.sunShadows = true; // the sky builds its next sun with this
    _configure(look.sunLight);
  }

  void disable(LookState look) {
    _enabled = false;
    look.sunShadows = false;
    final sun = look.sunLight;
    if (sun != null) {
      sun
        ..castsShadow = false
        ..shadowAmbientStrength = 0;
    }
    _configured = null;
  }

  /// Call every frame: configures a sun that replaced the one we set up.
  void sync(LookState look) {
    if (_enabled && !identical(look.sunLight, _configured)) _configure(look.sunLight);
  }

  void _configure(SunLight? sun) {
    _configured = sun;
    if (sun == null) return; // sky off: the intent waits in look.sunShadows
    sun
      ..castsShadow = true
      ..shadowMapResolution = 2048
      ..shadowCascadeCount = 2
      ..shadowMaxDistance = kShadowDistance
      ..shadowAmbientStrength = kShadowAmbient;
  }
}

class ShadowsFeature extends HotelFeature {
  @override
  String get id => 'shadows';
  @override
  String get label => 'Sun shadows';
  @override
  CostTier get tier => CostTier.mid;

  final SunShadows _shadows = SunShadows();

  @override
  Future<void> mount(HotelContext ctx) async {
    _shadows.enable(ctx.look);
    ctx.applyLook();
  }

  @override
  void unmount(HotelContext ctx) {
    _shadows.disable(ctx.look);
    ctx.applyLook();
  }

  @override
  void tick(HotelContext ctx, double dt) => _shadows.sync(ctx.look);
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
  Future<void> mount(HotelContext ctx) async =>
      ctx.scene.antiAliasingMode = AntiAliasingMode.msaa;

  @override
  void unmount(HotelContext ctx) => ctx.scene.antiAliasingMode = AntiAliasingMode.none;
}
