import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';
import '../hotel/feature.dart';
import '../hotel/feature_registry.dart';
import '../hotel/hotel_context.dart';
import '../math/floor_plan.dart';
import '../math/schedulers.dart';

/// World Y the rain box spawns particles at: 15 m above the balcony floor.
const double rainEmitterY = 15.0;

/// World Z the rain box is centered on: the middle of the 30 m outside band
/// (x ∈ [−15, 15], z ∈ [6.5, 36.5]) that starts just past the balcony rail
/// (FloorPlan._rail = 7.8) so rain is always outside, never over the room.
const double rainEmitterZ = 21.5;

/// World Z the balcony-splash box is centered on: the balcony floor strip,
/// clear of the window wall (z = 6) and up to the railing (z = 7.8).
const double splashEmitterZ = 6.96;
const double _splashHalfZ = 0.84;

/// Full-storm spawn rate for rain (particles/second); splashes run at 10%.
const double _rainRateAtFullStorm = 1500.0;
const double _splashRateFraction = 0.10;

/// Fall time for 15 m at 11 m/s, so a rain streak's lifetime matches its
/// drop from the emitter to the balcony without excess capacity.
const double _rainLifetime = rainEmitterY / 11.0;

/// Kept short: splashes are a brief kick up off the balcony floor.
const double _splashLifetime = 0.35;

/// How long after rain is no longer requested the feature keeps its particle
/// nodes attached, even if particles are (implausibly) still alive.
const double _drainGraceSeconds = 3.0;

/// Rain tint, alpha-blended at 0.55 and darkened toward night so it never
/// glows white after dark (`clamp(sunIntensity, 0.15, 1)`).
Vector4 _rainColor(double sunIntensity) {
  final f = sunIntensity.clamp(0.15, 1.0);
  return Vector4(0.75 * f, 0.8 * f, 0.9 * f, 0.55);
}

/// Falling rain: a 30×30 m box 15 m above the balcony, outside only, heading
/// straight down at 11 m/s. Pure CPU maths (no GPU) so it's directly
/// testable; the caller drives [ParticleSystem.spawner]'s rate and reads
/// [ParticleSystem.storage] for the live particles.
ParticleSystem createRainSystem({double sunIntensity = 1.0}) => ParticleSystem(
      maxParticles: 2200,
      shape: BoxEmitterShape(
        halfExtents: Vector3(15, 0, 15),
        direction: Vector3(0, -1, 0),
      ),
      spawner: Spawner(rate: 0),
      startSpeed: const ConstantFloat(11.0),
      startSize: const UniformFloat(0.014, 0.024),
      startColor: ConstantColor(_rainColor(sunIntensity)),
      lifetime: const ConstantFloat(_rainLifetime),
      gravity: Vector3.zero(),
    );

/// Balcony splashes: a burst-style box at y = 0 on the balcony floor, kicking
/// particles up before gravity pulls them back down. Rate is set by the
/// caller (10% of the rain rate).
ParticleSystem createSplashSystem() => ParticleSystem(
      maxParticles: 512,
      shape: BoxEmitterShape(
        halfExtents: Vector3(FloorPlan.roomWidth, 0, _splashHalfZ),
        direction: Vector3(0, 1, 0),
      ),
      spawner: Spawner(rate: 0),
      startSpeed: const UniformFloat(0.5, 1.3),
      startSize: const UniformFloat(0.01, 0.02),
      startColor: ConstantColor(Vector4(0.82, 0.87, 0.94, 0.5)),
      lifetime: const ConstantFloat(_splashLifetime),
      gravity: Vector3(0, -9.8, 0),
    );

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// The HUD's rain button. Rain is off by default in the Effects menu and is
/// the only consumer of [rainRequested], so asking for rain switches it on.
/// Stopping leaves it mounted so the weather fades out instead of cutting.
Future<void> requestRain(FeatureRegistry registry, ValueNotifier<bool> rainRequested, bool on) {
  rainRequested.value = on;
  return on && !registry.isEnabled('rain') ? registry.setEnabled('rain', true) : Future.value();
}

/// Rain outside the rooms, and the weather level it drives. Owns
/// `ctx.weather` (smoothed from `ctx.rainRequested`) and, while raining,
/// thickens fog and darkens the sky through `LookState.weatherExposureScale`
/// (never `LookState.exposure`, which the sky feature owns).
class RainFeature extends HotelFeature {
  @override
  String get id => 'rain';
  @override
  String get label => 'Rain outside';
  @override
  CostTier get tier => CostTier.expensive;
  @override
  bool get defaultOn => false;

