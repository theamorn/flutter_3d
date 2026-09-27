import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_scene/kit.dart' show DayNightCycleComponent;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import '../math/schedulers.dart';

/// Bangkok-ish. Only sets [kTunedSunHeight]: the sun itself takes the
/// stylised path of [sunDirectionAt].
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

/// Aerosol (Mie) scattering: the engine's default by day; much thinner by
/// night, when the moon stands in view and a daytime-strength forward glow
/// turns the whole sky around it hazy white.
const double kDayMie = 0.005, kNightMie = 0.0008;

/// Lowest height (y of the unit direction) at which the sky renders its sun
/// or moon: the engine's physical sky goes exactly black at the horizon.
/// Kept small (≈ 0.6°) so the sky's own disk never strays from the disc drawn
/// over it; the brightness formula below holds the sky steady that low.
const double kMinSkyElevation = 0.01;

/// Height (0.5 = 30°) over which the sky fades from day to moonlit night and
/// the exposure adapts, as the sun sinks to the horizon.
const double kDayFadeElevation = 0.5;

/// The stylised path over the sea (the rooms look toward +Z): the sun rises
/// from the sea [kArcAzimuth] to the left (−X) at 06:00, climbs to
/// [kArcPeak] straight out over the sea at noon and sets as far to the right
/// at 18:00. Below the horizon it runs back the same way.
const double kArcAzimuth = 60 * degrees2Radians, kArcPeak = 55 * degrees2Radians;

Vector3 _arc(double hours) {
  final theta = math.pi * (hours - 6) / 12;
  final azimuth = -kArcAzimuth * math.cos(theta), elevation = kArcPeak * math.sin(theta);
  return Vector3(math.cos(elevation) * math.sin(azimuth), math.sin(elevation),
      math.cos(elevation) * math.cos(azimuth));
}

/// Unit vector toward the sun at [hours] (0..24).
Vector3 sunDirectionAt(double hours) => _arc(hours);

/// Unit vector toward the (full) moon: the sun's path, twelve hours later.
Vector3 moonDirectionAt(double hours) => _arc(hours + 12);

/// Angular radius of the drawn sun and moon discs (the real ones are
/// ≈ 0.27°; this reads at phone size), and of the sky's own sun disk, which
/// the drawn discs cover: it is never more than [kMinSkyElevation] away.
const double kDiscRadius = 1.25 * degrees2Radians, kSkyDiskRadius = 0.45 * degrees2Radians;

/// How far away the discs are drawn, centred on the camera: past the fog
/// cutoff, inside the camera's 900 m far plane.
const double kCelestialDistance = 898;

/// Brightness of the discs on screen (radiance × exposure).
const double kSunDiscOnScreen = 8, kMoonDiscOnScreen = 1.6;

/// flutter_scene_sky_physical.frag renders inscatter ∝ (energy · g)^1.5 with
/// g = 1 − e^−elevation. Solving for energy gives any wanted brightness
/// wherever the (lifted) sun or moon stands.
double _g(double y) => 1 - math.exp(-math.asin(y.clamp(-1.0, 1.0)));

/// Height of the sun the day exposure was tuned under: the kit's 15:00 sun
/// at [kLatitude]. The sky keeps that brightness all day, whatever the path.
final double kTunedSunHeight =
    DayNightCycleComponent(timeOfDay: 15, latitude: kLatitude).sunDirection.y;
final double _gTuned = _g(kTunedSunHeight);

