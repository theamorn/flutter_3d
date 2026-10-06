import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import 'ocean_feature.dart' show kSandTop, kFacade;

/// Talk toggle: when true, build the same 700 props as individual scene
/// nodes/draw items instead of 2 instanced meshes. Compare HUD mesh count
/// and UI ms between the two builds (`--dart-define=NAIVE_PROPS=true`).
const bool kNaiveProps = bool.fromEnvironment('NAIVE_PROPS');

enum PropKind { palm, umbrella }

/// One scattered prop: its kind, sand-plane position, yaw and uniform scale.
class PropPlacement {
  const PropPlacement(this.kind, this.x, this.z, this.rotationY, this.scale);
  final PropKind kind;
  final double x, z, rotationY, scale;
}

/// Jittered-grid scatter of [palmCount] palms then [umbrellaCount] umbrellas
/// over `x ∈ [xMin, xMax], z ∈ [zMin, zMax]`, seeded by [rng].
///
/// Pure and GPU-free: positions only, no Vector/Matrix types, so results are
/// exactly reproducible (no float32 rounding) and unit-testable. Each prop
/// type is laid on its own grid sized so `cols * rows >= count`, one prop
/// per cell, jittered within the cell and clamped back into bounds. When
/// [blocked] flags a jittered point (e.g. inside a building footprint), a
/// few more jitters are tried before falling back to the last sample.
List<PropPlacement> scatterBeachProps(
  math.Random rng, {
  int palmCount = 400,
  int umbrellaCount = 300,
  double xMin = -120,
  double xMax = 120,
  double zMin = 5,
  double zMax = 35,
  bool Function(double x, double z)? blocked,
}) {
  final out = <PropPlacement>[];
  final width = xMax - xMin, depth = zMax - zMin;

  void place(PropKind kind, int count) {
    if (count <= 0) return;
    final area = width * depth;
    final cell = math.sqrt(area / count);
    final cols = math.max(1, (width / cell).round());
    final rows = math.max(1, (count / cols).ceil());
    final cellW = width / cols;
    final cellD = depth / rows;
    var placed = 0;
    for (var r = 0; r < rows && placed < count; r++) {
      for (var c = 0; c < cols && placed < count; c++) {
        final cx = xMin + (c + 0.5) * cellW;
        final cz = zMin + (r + 0.5) * cellD;
        var x = cx, z = cz;
        for (var attempt = 0; attempt < 6; attempt++) {
          final jx = (rng.nextDouble() - 0.5) * cellW * 0.8;
          final jz = (rng.nextDouble() - 0.5) * cellD * 0.8;
          x = (cx + jx).clamp(xMin, xMax);
          z = (cz + jz).clamp(zMin, zMax);
          if (blocked == null || !blocked(x, z)) break;
        }
        final rot = rng.nextDouble() * math.pi * 2;
        final scale = 0.85 + rng.nextDouble() * 0.3;
        out.add(PropPlacement(kind, x, z, rot, scale));
        placed++;
      }
    }
  }

  place(PropKind.palm, palmCount);
  place(PropKind.umbrella, umbrellaCount);
  return out;
}

/// True inside the hotel tower's footprint (see `ocean_feature.dart`'s
/// `kFacade`), so props don't scatter into the building.
bool _insideTower(double x, double z) =>
    x >= kFacade.min.x && x <= kFacade.max.x && z >= kFacade.min.z && z <= kFacade.max.z;

Float32List _uniformColor(int vertexCount, double r, double g, double b, double a) {
  final out = Float32List(vertexCount * 4);
  for (var i = 0; i < vertexCount; i++) {
    out[i * 4] = r;
    out[i * 4 + 1] = g;
    out[i * 4 + 2] = b;
    out[i * 4 + 3] = a;
  }
  return out;
}

/// [part]'s CPU mesh data, tinted uniformly with [color] and moved by
/// [transform]. Used to merge a prop's parts (trunk + leaves, pole +
/// canopy) into the single [MeshData] an `InstancedMesh` needs (one
/// geometry, one material per instanced mesh — see
/// `instanced_mesh_component.dart`). Vertex colour carries the per-part
/// tint through the merge; a shared `PhysicallyBasedMaterial` with
/// `vertexColorWeight = 1` reads it back per-fragment
/// (`flutter_scene_standard.frag`), which is the cheapest way to keep 2
/// distinct part colours inside 1 draw source.
MeshData _tintedPart(Geometry part, Vector4 color, Matrix4 transform) {
  final data = part.extractMeshData();
  final tinted = MeshData(
    positions: data.positions,
    vertexCount: data.vertexCount,
    normals: data.normals,
    texCoords: data.texCoords,
    texCoords1: data.texCoords1,
    colors: _uniformColor(data.vertexCount, color.r, color.g, color.b, color.a),
    tangents: data.tangents,
    indices: data.indices,
    primitiveType: data.primitiveType,
    customAttributes: data.customAttributes,
  );
  return tinted.transformed(transform);
}

