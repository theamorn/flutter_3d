import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

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
}

/// The ONLY place an EnvironmentSettings literal is built (engine rule 1).
EnvironmentSettings composeLook(LookState s) {
  final exposure = s.exposure * s.weatherExposureScale;
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
      fogEnabled: s.fog,
      fogDensity: s.fogDensity,
      fogSkyColorInfluence: 1.0,
      fogColor: Vector3(0.7, 0.78, 0.86),
      godRaysEnabled: s.godRays,
      godRaysStepCount: 24,
      godRaysDensity: 0.18,
      screenSpaceReflectionsEnabled: s.ssr,
    );
}