/// Sunlight colour and intensity at height [y] > 0: daylight overhead,
/// golden toward the horizon (the kit's DayNightCycleComponent curve).
(Vector3, double) _daylight(double y) {
  final t = math.sin(y.clamp(0.0, 1.0) * math.pi * 0.5);
  return (Vector3(1.0, 0.95, 0.88) * t + Vector3(1.0, 0.55, 0.20) * (1 - t), 3.0 * t);
}

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
      {required this.night})
      : mieCoefficient = night ? kNightMie : kDayMie;

  /// Unit vector toward the body lighting the sky (the sun, or the moon),
  /// never lower than [kMinSkyElevation].
  final Vector3 lightDirection;
  final Vector3 lightColor;
  final double lightIntensity, exposure;

  /// Sky brightness relative to the 15:00 sky: 1 by day, fading to
  /// [kNightSkyBrightness] as the sun sets.
  final double skyBrightness;
  final bool night;

  /// PhysicalSkySource.mieCoefficient: the haze around the sun or moon.
  final double mieCoefficient;

  /// PhysicalSkySource.energy that renders [skyBrightness] with the body at
  /// [lightDirection].
  double get skyEnergy =>
      math.pow(skyBrightness, 2 / 3).toDouble() * _gTuned / _g(lightDirection.y);
}

/// The sky at [hours] (0..24), the sun on [sunDirectionAt]. As the sun
/// sinks from 30° to the horizon the sky fades to moonlit brightness while
/// exposure adapts; at the horizon the full moon, rising on the other side,
/// takes the sky over at the same brightness.
SkyState skyAt(double hours) {
  final sun = sunDirectionAt(hours);
  final day = _smooth(0, kDayFadeElevation, sun.y);
  double logLerp(double night, double day_, double t) =>
      math.exp(math.log(night) + (math.log(day_) - math.log(night)) * t);
  final exposure = logLerp(kNightExposure, kDayExposure, day);
  final brightness = logLerp(kNightSkyBrightness, 1, day);
  if (sun.y >= 0) {
    final (color, intensity) = _daylight(sun.y);
    return SkyState(_lift(sun), color, intensity, brightness, exposure, night: false);
  }
  final moon = moonDirectionAt(hours);
  return SkyState(_lift(moon), _moonColor, kMoonLight * _smooth(0, 0.25, moon.y),
      brightness, exposure,
      night: true);
}

/// Places a unit disc (DiscGeometry, facing +Y) [kCelestialDistance] from
/// [eye] toward [dir], facing the eye, sized to [kDiscRadius].
Matrix4 celestialDiscTransform(Vector3 eye, Vector3 dir) {
  final d = dir.normalized();
  final radius = kCelestialDistance * math.tan(kDiscRadius);
  return Matrix4.compose(eye + d * kCelestialDistance,
      Quaternion.fromTwoVectors(Vector3(0, 1, 0), -d), Vector3.all(radius));
}

/// A pale full moon: grey-white with darker maria, round (transparent
/// outside the disc). Pure pixels, generated once.
Uint8List moonPixels(int size) {
  final px = Uint8List(size * size * 4);
  // Maria: (u, v, radius) in the unit square, roughly the near side's.
  const maria = [
    (0.36, 0.35, 0.14), (0.55, 0.3, 0.1), (0.62, 0.48, 0.12),
    (0.42, 0.58, 0.09), (0.3, 0.52, 0.07), (0.7, 0.68, 0.06),
  ];
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final u = (x + 0.5) / size, v = (y + 0.5) / size;
      final r = math.sqrt((u - 0.5) * (u - 0.5) + (v - 0.5) * (v - 0.5)) * 2;
      var shade = 0.92 - 0.12 * r * r; // a little limb darkening
      for (final (mu, mv, mr) in maria) {
        final d = math.sqrt((u - mu) * (u - mu) + (v - mv) * (v - mv)) / mr;
        if (d < 1) shade -= 0.22 * (1 - d * d);
      }
      final o = (y * size + x) * 4;
      final c = (shade.clamp(0.0, 1.0) * 255).round();
      px[o] = c;
      px[o + 1] = c;
      px[o + 2] = (c * 1.04).round().clamp(0, 255);
      px[o + 3] = (((1 - r) * size / 2).clamp(0.0, 1.0) * 255).round(); // 1 px soft edge
    }
  }
  return px;
}

