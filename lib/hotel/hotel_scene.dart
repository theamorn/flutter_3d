import 'package:flutter_scene/scene.dart';
import 'feature_catalog.dart';
import 'feature_registry.dart';
import 'hotel_context.dart';

class HotelScene {
  HotelScene() {
    ctx = HotelContext(scene);
    registry = FeatureRegistry(buildCatalog(), mountContext: ctx);
  }
  final Scene scene = Scene();
  late final HotelContext ctx;
  late final FeatureRegistry registry;

  Future<void> start() async {
    // Geometry and materials touch the shader bundle, so features may only
    // build nodes once the engine's static resources are up.
    await Scene.initializeStaticResources();
    ctx.applyLook();
    await registry.mountDefaults();
  }

  void tick(double dt) => registry.tick(dt);
}