  ParticleSystem? _rainSystem;
  ParticleSystem? _splashSystem;
  Node? _rainNode;
  Node? _splashNode;
  bool _attached = false;
  double _offTimer = _drainGraceSeconds;

  // Throttle: only rewrite the look (and call applyLook) once ctx.weather has
  // moved more than 0.02 since the last write. fogDensity's own range
  // (0.004..0.016) never spans 0.02, so gating on the raw output would never
  // fire; gating on the driver (weather, 0..1) is what the brief's "only when
  // the value changes by more than 0.02" throttle is for.
  double _lastAppliedWeather = -1;

  @override
  Future<void> mount(HotelContext ctx) async {
    ctx.weather = 0.0;
    _rainSystem = createRainSystem(sunIntensity: ctx.look.sunLight?.intensity ?? 1.0);
    _splashSystem = createSplashSystem();

    final rainComponent = ParticleEmitterComponent(system: _rainSystem!)
      ..facing = BillboardFacing.velocityStretched
      ..velocityStretch = 0.03;
    final splashComponent = ParticleEmitterComponent(system: _splashSystem!);

    _rainNode = Node(name: 'rain_particles')
      ..position = Vector3(0, rainEmitterY, rainEmitterZ)
      ..shadowCastingMode = ShadowCastingMode.off;
    _rainNode!.addComponent(rainComponent);

    _splashNode = Node(name: 'rain_splash_particles')
      ..position = Vector3(0, 0, splashEmitterZ)
      ..shadowCastingMode = ShadowCastingMode.off;
    _splashNode!.addComponent(splashComponent);

    _attached = false;
    _offTimer = _drainGraceSeconds;
    _lastAppliedWeather = -1;

    ctx.look
      ..fogDensity = 0.004
      ..weatherExposureScale = 1.0;
  }

  @override
  void tick(HotelContext ctx, double dt) {
    final rainSys = _rainSystem, splashSys = _splashSystem;
    if (rainSys == null || splashSys == null) return;

    ctx.weather = approach(ctx.weather, ctx.rainRequested.value ? 1.0 : 0.0, dt);
    final weather = ctx.weather;

    rainSys.spawner.rate = _rainRateAtFullStorm * weather;
    splashSys.spawner.rate = _rainRateAtFullStorm * weather * _splashRateFraction;

    // Retint by current daylight so rain doesn't glow white at night.
    final sunIntensity = ctx.look.sunLight?.intensity ?? 1.0;
    rainSys.startColor = ConstantColor(_rainColor(sunIntensity));

    if (ctx.rainRequested.value) {
      _offTimer = 0;
    } else {
      _offTimer += dt;
    }
    final draining = rainSys.storage.aliveCount > 0 || splashSys.storage.aliveCount > 0;
    final forceOff = _offTimer >= _drainGraceSeconds;
    if (forceOff && draining) {
      rainSys.reset();
      splashSys.reset();
    }
    final active = ctx.rainRequested.value || (draining && !forceOff);

    if (active && !_attached) {
      ctx.scene.add(_rainNode!);
      ctx.scene.add(_splashNode!);
      _attached = true;
    } else if (!active && _attached) {
      ctx.scene.remove(_rainNode!);
      ctx.scene.remove(_splashNode!);
      _attached = false;
    }

    if ((weather - _lastAppliedWeather).abs() > 0.02) {
      ctx.look
        ..fogDensity = _lerp(0.004, 0.016, weather)
        ..weatherExposureScale = 1 - 0.35 * weather;
      ctx.applyLook();
      _lastAppliedWeather = weather;
    }
  }

  @override
  void unmount(HotelContext ctx) {
    if (_attached) {
      if (_rainNode != null) ctx.scene.remove(_rainNode!);
      if (_splashNode != null) ctx.scene.remove(_splashNode!);
    }
    _attached = false;
    _rainNode = null;
    _splashNode = null;
    _rainSystem = null;
    _splashSystem = null;
    ctx.weather = 0.0;
    ctx.look
      ..fogDensity = 0.004
      ..weatherExposureScale = 1.0;
    ctx.applyLook();
  }
}
