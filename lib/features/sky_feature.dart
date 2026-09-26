import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_scene/kit.dart' show DayNightCycleComponent;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import '../math/schedulers.dart';

/// Bangkok-ish.
const double kLatitude = 13.7;

/// Exposure in full daylight and fully adapted at night. Measured on the
/// simulator: at 1.0 the physical sky's IBL clips the whole room to white;
/// at 0.35 the afternoon room and sky read.
const double kDayExposure = 0.35, kNightExposure = 2.5;

/// Night sky brightness relative to the 15:00 sky, and the moonlight. At
/// night the moon (opposite the sun) lights a dim physical sky, so the room
/// keeps some blue ambient instead of the sun-sky's pure black. Tuned on the
/// simulator: dark, room still readable at kNightExposure.
const double kNightSkyBrightness = 0.012, kMoonLight = 0.25;

/// Clear tropical afternoon (the sky's default 10 is hazy and near-white).
const double kTurbidity = 3;

/// Lowest height (y of the unit direction; 0.5 = 30°) at which the sky
/// renders its sun or moon. The engine's physical sky has no ambient floor
/// and goes exactly black at the horizon, so dusk would be a black screen.
const double kMinSkyElevation = 0.5;

/// flutter_scene_sky_physical.frag renders inscatter ∝ (energy · g)^1.5 with
/// g = 1 − e^−elevation. Solving for energy gives any wanted brightness
/// wherever the (lifted) sun or moon stands.
double _g(double y) => 1 - math.exp(-math.asin(y.clamp(-1.0, 1.0)));

/// g of the 15:00 sun: the sky the day exposure was tuned on (energy 1).
final double _gTuned =
    _g(DayNightCycleComponent(timeOfDay: 15, latitude: kLatitude).sunDirection.y);

final Vector3 _moonColor = Vector3(0.6, 0.7, 1.0);

double _smooth(double e0, double e1, double x) {
  final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// [d] raised to at least [kMinSkyElevation], keeping its compass heading.
Vector3 _lift(Vector3 d) {
  if (d.y >= kMinSkyElevation) return d;
  final flat = Vector2(d.x, d.z);
  if (flat.length2 < 1e-12) flat.setValues(0, 1);
  flat
    ..normalize()
    ..scale(math.sqrt(1 - kMinSkyElevation * kMinSkyElevation));
  return Vector3(flat.x, kMinSkyElevation, flat.y);
}

/// The sky and its light for one time of day.
class SkyState {
  SkyState(this.lightDirection, this.lightColor, this.lightIntensity, this.skyBrightness,
      this.exposure,
      {required this.night});

  /// Unit vector toward the body lighting the sky (the sun, or the moon),
  /// never lower than [kMinSkyElevation].
  final Vector3 lightDirection;
  final Vector3 lightColor;
  final double lightIntensity, exposure;

  /// Sky brightness relative to the 15:00 sky: 1 by day, fading to
  /// [kNightSkyBrightness] as the sun sets.
  final double skyBrightness;
  final bool night;

  /// PhysicalSkySource.energy that renders [skyBrightness] with the body at
  /// [lightDirection].
  double get skyEnergy =>
      math.pow(skyBrightness, 2 / 3).toDouble() * _gTuned / _g(lightDirection.y);
}

/// The sky at [hours] (0..24). The kit's DayNightCycleComponent, left
/// unmounted, supplies the solar arc and the sun's colour and intensity
/// (its evaluators are pure). As the sun sinks from 30° to the horizon the
/// sky fades to moonlit brightness while exposure adapts; at the horizon a
/// full moon, opposite the sun, takes the sky over at the same brightness.
SkyState skyAt(double hours) {
  final cycle = DayNightCycleComponent(timeOfDay: hours, latitude: kLatitude);
  final sun = cycle.sunDirection;
  final day = _smooth(0, kMinSkyElevation, sun.y);
  double logLerp(double night, double day_, double t) =>
      math.exp(math.log(night) + (math.log(day_) - math.log(night)) * t);
  final exposure = logLerp(kNightExposure, kDayExposure, day);
  final brightness = logLerp(kNightSkyBrightness, 1, day);
  if (sun.y >= 0) {
    final l = cycle.evaluateLighting();
    return SkyState(_lift(sun), l.sunColor, l.sunIntensity, brightness, exposure,
        night: false);
  }
  final moon = -sun;
  return SkyState(_lift(moon), _moonColor, kMoonLight * _smooth(0, 0.25, moon.y),
      brightness, exposure,
      night: true);
}

/// Physical sky + image-based lighting + a sun that shades and shadows from
/// the sky's own sun, all driven by the time-of-day slider.
class SkyFeature extends HotelFeature {
  @override
  String get id => 'sky';
  @override
  String get label => 'Sky + time of day + IBL';
  @override
  CostTier get tier => CostTier.cheap;

  final RebakeThrottle _rebake = RebakeThrottle();
  PhysicalSkySource? _sky;
  SkyEnvironment? _environment;
  SunLight? _sun;
  VoidCallback? _onTime;
  double _exposureBefore = 1;

  @override
  Future<void> mount(HotelContext ctx) async {
    final sky = _sky = PhysicalSkySource(turbidity: kTurbidity);
    _environment = SkyEnvironment(sky,
        refresh: SkyEnvironmentRefresh.manual, faceResolution: 64, equirectWidth: 256);
    // The binding owns Scene.directionalLight and re-aims it at the sky's
    // "sun" every frame, so the light follows the sun by day and the moon at
    // night. Its colour and intensity are ours: the physical sky reports a
    // constant daylight sun even below the horizon.
    _sun = SunLight(sky, castsShadow: ctx.look.sunShadows);
    _exposureBefore = ctx.look.exposure;
    ctx.look
      ..skybox = Skybox(sky)
      ..skyEnvironment = _environment
      ..sunLight = _sun;
    _apply(ctx);
    void onTime() {
      _apply(ctx);
      _rebake.markDirty();
    }

    _onTime = onTime;
    ctx.timeOfDay.addListener(onTime);
  }

  /// Aims the sky (the visible sky updates at once), sets its light and the
  /// exposure. The IBL catches up on the throttle.
  void _apply(HotelContext ctx) {
    final s = skyAt(ctx.timeOfDay.value);
    _sky!
      ..sunDirection = s.lightDirection
      ..energy = s.skyEnergy;
    _sun!
      ..color = s.lightColor
      ..intensity = s.lightIntensity;
    ctx.look.exposure = s.exposure;
    ctx.applyLook();
  }

  @override
  void tick(HotelContext ctx, double dt) {
    // At most every 0.4 s while the slider moves, plus once after it stops.
    if (_rebake.tick(dt)) _environment?.invalidate();
  }

  @override
  void unmount(HotelContext ctx) {
    final onTime = _onTime;
    if (onTime != null) ctx.timeOfDay.removeListener(onTime);
    _onTime = null;
    ctx.look
      ..skybox = null
      ..skyEnvironment = null
      ..sunLight = null
      ..exposure = _exposureBefore;
    ctx.applyLook();
    _sky = null;
    _environment = null;
    _sun = null;
  }
}
