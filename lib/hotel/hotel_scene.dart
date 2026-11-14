import 'dart:async';
import 'package:flutter_scene/scene.dart';
import 'debug_tour.dart';
import 'feature_catalog.dart';
import 'feature_registry.dart';
import 'hotel_context.dart';
import 'perf_probe.dart';

class HotelScene {
  HotelScene() {
    ctx = HotelContext(scene);
    registry = FeatureRegistry(buildCatalog(), mountContext: ctx);
  }
  final Scene scene = Scene();
  late final HotelContext ctx;
  late final FeatureRegistry registry;
  DebugTour? _tour;

  Future<void> start() async {
    // Geometry and materials touch the shader bundle, so features may only
    // build nodes once the engine's static resources are up.
    // Load physical-material extension shaders and SMAA tables before the
    // tour instead of waiting for their first use.
    await Scene.preload(physicalMaterials: true, smaa: true);
    ctx.applyLook();
    await registry.mountDefaults();
    _tour = await maybeStartDebugTour(this);
    unawaited(maybeRunPerfProbe(this));
  }

  void tick(double dt) => registry.tick(dt);

  /// Releases cross-frame render targets, shadow caches, punctual light
  /// textures, planar reflection captures, and TAA/SSGI history immediately
  /// (`Scene.dispose()` in 0.24.2+).
  void dispose() {
    _tour?.dispose();
    _tour = null;
    scene.dispose();
  }
}
