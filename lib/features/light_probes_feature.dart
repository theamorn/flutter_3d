import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import '../math/light_probes.dart';
import '../math/occlusion.dart' show cellOf;
import '../math/schedulers.dart';
import 'occlusion_feature.dart' show roomContents, roomContentsRoot;

const int kProbeFaceResolution = 128;

EnvironmentMap? _environmentOf(Material material) => switch (material) {
  PhysicallyBasedMaterial m => m.environment,
  PreprocessedMaterial m => m.environment,
  _ => null,
};

void _setEnvironment(Material material, EnvironmentMap? environment) {
  if (material is PhysicallyBasedMaterial) material.environment = environment;
  if (material is PreprocessedMaterial) material.environment = environment;
}

/// Baked light probes: each bedroom and bathroom captures its own lighting
/// (a 6-face snapshot), and every surface in it takes that snapshot as its
/// ambient light and box-corrected reflections. Surfaces outdoors, the
/// balconies included, keep the sky.
///
/// The probes are bound per material, not through the engine's cross-fade.
/// That picks one probe by camera position for the whole frame and overrides
/// every material's own environment, so from the bedroom the sea would
/// reflect the bedroom.
///
/// It re-captures 0.5 s after the time, lights, weather or sky settle, one
/// probe per frame, holding occlusion culling off so each capture sees the
/// whole room.
class LightProbesFeature extends HotelFeature {
  @override
  String get id => 'light_probes';
  @override
  String get label => 'Baked light probes (room ambient + reflections)';
  @override
  CostTier get tier => CostTier.cheap;

  final List<Node> _nodes = [];
  final List<ReflectionProbeComponent> _probes = [];

  /// Each room's probes, in [roomProbeBoxes] order.
  final Map<Node, List<ReflectionProbeComponent>> _roomProbes = {};

  /// The capture each probe had when the materials were last bound.
  final Map<ReflectionProbeComponent, EnvironmentMap?> _bound = {};
  final Map<Material, EnvironmentMap?> _previous = {};
  final Map<Material, EnvironmentMap> _pinned = {};
  SettleTimer _settle = SettleTimer();
  CaptureQueue _queue = CaptureQueue(0);
  bool _holding = false;
  LightingSignature? _last;

  LightingSignature _signature(HotelContext ctx) => LightingSignature(
    timeOfDay: ctx.timeOfDay.value,
    weather: ctx.weather,
    sky: ctx.look.skyEnvironment,
    revision: ctx.lightingRevision.value,
  );

  @override
  Future<void> mount(HotelContext ctx) async {
    for (final room in ctx.rooms.values) {
      final probes = <ReflectionProbeComponent>[];
      for (final box in roomProbeBoxes()) {
        final probe = ReflectionProbeComponent(
          extents: box.halfExtents.clone(),
          blendDistance: 0.3,
          priority: box.priority,
          weight: 0, // out of the frame-wide cross-fade: bound per material
          faceResolution: kProbeFaceResolution,
          captureOnActivate: false,
        );
        final node = Node(
          name: 'light_probe',
          localTransform: Matrix4.translation(box.center),
        )..addComponent(probe);
        roomContentsRoot(room).add(node);
        _nodes.add(node);
        probes.add(probe);
      }
      _roomProbes[room] = probes;
      _probes.addAll(probes);
    }
    // The first capture is requested on the first tick under a hold.
    _queue = CaptureQueue(_probes.length)..start();
    _last = _signature(ctx);
  }

  @override
  void tick(HotelContext ctx, double dt) {
    final now = _signature(ctx);
    final last = _last;
    if (last == null || now.differsFrom(last)) {
      _last = now;
      _settle.markDirty();
    }
    if (_settle.tick(dt)) _queue.start();

    final step = _queue.step();
    _setHold(ctx, step.hold);
    final capture = step.capture;
    if (capture != null) _probes[capture].requestCapture();
    _bindCaptures();
  }

  void _setHold(HotelContext ctx, bool hold) {
    if (hold == _holding) return;
    ctx.occlusionHolds += hold ? 1 : -1;
    _holding = hold;
  }

  /// Once a capture lands (a frame after its request), binds every room
  /// surface to its own cell's probe.
  void _bindCaptures() {
    var landed = false;
    for (final probe in _probes) {
      if (!identical(probe.environment, _bound[probe])) {
        _bound[probe] = probe.environment;
        landed = true;
      }
    }
    if (!landed) return;
    for (final MapEntry(key: room, value: probes) in _roomProbes.entries) {
      for (final node in roomContents(room)) {
        _bindSubtree(node, probes);
      }
    }
  }

  /// Per primitive, so the bathroom's tiles and floor take the bathroom's
  /// probe although they share the walls and floor nodes with the bedroom.
  void _bindSubtree(Node node, List<ReflectionProbeComponent> probes) {
    final transform = node.globalTransform;
    for (final primitive in node.mesh?.primitives ?? const <MeshPrimitive>[]) {
      final bounds = primitive.geometry.localBounds;
      if (bounds == null) continue;
      _bind(primitive.material, probes, transform.transformed3(bounds.center));
    }
    final batch = node.getComponent<InstancedMeshComponent>();
    final bounds = node.combinedWorldBounds;
    if (batch != null && bounds != null) {
      _bind(batch.instancedMesh.material, probes, bounds.center);
    }
    for (final child in node.children) {
      _bindSubtree(child, probes);
    }
  }

  void _bind(
    Material material,
    List<ReflectionProbeComponent> probes,
    Vector3 at,
  ) {
    if (material is! PhysicallyBasedMaterial &&
        material is! PreprocessedMaterial) {
      return;
    }
    final box = probeBoxFor(cellOf(at));
    final environment = box == null ? null : probes[box].environment;
    if (environment == null) return; // outdoors, or not captured yet
    _previous.putIfAbsent(material, () => _environmentOf(material));
    _setEnvironment(material, environment);
    _pinned[material] = environment;
  }

  @override
  void unmount(HotelContext ctx) {
    _queue.cancel();
    _setHold(ctx, false);
    for (final node in _nodes) {
      node.parent?.remove(node);
    }
    for (final MapEntry(key: material, value: pinned) in _pinned.entries) {
      // Leave a material alone if something else has rebound it since.
      if (identical(_environmentOf(material), pinned)) {
        _setEnvironment(material, _previous[material]);
      }
    }
    _nodes.clear();
    _probes.clear();
    _roomProbes.clear();
    _bound.clear();
    _previous.clear();
    _pinned.clear();
    _last = null;
    _settle = SettleTimer();
  }
}
