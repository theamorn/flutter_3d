import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

/// Fragments farther than this skip fog. The sky feature's sun and moon
/// discs stand beyond it (so haze doesn't erase them); the sea's farthest
/// corner, seen from anywhere in the rooms, is nearer (so it stays fogged).
/// Pinned by sky_test.
const double kFogCutoffDistance = 895;

/// Auto exposure's reach either side of the sky's scheduled exposure, in EV
/// stops: enough to adapt between the room and the balcony without undoing
/// the sky feature's day/night schedule.
const double kAutoExposureRangeEv = 1.5;

/// Volumetric fog: exponential density at the sea (y = −90, ocean_feature's
/// kSeaLevel), falling off with height so the rooms 90 m up see about 1 % of
/// it (e^(−0.05 · 90) ≈ 0.011): mist over the sea, clear air on the balcony.
/// Denser and steeper than a plain fog, so switching to it reads as mist
/// settling on the sea rather than the same haze.
const double kVolumetricFogDensity = 0.03, kVolumetricFogFalloff = 0.05;
const double kVolumetricFogHeight = -90;

/// The fog's glow toward the sun.
const double kVolumetricSunInScatter = 0.6;

/// God rays while volumetric fog is on: thicker, longer shafts.
const double kVolumetricGodRaysDensity = 0.35,
    kVolumetricGodRaysIntensity = 1.2,
    kVolumetricGodRaysMaxDistance = 250;

/// Dynamic GI's leak guard: the depth-moment visibility test nearly at full
/// strength, with a bias (a fraction of the 1 m vertical probe spacing) under
/// the thinnest wall, the bathroom's 6 cm.
const double kGiVisibility = 0.9, kGiVisibilityBias = 0.05;

class LookState {
  bool toneMapping = true,
      fog = false,
      bloom = false,
      ao = false,
      godRays = false,
      ssr = false;
  double exposure = 1.0;

  /// Multiplies [exposure] in [composeLook]. Task 20 (rain) darkens the sky
  /// as weather builds (`1 - 0.35 * weather`) without touching [exposure]
  /// itself, which the sky feature (Task 12) owns and rewrites on every
  /// time-of-day change. Reset to 1.0 when rain unmounts.
  double weatherExposureScale = 1.0;
  double environmentIntensity = 1.0;
  double fogDensity = 0.004;
  Skybox? skybox; // Task 12 sets
  SkyEnvironment? skyEnvironment; // Task 12 sets
  SunLight? sunLight; // Task 12 sets

  /// Whether the sun casts shadows. Task 15's toggle writes it; Task 12 builds
  /// its SunLight with it, so the switch survives the sky being remounted.
  bool sunShadows = false;

  /// Task 5 (auto exposure), Task 7 (volumetric fog), Task 12 (dynamic GI).
  bool autoExposure = false, volumetricFog = false, dynamicGi = false;

  /// Multiplies the volumetric fog's density; the fog feature raises it with
  /// the weather.
  double volumetricFogThickness = 1.0;
}

/// The ONLY place an EnvironmentSettings literal is built (engine rule 1).
EnvironmentSettings composeLook(LookState s) {
  final exposure = s.exposure * s.weatherExposureScale;
  final volumetric = s.volumetricFog;
  return EnvironmentSettings(
      skybox: s.skybox,
      skyEnvironment: s.skyEnvironment,
      sunLight: s.sunLight,
      // `linear` is the engine's "no tone curve" mode (there is no `none`).
      toneMapping: s.toneMapping ? ToneMappingMode.aces : ToneMappingMode.linear,
      exposure: exposure,
      environmentIntensity: s.environmentIntensity,
      bloomEnabled: s.bloom,
      // The engine thresholds linear radiance before exposure; keep the
      // threshold at 1.0 on screen whatever the exposure (the sky runs 0.35,
      // and rain further scales it by weatherExposureScale).
      bloomThreshold: 1.0 / exposure,
      lensFlareEnabled: s.bloom,
      lensFlareHaloIntensity: 0.3,
      ambientOcclusionEnabled: s.ao,
      ambientOcclusionMethod: AmbientOcclusionMethod.groundTruth, // GTAO
      ambientOcclusionBentNormals: true,
      ambientOcclusionHalfResolution: true,
      fogEnabled: s.fog || volumetric,
      fogDensity: volumetric ? kVolumetricFogDensity * s.volumetricFogThickness : s.fogDensity,
      fogHeight: volumetric ? kVolumetricFogHeight : 0.0,
      fogHeightFalloff: volumetric ? kVolumetricFogFalloff : 0.0,
      fogSunInScatter: volumetric ? kVolumetricSunInScatter : 0.0,
      fogCutoffDistance: kFogCutoffDistance,
      fogSkyColorInfluence: 1.0,
      fogColor: Vector3(0.7, 0.78, 0.86),
      godRaysEnabled: s.godRays || volumetric,
      godRaysStepCount: 24,
      godRaysDensity: volumetric ? kVolumetricGodRaysDensity : 0.18,
      godRaysIntensity: volumetric ? kVolumetricGodRaysIntensity : 1.0,
      godRaysMaxDistance: volumetric ? kVolumetricGodRaysMaxDistance : 200.0,
      autoExposureEnabled: s.autoExposure,
      autoExposureMinEv: -kAutoExposureRangeEv,
      autoExposureMaxEv: kAutoExposureRangeEv,
      autoExposureSpeedUp: 3.0,
      autoExposureSpeedDown: 1.0,
      globalIlluminationEnabled: s.dynamicGi,
      globalIlluminationVolumeMode: IrradianceVolumeMode.component,
      globalIlluminationVisibility: kGiVisibility,
      globalIlluminationVisibilityBias: kGiVisibilityBias,
      screenSpaceReflectionsEnabled: s.ssr,
    );
}
