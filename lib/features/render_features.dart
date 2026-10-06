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
    if (_enabled && !identical(look.sunLight, _configured)) {
      _configure(look.sunLight);
    }
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

/// The anti-aliasing modes are one exclusive group: switching one on
/// switches the others off (FeatureRegistry).
const String kAaGroup = 'aa';

/// The mode to leave behind when the feature that set [mine] unmounts: off,
/// unless another mode has already taken over. Per-feature reconcile chains
/// can mount the new mode before the old one unmounts.
AntiAliasingMode aaAfterUnmount(
  AntiAliasingMode current,
  AntiAliasingMode mine,
) => current == mine ? AntiAliasingMode.none : current;

/// One anti-aliasing mode. The context starts at `none` (HotelContext), so
/// off really is off.
abstract class AaFeature extends HotelFeature {
  AaFeature(this.mode);
  final AntiAliasingMode mode;

  @override
  bool get defaultOn => false;
  @override
  String? get exclusiveGroup => kAaGroup;

  @override
  Future<void> mount(HotelContext ctx) async =>
      ctx.scene.antiAliasingMode = mode;

  @override
  void unmount(HotelContext ctx) => ctx.scene.antiAliasingMode = aaAfterUnmount(
    ctx.scene.antiAliasingMode,
    mode,
  );
}

class MsaaFeature extends AaFeature {
  MsaaFeature() : super(AntiAliasingMode.msaa);
  @override
  String get id => 'msaa';
  @override
  String get label => 'MSAA anti-aliasing';
  @override
  CostTier get tier => CostTier.mid;
}

class FxaaFeature extends AaFeature {
  FxaaFeature() : super(AntiAliasingMode.fxaa);
  @override
  String get id => 'fxaa';
  @override
  String get label => 'FXAA anti-aliasing';
  @override
  CostTier get tier => CostTier.cheap;
}

class SmaaFeature extends AaFeature {
  SmaaFeature() : super(AntiAliasingMode.smaa);
  @override
  String get id => 'smaa';
  @override
  String get label => 'SMAA anti-aliasing';
  @override
  CostTier get tier => CostTier.mid;
}

class TaaFeature extends AaFeature {
  TaaFeature() : super(AntiAliasingMode.taa);
  @override
  String get id => 'taa';
  @override
  String get label => 'TAA anti-aliasing';
  @override
  CostTier get tier => CostTier.mid;
}

/// The render scales are one exclusive group too. With neither on, the scene
/// draws every screen pixel. The hotel is GPU-bound (learning.md), so the
/// share of pixels is ultra's biggest lever.
const String kRenderScaleGroup = 'render_scale';

/// The scale to leave behind when the feature that set [mine] unmounts: full
/// resolution, unless the other scale has already taken over.
double renderScaleAfterUnmount(double current, double mine) =>
    current == mine ? 1.0 : current;

/// Renders the scene at [scale] of the screen's resolution, then scales it up.
abstract class RenderScaleFeature extends HotelFeature {
  RenderScaleFeature(this.scale);
  final double scale;

  @override
  bool get defaultOn => false;
  @override
  String? get exclusiveGroup => kRenderScaleGroup;
  @override
  CostTier get tier => CostTier.free;

  @override
  Future<void> mount(HotelContext ctx) async {
    ctx.renderScaleControl.selectFixed(id, scale);
    ctx.applyRenderScale();
  }

  @override
  void unmount(HotelContext ctx) {
    if (!ctx.renderScaleControl.release(id)) return;
    ctx.applyRenderScale();
  }
}

class RenderScale85Feature extends RenderScaleFeature {
  RenderScale85Feature() : super(0.85);
  @override
  String get id => 'render_scale_85';
  @override
  String get label => 'Render at 85% (72% of the pixels)';
}

class RenderScale75Feature extends RenderScaleFeature {
  RenderScale75Feature() : super(0.75);
  @override
  String get id => 'render_scale_75';
  @override
  String get label => 'Render at 75% (56% of the pixels)';
}

/// Lets two frames of GPU work queue before the scene re-presents its last
/// image (flutter_scene 0.24 `Scene.maxGpuFramesInFlight`; the engine's
/// default is 1). A measuring choice: full GPU throughput, at the cost of the
/// UI thread waiting on the GPU again, about half as long as before 0.24.
class GpuPacing2Feature extends HotelFeature {
  @override
  String get id => 'gpu_pacing_2';
  @override
  String get label => 'GPU pacing: 2 frames in flight';
  @override
  CostTier get tier => CostTier.free;
  @override
  bool get defaultOn => false;

  @override
  Future<void> mount(HotelContext ctx) async =>
      ctx.scene.maxGpuFramesInFlight = 2;

  @override
  void unmount(HotelContext ctx) => ctx.scene.maxGpuFramesInFlight = 1;
}

/// Starts at full resolution and lets flutter_scene 0.24 lower the render scale
/// (down to 60%) whenever frames miss 60 fps, recovering when they keep it.
/// In no preset: its numbers aren't reproducible, which is the point of the
/// fixed scales.
class RenderScaleAutoFeature extends HotelFeature {
  @override
  String get id => 'render_scale_auto';
  @override
  String get label => 'Render scale: Auto (adaptive, 60 fps target)';
  @override
  CostTier get tier => CostTier.free;
  @override
  bool get defaultOn => false;
  @override
  String? get exclusiveGroup => kRenderScaleGroup;

  @override
  Future<void> mount(HotelContext ctx) async {
    ctx.renderScaleControl.selectAuto(id);
    ctx.applyRenderScale();
    ctx.scene.renderQuality
      ..targetFrameRate = 60
      ..minRenderScale = 0.6
      ..maxRenderScale = 1.0;
  }

  @override
  void unmount(HotelContext ctx) {
    if (!ctx.renderScaleControl.release(id)) return;
    ctx.applyRenderScale();
  }
}