/// A palm: cylinder trunk + a cone of leaves, merged into one geometry.
MeshGeometry _palmGeometry() {
  const trunkHeight = 3.2;
  final trunk = CylinderGeometry(
      bottomRadius: 0.18, topRadius: 0.12, height: trunkHeight, radialSegments: 6, bottomCap: true, topCap: false);
  final leaves = CylinderGeometry(
      bottomRadius: 1.3, topRadius: 0.05, height: 1.6, radialSegments: 7, bottomCap: true, topCap: false);
  final trunkData = _tintedPart(
      trunk, Vector4(0.35, 0.22, 0.12, 1), Matrix4.translation(Vector3(0, trunkHeight / 2, 0)));
  final leavesData = _tintedPart(
      leaves, Vector4(0.15, 0.45, 0.18, 1), Matrix4.translation(Vector3(0, trunkHeight - 0.2, 0)));
  return MeshGeometry.fromMeshData(MeshData.merge([trunkData, leavesData]));
}

/// An umbrella: pole + a cone canopy (apex up), merged into one geometry.
MeshGeometry _umbrellaGeometry() {
  const poleHeight = 2.2;
  final pole = CylinderGeometry(
      bottomRadius: 0.05, topRadius: 0.05, height: poleHeight, radialSegments: 6, bottomCap: true, topCap: false);
  final canopy = CylinderGeometry(
      bottomRadius: 1.0, topRadius: 0.0, height: 0.6, radialSegments: 8, bottomCap: true, topCap: false);
  final poleData =
      _tintedPart(pole, Vector4(0.25, 0.25, 0.27, 1), Matrix4.translation(Vector3(0, poleHeight / 2, 0)));
  final canopyData =
      _tintedPart(canopy, Vector4(0.78, 0.28, 0.22, 1), Matrix4.translation(Vector3(0, poleHeight, 0)));
  return MeshGeometry.fromMeshData(MeshData.merge([poleData, canopyData]));
}

class InstancingFeature extends HotelFeature {
  @override
  String get id => 'instancing';
  @override
  String get label => 'Instanced beach props';
  @override
  CostTier get tier => CostTier.cheap;

  final List<Node> _nodes = [];

  @override
  Future<void> mount(HotelContext ctx) async {
    final placements = scatterBeachProps(math.Random(7), blocked: _insideTower);

    final palmGeometry = _palmGeometry();
    final palmMaterial = PhysicallyBasedMaterial()
      ..vertexColorWeight = 1.0
      ..metallicFactor = 0
      ..roughnessFactor = 0.85;
    final umbrellaGeometry = _umbrellaGeometry();
    final umbrellaMaterial = PhysicallyBasedMaterial()
      ..vertexColorWeight = 1.0
      ..metallicFactor = 0
      ..roughnessFactor = 0.6;

    Matrix4 transformFor(PropPlacement p) => Matrix4.compose(
          Vector3(p.x, kSandTop, p.z),
          Quaternion.axisAngle(Vector3(0, 1, 0), p.rotationY),
          Vector3.all(p.scale),
        );

    if (kNaiveProps) {
      // Talk comparison: 700 individual nodes/draw items sharing the same
      // geometry+material objects (memory is shared; draw calls are not).
      for (final p in placements) {
        final geometry = p.kind == PropKind.palm ? palmGeometry : umbrellaGeometry;
        final material = p.kind == PropKind.palm ? palmMaterial : umbrellaMaterial;
        final node = Node(
          name: 'beach_prop_${p.kind.name}',
          localTransform: transformFor(p),
          mesh: Mesh(geometry, material),
        )..shadowCastingMode = ShadowCastingMode.off;
        ctx.scene.add(node);
        _nodes.add(node);
      }
    } else {
      final palmMesh = InstancedMesh(geometry: palmGeometry, material: palmMaterial);
      final umbrellaMesh = InstancedMesh(geometry: umbrellaGeometry, material: umbrellaMaterial);
      for (final p in placements) {
        (p.kind == PropKind.palm ? palmMesh : umbrellaMesh).addInstance(transformFor(p));
      }
      final palmNode = Node(name: 'beach_palms')
        ..shadowCastingMode = ShadowCastingMode.off
        ..addComponent(InstancedMeshComponent(palmMesh));
      final umbrellaNode = Node(name: 'beach_umbrellas')
        ..shadowCastingMode = ShadowCastingMode.off
        ..addComponent(InstancedMeshComponent(umbrellaMesh));
      for (final n in [palmNode, umbrellaNode]) {
        ctx.scene.add(n);
        _nodes.add(n);
      }
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
