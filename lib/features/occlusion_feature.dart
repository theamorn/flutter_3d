import 'dart:ui';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import '../math/occlusion.dart';
import '../math/portal.dart';
import 'door_feature.dart';
import 'reflection_features.dart';

/// Root-level outdoor nodes worth hiding when no window is in view: the big
/// ground-level surfaces and the 700 beach props (none cast shadows). The
/// horizon walls, sun, moon and lightning stay: they're tiny, and they're
/// what the sea reflects.
const Set<String> kOccludableOutdoors = {
  'sea', 'beach', 'shore', 'hotel_facade', 'beach_palms', 'beach_umbrellas',
  'rain_particles', 'rain_splash_particles',
};

/// The node a room's furniture and fixtures hang under: the root itself for
/// room A, the `room` child under room B's x-mirror. Features that add
/// nodes to a room add them here, so room B mirrors them for free and
/// occlusion culling still finds the room's contents.
Node roomContentsRoot(Node root) {
  var n = root;
  while (n.mesh == null && n.children.length == 1) {
    n = n.children.single;
  }
  return n;
}

/// The room's furniture and fixtures.
List<Node> roomContents(Node root) => roomContentsRoot(root).children;

/// Camera occlusion culling (see `math/occlusion.dart`): each frame, every
/// camera that renders the scene gets the cells it can see through the
/// doorways and windows, and whatever lies in none of them is not drawn.
///
/// * Furniture and fixtures hide per primitive (`MeshPrimitive.visible`,
///   colour passes only), so they still cast shadows, their lamps still
///   light the room, and taps still find them.
/// * A mirror hides as a node, which also stops its reflection capture: a
///   whole extra scene render the camera would never see.
/// * Outdoor ground and props hide as nodes when no window shows them.
/// * Each visible mirror is a camera too: what its reflection shows through
///   the glass stays drawn, even behind the viewer.
/// * The sea's reflection capture draws only [kSeaReflectedLayer]: its
///   reflected rays all leave the sea heading out to the horizon, so the
///   rooms, beach and props can never appear in it.
class OcclusionFeature extends HotelFeature {
  @override
  String get id => 'occlusion';
  @override
  String get label => 'Occlusion culling (camera portals)';
  @override
  CostTier get tier => CostTier.free;

  /// Primitives and nodes this feature switched off, to switch back on.
  final Set<MeshPrimitive> _hiddenPrimitives = {};
  final Set<Node> _hiddenNodes = {};

  @override
  Future<void> mount(HotelContext ctx) async => tick(ctx, 0);

  @override
  void tick(HotelContext ctx, double dt) {
    if (ctx.occlusionHolds > 0) {
      // A probe capture renders this frame: it must see the whole scene.
      _apply(const {}, const {}, const {});
      return;
    }
    final view = PlatformDispatcher.instance.implicitView;
    if (view == null || view.physicalSize.isEmpty) return;
    final camera = ctx.camera;
    final eye = camera.position;
    final portals =
        hotelPortals(connectingDoorOpen: doorwayExposed(DoorFeature.angleFor(ctx)));
    final main =
        visibleCells(eye, cellOf(eye), frustumPlanes(camera.getFrustum(view.physicalSize)), portals);

    // The rooms' contents, placed once per frame (curtains and doors move).
    final contents = <(Node, Aabb3, Cell)>[];
    for (final room in ctx.rooms.values) {
      if (!room.visible) continue; // portal culling hid the whole room
      for (final node in roomContents(room)) {
        final box = node.combinedWorldBounds;
        final cell = box == null ? null : cellContaining(box);
        if (cell != null) contents.add((node, box!, cell));
      }
    }

    // What each visible mirror reflects is on screen too: the engine's
    // planar reflectors and the custom mirror captures alike.
    final seenByAny = {for (final e in main.entries) e.key: [...e.value]};
    for (final (node, box, cell) in contents) {
      final plane = _mirrorPlane(ctx, node);
      if (plane == null || !seen(main, cell, box)) continue;
      final reflected = mirrorCells(eye, plane, box, portals);
      if (reflected != null) addCells(seenByAny, reflected);
    }

    final show = <MeshPrimitive>{}, hide = <MeshPrimitive>{};
    final hideNodes = <Node>{};
    for (final (node, box, cell) in contents) {
      if (node.getComponent<PlanarReflectorComponent>() != null ||
          ctx.reflectionCaptures[node] != null) {
        // The mirror feature copies the glass's visibility into the mesh it
        // swaps in, so the primitives stay on and the node carries it.
        if (!seen(main, cell, box)) hideNodes.add(node);
        _primitives(node, show);
      } else {
        _primitives(node, seen(seenByAny, cell, box) ? show : hide);
      }
    }
    for (final node in ctx.scene.root.children) {
      if (!kOccludableOutdoors.contains(node.name)) continue;
      final box = node.combinedWorldBounds;
      final shown = box == null ? main.containsKey(Cell.outdoors) : seen(main, Cell.outdoors, box);
      if (!shown) hideNodes.add(node);
    }
    _apply(show, hide, hideNodes);

    final sea = findSea(ctx.scene.root)?.getComponent<PlanarReflectorComponent>();
    if (sea != null) sea.layerMask = kSeaReflectedLayer;
  }

  /// The plane [node] mirrors across, if it is a live mirror of either kind.
  static Plane? _mirrorPlane(HotelContext ctx, Node node) {
    final reflector = node.getComponent<PlanarReflectorComponent>();
    if (reflector != null) return reflector.enabled ? reflector.worldPlane() : null;
    return ctx.reflectionCaptures[node];
  }

  static void _primitives(Node node, Set<MeshPrimitive> into) {
    final mesh = node.mesh;
    if (mesh != null) into.addAll(mesh.primitives);
    for (final c in node.children) {
      _primitives(c, into);
    }
  }

  /// Owns the contents' primitive visibility while mounted (nothing else
  /// hides a room primitive): [show] on, [hide] off, and anything hidden
  /// earlier that's no longer in either (a mesh a feature swapped out, and
  /// may swap back) on again.
  void _apply(Set<MeshPrimitive> show, Set<MeshPrimitive> hide, Set<Node> hideNodes) {
    for (final p in _hiddenPrimitives.difference(hide)) {
      p.visible = true;
    }
    for (final p in show) {
      p.visible = true;
    }
    for (final p in hide) {
      p.visible = false;
    }
    _hiddenPrimitives
      ..clear()
      ..addAll(hide);
    for (final n in _hiddenNodes.difference(hideNodes)) {
      n.visible = true;
    }
    _hiddenNodes.retainAll(hideNodes);
    for (final n in hideNodes) {
      if (n.visible) {
        n.visible = false;
        _hiddenNodes.add(n);
      }
    }
  }

  @override
  void unmount(HotelContext ctx) {
    _apply(const {}, const {}, const {});
    final sea = findSea(ctx.scene.root)?.getComponent<PlanarReflectorComponent>();
    if (sea != null) sea.layerMask = kSeaCaptureMask;
  }
}
