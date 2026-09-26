import 'dart:math' as math;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import '../math/floor_plan.dart';

/// Planar reflections for the bathroom mirrors and the sea (Task 23).
///
/// A [PlanarReflectorComponent] renders the scene once more per frame from
/// the camera reflected across the surface, but only materials that declare
/// the `planar_reflection` engine input sample that capture, and
/// `PhysicallyBasedMaterial` doesn't. So each surface also swaps its material
/// for its own instance of [kMirrorFmat] (one per reflector: a material
/// shared between reflectors shows one of their captures at random).

/// The capture-sampling material, compiled by the build hook.
const String kMirrorFmat = 'assets/materials/mirror.fmat';

/// The render layer the sea sits on, alone, so its own capture can skip it.
const int kSeaLayer = 1 << 2;

/// The sea capture's layer mask: everything but the sea itself.
const int kSeaCaptureMask = 0xFFFFFFFF & ~(1 << 2);

/// The reflector for one bathroom mirror. The `mirror` quad faces local +X;
/// room B's copy sits under a scale.x = -1 parent, and the engine takes the
/// normal through the inverse transpose, so it faces -X there with no help.
PlanarReflectorComponent mirrorReflector() =>
    PlanarReflectorComponent(resolutionScale: 0.5, localNormal: Vector3(1, 0, 0));

/// The reflector for the sea plane (local +Y).
PlanarReflectorComponent seaReflector() => PlanarReflectorComponent(
    resolutionScale: 0.5, localNormal: Vector3(0, 1, 0), layerMask: kSeaCaptureMask);

/// The ocean's `sea` node: a direct child of the scene root, not part of
/// either room, so `ctx.nodesNamed` can't see it.
Node? findSea(Node root) {
  for (final n in root.children) {
    if (n.name == 'sea') return n;
  }
  return null;
}

/// A reflector on one surface node, holding what it replaced so [detach]
/// can put it all back.
class PlanarBinding {
  /// Adds [reflector] to [node], draws every primitive of its mesh with
  /// [material], and, if [layers] is given, moves the node onto them.
  PlanarBinding.attach(this.node, this.reflector, {required Material material, int? layers})
      : _mesh = node.mesh,
        _layers = node.layers {
    final mesh = _mesh;
    if (mesh != null) {
      // A new Mesh over the same geometry: the MeshComponent keeps its render
      // items and only swaps their materials. The original Mesh (and its
      // materials) stays untouched for detach.
      node.mesh = Mesh.primitives(primitives: [
        for (final p in mesh.primitives)
          MeshPrimitive(p.geometry, material)
            ..visible = p.visible
            ..castsShadow = p.castsShadow,
      ]);
    }
    if (layers != null) node.layers = layers;
    node.addComponent(reflector);
  }

  final Node node;
  final PlanarReflectorComponent reflector;
  final Mesh? _mesh;
  final int _layers;

  /// Removes the reflector and restores the mesh and layers. Safe to call
  /// twice, and on a node that has already left the scene.
  void detach() {
    // Reflector first: its onUnmount hands a null capture to the materials
    // still on the mesh, so the capture material lets go of the texture.
    if (reflector.isAttached) node.removeComponent(reflector);
    final mesh = _mesh;
    if (mesh != null && !identical(node.mesh, mesh)) node.mesh = mesh;
    node.layers = _layers;
  }
}

/// Points [binding] at [target]: returns it unchanged if it's already on
/// [target], otherwise detaches it and binds [target] with [attach] (or
/// nothing, when [target] is null).
PlanarBinding? followSurface(
    PlanarBinding? binding, Node? target, PlanarBinding Function(Node) attach) {
  if (identical(binding?.node, target)) return binding;
  binding?.detach();
  return target == null ? null : attach(target);
}

/// Configures [material] ([kMirrorFmat]) to look like [original] wherever no
/// capture is bound (inside another reflector's capture, or before the
/// first one), and sets how much of the capture it shows.
void _styleMirror(PreprocessedMaterial material, Material? original,
    {required double reflectivity, required double fresnelMix}) {
  final p = material.parameters
    ..setFloat('reflectivity', reflectivity)
    ..setFloat('fresnel_mix', fresnelMix);
  if (original is PhysicallyBasedMaterial) {
    p
      ..setVec4('base_color', original.baseColorFactor)
      ..setFloat('metallic_factor', original.metallicFactor)
      ..setFloat('roughness_factor', original.roughnessFactor);
  }
}

Material? _firstMaterial(Node node) {
  final primitives = node.mesh?.primitives;
  return primitives == null || primitives.isEmpty ? null : primitives.first.material;
}

class MirrorFeature extends HotelFeature {
  @override
  String get id => 'mirror';
  @override
  String get label => 'Bathroom mirror (planar reflection)';
  @override
  CostTier get tier => CostTier.expensive;
  @override
  bool get defaultOn => false;

  /// One capture material per mirror, loaded once and reused across toggles.
  final List<PreprocessedMaterial> _materials = [];
  final List<PlanarBinding> _bindings = [];

  @override
  Future<void> mount(HotelContext ctx) async {
    // One mirror per room, even if the rooms haven't mounted yet.
    final wanted = math.max(ctx.nodesNamed('mirror').length, RoomId.values.length);
    while (_materials.length < wanted) {
      _materials.add(await loadFmatMaterial(kMirrorFmat));
    }
    _bindAll(ctx);
  }

  void _bindAll(HotelContext ctx) {
    final mirrors = ctx.nodesNamed('mirror');
    for (var i = 0; i < mirrors.length && i < _materials.length; i++) {
      final node = mirrors[i];
      final material = _materials[i];
      _styleMirror(material, _firstMaterial(node), reflectivity: 1, fresnelMix: 0);
      _bindings.add(PlanarBinding.attach(node, mirrorReflector(), material: material));
    }
  }

  @override
  void tick(HotelContext ctx, double dt) {
    // Rooms mount first, but a toggle made while they're still loading can
    // run this feature's mount before them.
    if (_bindings.isEmpty) _bindAll(ctx);
  }

  @override
  void unmount(HotelContext ctx) {
    for (final b in _bindings) {
      b.detach();
    }
    _bindings.clear();
  }
}

class SeaReflectionFeature extends HotelFeature {
  @override
  String get id => 'sea_reflection';
  @override
  String get label => 'Sea planar reflection';
  @override
  CostTier get tier => CostTier.expensive;
  @override
  bool get defaultOn => false;

  PreprocessedMaterial? _material;
  PlanarBinding? _binding;

  @override
  Future<void> mount(HotelContext ctx) async {
    _material ??= await loadFmatMaterial(kMirrorFmat);
    _follow(ctx);
  }

  /// The ocean feature can unmount and remount on its own, which replaces
  /// the sea node, so re-find it every frame and move the binding with it.
  @override
  void tick(HotelContext ctx, double dt) => _follow(ctx);

  void _follow(HotelContext ctx) {
    final material = _material;
    if (material == null) return;
    _binding = followSurface(_binding, findSea(ctx.scene.root), (sea) {
      // Water: 2% head-on, rising to 100% at grazing angles.
      _styleMirror(material, _firstMaterial(sea), reflectivity: 0.02, fresnelMix: 1);
      return PlanarBinding.attach(sea, seaReflector(), material: material, layers: kSeaLayer);
    });
  }

  @override
  void unmount(HotelContext ctx) {
    _binding?.detach();
    _binding = null;
  }
}