/// Physical sky + image-based lighting + a sun that shades and shadows from
/// the sky's own sun, all driven by the time-of-day slider. The sun and moon
/// are drawn as discs so they can rise out of and set into the sea (the
/// sky's own disk never goes below [kMinSkyElevation]).
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
  final List<Node> _discs = [];
  late UnlitMaterial _sunMaterial, _moonMaterial;
  Node? _sunDisc, _moonDisc;
  Vector3 _sunDir = Vector3(0, 1, 0), _moonDir = Vector3(0, -1, 0);
  Vector3 _sunRadiance = Vector3.zero(), _moonRadiance = Vector3.zero();

  @override
  Future<void> mount(HotelContext ctx) async {
    final sky = _sky = PhysicalSkySource(turbidity: kTurbidity, sunAngularRadius: kSkyDiskRadius);
    _environment = SkyEnvironment(sky,
        refresh: SkyEnvironmentRefresh.manual, faceResolution: 64, equirectWidth: 256);
    // The binding owns Scene.directionalLight and re-aims it at the sky's
    // "sun" every frame, so the light follows the sun by day and the moon at
    // night. Its colour and intensity are ours: the physical sky reports a
    // constant daylight sun even below the horizon.
    _sun = SunLight(sky, castsShadow: ctx.look.sunShadows);
    _exposureBefore = ctx.look.exposure;
    _sunMaterial = UnlitMaterial();
    _moonMaterial = UnlitMaterial(colorTexture: Texture2D.fromPixels(moonPixels(128), 128, 128));
    Node disc(String name, UnlitMaterial m) {
      final n = Node(name: name, mesh: Mesh(DiscGeometry(radius: 1, segments: 48), m))
        ..castsShadows = false
        ..raycastable = false;
      ctx.scene.add(n);
      _discs.add(n);
      return n;
    }

    _sunDisc = disc('sun_disc', _sunMaterial);
    _moonDisc = disc('moon_disc', _moonMaterial);
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
      ..energy = s.skyEnergy
      ..mieCoefficient = s.mieCoefficient;
    _sun!
      ..color = s.lightColor
      ..intensity = s.lightIntensity;
    ctx.look.exposure = s.exposure;
    ctx.applyLook();
    // The discs: the true (never lifted) sun and moon, as bright on screen
    // at any exposure. Golden low down, like the sunlight.
    final hours = ctx.timeOfDay.value;
    _sunDir = sunDirectionAt(hours);
    _moonDir = moonDirectionAt(hours);
    final (sunColor, _) = _daylight(math.max(_sunDir.y, 0));
    _sunRadiance = sunColor * (kSunDiscOnScreen / s.exposure);
    _moonRadiance = Vector3(0.92, 0.95, 1.0) * (kMoonDiscOnScreen / s.exposure);
  }

  @override
  void tick(HotelContext ctx, double dt) {
    // At most every 0.4 s while the slider moves, plus once after it stops.
    if (_rebake.tick(dt)) _environment?.invalidate();
    // Follow the camera, so the discs stay "at infinity". A body well below
    // the horizon is hidden (the sea covers it before then); storm clouds
    // (the rain feature's weather) hide both.
    final eye = ctx.camera.position;
    final clear = (1 - ctx.weather).clamp(0.0, 1.0);
    for (final (node, dir, material, radiance) in [
      (_sunDisc, _sunDir, _sunMaterial, _sunRadiance),
      (_moonDisc, _moonDir, _moonMaterial, _moonRadiance),
    ]) {
      if (node == null) continue;
      node.visible = dir.y > -0.2 && clear > 0.01;
      if (!node.visible) continue;
      node.localTransform = celestialDiscTransform(eye, dir);
      material.baseColorFactor = Vector4(radiance.x * clear, radiance.y * clear, radiance.z * clear, 1);
    }
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
    for (final n in _discs) {
      ctx.scene.remove(n);
    }
    _discs.clear();
    _sunDisc = null;
    _moonDisc = null;
    _sky = null;
    _environment = null;
    _sun = null;
  }
}
