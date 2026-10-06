import 'dart:math' as math;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import '../math/floor_plan.dart';
import 'reflection_features.dart' show kSeaReflectedLayer;

/// The sea surface, 90 m below the room floor (30th floor).
const double kSeaLevel = -90;

/// A flat opaque sea: the sky reflects in it through the IBL, and a flat
/// plane is what Task 23's planar reflection needs. x is kept to ±380 m so
/// every corner stays inside the camera's 900 m far plane; fog hides the
/// far edge.
final Aabb3 kSea =
    Aabb3.minMax(Vector3(-380, kSeaLevel, 40), Vector3(380, kSeaLevel, 800));

/// Dry sand just above the water, sloping under it at the shoreline.
const double kSandTop = kSeaLevel + 0.2;
const double kShoreEndZ = 60, kShoreEndY = kSeaLevel - 0.6;

/// The tower below the balcony, so looking down shows a wall, not the void.
/// Its top stays under the room floor slab (−0.1) to avoid z-fighting.
final Aabb3 kFacade =
    Aabb3.minMax(Vector3(-30, kSeaLevel - 0.5, -20), Vector3(30, -0.15, FloorPlan.roomDepth));

/// The sea's far and side edges, raised to eye level: from the rooms the sea
/// then meets the sky at the horizon (the flat sea alone ends 6.6° below
/// it), and a setting sun or moon (the sky feature's discs, 898 m out)
/// sinks behind it. Fogged like the far sea.
final List<Aabb3> kSeaHorizon = [
  Aabb3.minMax(Vector3(kSea.min.x, kSeaLevel, kSea.max.z - 0.5),
      Vector3(kSea.max.x, FloorPlan.eyeHeight, kSea.max.z)),
  Aabb3.minMax(Vector3(kSea.min.x, kSeaLevel, kSea.min.z),
      Vector3(kSea.min.x + 0.5, FloorPlan.eyeHeight, kSea.max.z)),
  Aabb3.minMax(Vector3(kSea.max.x - 0.5, kSeaLevel, kSea.min.z),
      Vector3(kSea.max.x, FloorPlan.eyeHeight, kSea.max.z)),
];

PhysicallyBasedMaterial _pbr(double r, double g, double b, double roughness) =>
    PhysicallyBasedMaterial()
      ..baseColorFactor = Vector4(r, g, b, 1)
      ..metallicFactor = 0
      ..roughnessFactor = roughness;

Node _box(String name, Aabb3 box, Material material) => Node(
      name: name,
      localTransform: Matrix4.translation(box.center),
      mesh: Mesh(CuboidGeometry(box.max - box.min), material),
    );

class OceanFeature extends HotelFeature {
  @override
  String get id => 'ocean';
  @override
  String get label => 'Ocean + beach view';
  @override
  CostTier get tier => CostTier.cheap;

  final List<Node> _nodes = [];

  @override
  Future<void> mount(HotelContext ctx) async {
    final water = _pbr(0.02, 0.10, 0.12, 0.15);
    final sea = Node(
      name: 'sea', // Task 23 finds it among the scene root's children
      localTransform: Matrix4.translation(kSea.center),
      mesh: Mesh(
          PlaneGeometry(width: kSea.max.x - kSea.min.x, depth: kSea.max.z - kSea.min.z),
          water),
    );
    final horizon = [
      for (final (i, b) in kSeaHorizon.indexed)
        _box('sea_horizon_$i', b, water)..layers = kRenderLayerDefault | kSeaReflectedLayer,
    ];
    final sand = _pbr(0.76, 0.66, 0.48, 0.9);
    final beach = _box(
        'beach',
        Aabb3.minMax(Vector3(kSea.min.x, kSandTop - 1, -60),
            Vector3(kSea.max.x, kSandTop, kSea.min.z)),
        sand);
    // The shore: a plane tilted about X so the sand runs under the water.
    final drop = kSandTop - kShoreEndY, run = kShoreEndZ - kSea.min.z;
    final shore = Node(
      name: 'shore',
      localTransform: Matrix4.translation(
          Vector3(0, (kSandTop + kShoreEndY) / 2, (kSea.min.z + kShoreEndZ) / 2))
        ..rotateX(math.atan2(drop, run)),
      mesh: Mesh(
          PlaneGeometry(width: kSea.max.x - kSea.min.x, depth: math.sqrt(drop * drop + run * run)),
          sand),
    );
    final facade = _box('hotel_facade', kFacade, _pbr(0.72, 0.70, 0.66, 0.85));
    // Far below the sun's shadow range and never shadowing the rooms: no casters.
    for (final n in [sea, ...horizon, beach, shore, facade]) {
      n.shadowCastingMode = ShadowCastingMode.off;
      ctx.scene.add(n);
      _nodes.add(n);
    }
  }

  @override
  void unmount(HotelContext ctx) {
    for (final n in _nodes) {
      ctx.scene.remove(n);
    }
    _nodes.clear();
  }
}
