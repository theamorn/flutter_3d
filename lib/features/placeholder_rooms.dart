import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';
import '../math/colliders.dart';
import '../math/floor_plan.dart';
import '../render/shadow_channels.dart' show kFixtureSelfShadowChannel;
import 'bedding_mesh.dart';
import 'room_textures.dart';

/// Room A, authored as plain data (`roomASpec`, GPU-free and unit-tested)
/// and turned into scene nodes by [buildRoomA]. Every mesh is built from
/// boxes, quads, cylinders and cloth meshes in room A space (x ∈ [−8, 0]). These
/// code-built rooms are final: no `.glb` import replaces them (Task 28 was
/// dropped).

/// The window opening in the window wall (z = 6). Its middle 1.2 m is the
/// open balcony doorway; glass fills the rest. Two 1.4 m curtains close it.
const double windowX0 = -4.4, windowX1 = -1.6;

/// Top of the window opening and of the doors in the walls.
const double _windowTop = 2.4, _doorTop = 2.1;

/// A photo texture in assets/textures (credits: assets/TEXTURE_CREDITS.md):
/// `<id>.jpg`, plus the normal map `<id>_n.jpg` when [hasNormal]. It
/// repeats every [width] × [height] metres, its real-world size.
class TextureRef {
  const TextureRef(this.id, this.width, this.height, {this.hasNormal = true});
  final String id;
  final double width, height;
  final bool hasNormal;
  String get colorAsset => 'assets/textures/$id.jpg';
  String get normalAsset => 'assets/textures/${id}_n.jpg';
}

/// How a surface answers light, on top of its colour and roughness. The
/// classic models map onto the engine's PBR: Lambert is a diffuse-only
/// dielectric, Phong's sharp highlight is a low-roughness one; fabrics,
/// lacquer and brushed metal get the matching glTF material layers.
enum Shading {
  /// The engine's default dielectric or metal response.
  standard,

  /// Lambert: diffuse only, no specular reflection (paint, linen, rugs).
  matte,

  /// Phong-like: diffuse plus a sharp dielectric highlight (glazed ceramic).
  glossy,

  /// The soft glow of a fabric's pile at grazing angles (velvet, satin).
  sheen,

  /// A glossy lacquer layer over the base (lacquered wood, polished stone).
  clearcoat,

  /// Highlights stretched along the brushing (brushed brass).
  brushed,
}

/// Which decorative bedding a finish dresses, for the cloth lighting
/// feature: it relights only these primitives and leaves the sleeping linen
/// and every other surface alone.
enum BeddingMaterialRole { none, jacquardPillow, woolThrow }

/// Surface look of a part: linear RGB base colour plus PBR factors. With a
/// [texture], the colour tints it (the fabrics ship grey, so the tint is
/// their colour) and the part's UVs run in metres. [layer] (0..1) scales the
/// [shading] layer: the clearcoat's weight, the sheen's or the brushing's
/// strength.
class Finish {
  const Finish(this.r, this.g, this.b,
      {this.roughness = 0.8,
      this.metallic = 0,
      this.alpha = 1,
      this.texture,
      this.shading = Shading.standard,
      this.layer = 1,
      this.bedding = BeddingMaterialRole.none});
  final double r, g, b, roughness, metallic, alpha, layer;
  final TextureRef? texture;
  final Shading shading;
  final BeddingMaterialRole bedding;
}

/// The engine material settings a [Finish] asks for. Pure data, so the
/// shading can be tested without a GPU.
class ShadingLayers {
  const ShadingLayers(
      {required this.roughness,
      this.specular = 1,
      this.clearcoat = 0,
      this.clearcoatRoughness = 0,
      this.sheenColor,
      this.sheenRoughness = 0,
      this.anisotropy = 0});

  /// PhysicallyBasedMaterial.roughnessFactor.
  final double roughness;

  /// Dielectric specular weight: 0 is Lambert (no reflection at all).
  final double specular;
  final double clearcoat, clearcoatRoughness;

  /// Null: no sheen layer.
  final Vector3? sheenColor;
  final double sheenRoughness;
  final double anisotropy;

  /// Whether the engine draws it with its heavier physical shader variant
  /// (clearcoat, sheen and anisotropy do; a scalar specular doesn't).
  bool get usesPhysicalShader => clearcoat > 0 || sheenColor != null || anisotropy != 0;
}

ShadingLayers shadingLayers(Finish f) => switch (f.shading) {
      Shading.standard => ShadingLayers(roughness: f.roughness),
      Shading.matte => ShadingLayers(roughness: f.roughness, specular: 0),
      Shading.glossy => ShadingLayers(roughness: math.min(f.roughness, 0.3)),
      // The pile catches light in a paler shade of its own colour.
      Shading.sheen => ShadingLayers(
          roughness: f.roughness,
          sheenColor: Vector3(f.r + (1 - f.r) * 0.3, f.g + (1 - f.g) * 0.3, f.b + (1 - f.b) * 0.3)
            ..scale(f.layer),
          sheenRoughness: 0.4),
      Shading.clearcoat =>
        ShadingLayers(roughness: f.roughness, clearcoat: f.layer, clearcoatRoughness: 0.05),
      Shading.brushed => ShadingLayers(roughness: f.roughness, anisotropy: 0.7 * f.layer),
    };

// Real-world sizes from Poly Haven, in metres.
const _parquet = TextureRef('herringbone_parquet', 3.4, 3.4);
const _stucco = TextureRef('white_stucco', 2.0, 2.0);
const _bathTiles = TextureRef('interior_tiles', 1.9, 1.9);
const _pavers = TextureRef('marble_01', 1.5, 1.5);
const _linenWeave = TextureRef('rough_linen', 0.27, 0.27);
const _caban = TextureRef('caban', 0.27, 0.27);
const _satin = TextureRef('crepe_satin', 0.26, 0.27);
const _hessian = TextureRef('hessian_230', 0.27, 0.27);
const _americanWalnut = TextureRef('american_walnut_veneer', 1, 1, hasNormal: false);
const _teak = TextureRef('teak_veneer', 1, 1, hasNormal: false);
const _cherry = TextureRef('lacquered_cherry_wood', 1, 1, hasNormal: false);
const _blackOak = TextureRef('black_oak_veneer', 1, 1, hasNormal: false);
const _whiteOak = TextureRef('white_oak_veneer', 0.5, 0.5, hasNormal: false);
const _walnut = TextureRef('walnut_veneer', 1.8, 1.8, hasNormal: false);
const _blackWalnut = TextureRef('black_walnut_veneer_02', 1, 1, hasNormal: false);

const _paint = Finish(0.95, 0.88, 0.78, roughness: 0.9, texture: _stucco, shading: Shading.matte);

/// The reading lights' wall fixtures: high enough, and with an arm long
/// enough, that the beam passes over the headboard (1.35 m tall, standing
/// 0.6 m off the wall) onto the pillows. The shade stays clear of the bed.
const double kReadingLightHeight = 1.95, kReadingLightArm = 0.5;

const _ceilingPaint = Finish(0.90, 0.90, 0.88, roughness: 0.95, shading: Shading.matte);
const _parquetFloor = Finish(1, 1, 1, roughness: 0.35, texture: _parquet, shading: Shading.glossy);
const _bathFloor = Finish(1, 1, 1, roughness: 0.25, texture: _bathTiles, shading: Shading.glossy);
const _balconyTile = Finish(1, 1, 1, roughness: 0.6, texture: _pavers);
const _linen = Finish(1.0, 0.96, 0.9, roughness: 0.9, texture: _linenWeave, shading: Shading.matte);
const _sofaFabric =
    Finish(0.62, 0.53, 0.43, roughness: 0.9, texture: _caban, shading: Shading.sheen, layer: 0.6);
const _bedFrameWood = Finish(0.85, 0.58, 0.40,
    roughness: 0.5, texture: _americanWalnut, shading: Shading.clearcoat, layer: 0.5);
const _deskWood = Finish(0.85, 0.72, 0.60, roughness: 0.45, texture: _teak);
const _bedsideWood = Finish(1, 1, 1, roughness: 0.2, texture: _cherry, shading: Shading.clearcoat);
const _tvWood = Finish(0.45, 0.38, 0.33,
    roughness: 0.4, texture: _blackOak, shading: Shading.clearcoat, layer: 0.6);
const _velvet = TextureRef('velour_velvet', 0.28, 0.27);
const _jacquard = TextureRef('quatrefoil_jacquard_fabric', 0.28, 0.28);
const _woolWeave = TextureRef('poly_wool_herringbone', 0.27, 0.28);
const _leather = TextureRef('fabric_leather_02', 0.5, 0.5);
const _teddy = TextureRef('curly_teddy_natural', 0.34, 0.33);
const _jute = TextureRef('hessian_380', 0.27, 0.27);
const _whiteTiles = TextureRef('long_white_tiles', 1.27, 1.27);

const _headboardVelvet =
    Finish(0.05, 0.20, 0.22, roughness: 0.95, texture: _velvet, shading: Shading.sheen);
const _pillowJacquard = Finish(0.85, 0.70, 0.45,
    roughness: 0.7, texture: _jacquard, shading: Shading.sheen, layer: 0.7,
    bedding: BeddingMaterialRole.jacquardPillow);
const _throwWool = Finish(0.15, 0.15, 0.16,
    roughness: 0.9, texture: _woolWeave, shading: Shading.sheen, layer: 0.5,
    bedding: BeddingMaterialRole.woolThrow);
const _benchLeather =
    Finish(1, 1, 1, roughness: 0.5, texture: _leather, shading: Shading.clearcoat, layer: 0.3);
const _rugTeddy = Finish(1, 1, 1, roughness: 1, texture: _teddy, shading: Shading.matte);
const _rugJute = Finish(1, 1, 1, roughness: 1, texture: _jute, shading: Shading.matte);
const _bathTilesWall =
    Finish(1, 1, 1, roughness: 0.15, texture: _whiteTiles, shading: Shading.glossy);
const _blackStone = Finish(0.02, 0.02, 0.022, roughness: 0.08, shading: Shading.clearcoat);
const _leafGreen = Finish(0.10, 0.28, 0.08, roughness: 0.6);
const _bloomPink = Finish(0.95, 0.70, 0.75, roughness: 0.7, shading: Shading.matte);
const _bloomWhite = Finish(0.95, 0.95, 0.96, roughness: 0.6, shading: Shading.matte);
const _canvas = Finish(0.85, 0.80, 0.70, roughness: 0.9, shading: Shading.matte);
const _artTerracotta = Finish(0.60, 0.22, 0.10, roughness: 0.9, shading: Shading.matte);
const _artMustard = Finish(0.75, 0.50, 0.10, roughness: 0.9, shading: Shading.matte);
const _artTeal = Finish(0.05, 0.30, 0.32, roughness: 0.9, shading: Shading.matte);
const _artCharcoal = Finish(0.05, 0.05, 0.05, roughness: 0.9, shading: Shading.matte);
const _shelfWood = Finish(1.0, 0.92, 0.82, roughness: 0.55, texture: _whiteOak);
const _vanityWood = Finish(1, 1, 1, roughness: 0.45, texture: _walnut);
const _doorWood = Finish(0.55, 0.42, 0.33,
    roughness: 0.4, texture: _blackWalnut, shading: Shading.clearcoat, layer: 0.5);
const _brass = Finish(0.90, 0.70, 0.35, roughness: 0.3, metallic: 1, shading: Shading.brushed);
const _chrome = Finish(0.80, 0.80, 0.82, roughness: 0.2, metallic: 1);
const _blackPlastic = Finish(0.02, 0.02, 0.02, roughness: 0.4);
const _screen = Finish(0, 0, 0, roughness: 0.15);
const _mirror = Finish(0.95, 0.95, 0.95, roughness: 0.02, metallic: 1);
const _porcelain = Finish(0.95, 0.95, 0.95, roughness: 0.2, shading: Shading.glossy);
const _opalGlass = Finish(0.95, 0.95, 0.93, roughness: 0.3, shading: Shading.glossy);
const _shadeFabric =
    Finish(0.95, 0.88, 0.72, roughness: 0.9, texture: _hessian, shading: Shading.matte);
const _curtainFabric = Finish(0.80, 0.70, 0.55,
    roughness: 0.35, texture: _satin, shading: Shading.sheen, layer: 0.8);
const _windowGlass = Finish(0.85, 0.92, 0.95, roughness: 0.03, alpha: 0.05);
const _railingGlass = Finish(0.85, 0.95, 1.0, roughness: 0.02, alpha: 0.03);
const _showerGlass = Finish(0.85, 0.92, 0.95, roughness: 0.05, alpha: 0.2);
const _books = [
  Finish(0.55, 0.08, 0.06), Finish(0.08, 0.25, 0.55), Finish(0.10, 0.40, 0.15),
  Finish(0.75, 0.60, 0.10), Finish(0.35, 0.12, 0.40), Finish(0.85, 0.40, 0.10),
];

/// One solid piece of a node's mesh, in the node's local space.
sealed class Part {
  const Part(this.finish);
  final Finish finish;
  Aabb3 get bounds;
}

/// Smooth procedural fabric, kept in the same material batches as other
/// room parts. Bounds include every fold for picking and culling.
class ClothPart extends Part {
  ClothPart(this.data, super.finish) {
    final ps = data.positions;
    final min = Vector3(ps[0], ps[1], ps[2]), max = min.clone();
    for (var i = 3; i < ps.length; i += 3) {
      for (var axis = 0; axis < 3; axis++) {
        min[axis] = math.min(min[axis], ps[i + axis]);
        max[axis] = math.max(max[axis], ps[i + axis]);
      }
    }
    _bounds = Aabb3.minMax(min, max);
  }

  final MeshData data;
  late final Aabb3 _bounds;
  @override
  Aabb3 get bounds => Aabb3.copy(_bounds);
}

/// An axis-aligned box.
class BoxPart extends Part {
  BoxPart(this.min, this.max, super.finish);

  /// A box standing on the floor-plan footprint [b], from [y0] to [y1].
  BoxPart.footprint(Box2 b, double y0, double y1, Finish finish)
      : this(Vector3(b.minX, y0, b.minZ), Vector3(b.maxX, y1, b.maxZ), finish);

  final Vector3 min, max;
  @override
  Aabb3 get bounds => Aabb3.minMax(min, max);
}

/// A single-sided vertical rectangle facing [normal] (±X or ±Z). [width]
/// runs along the viewer's right, [height] along +Y; UV (0, 0) is the
/// viewer's top-left (the glTF convention) in both rooms: room B's copy is
/// built with u flipped (see [partsMeshData]).
class QuadPart extends Part {
  QuadPart(this.center, this.normal, this.width, this.height, super.finish)
      : assert(normal.y == 0 && (normal.length - 1).abs() < 1e-9);
  final Vector3 center, normal;
  final double width, height;

  /// Viewer's right when looking at the front face: n × up.
  Vector3 get right => normal.cross(Vector3(0, 1, 0));

  @override
  Aabb3 get bounds {
    final half = right.clone()..absolute();
    half.scale(width / 2);
    half.y = height / 2;
    return Aabb3.minMax(center - half, center + half);
  }
}

/// A capped Y-axis cylinder (a truncated cone when the radii differ)
/// standing on [base].
class CylinderPart extends Part {
  CylinderPart(this.base,
      {required this.bottomRadius,
      required this.topRadius,
      required this.height,
      required Finish finish})
      : super(finish);
  final Vector3 base;
  final double bottomRadius, topRadius, height;

  @override
  Aabb3 get bounds {
    final r = math.max(bottomRadius, topRadius);
    return Aabb3.minMax(
        base - Vector3(r, 0, r), base + Vector3(r, height, r));
  }
}

/// A node of the placeholder tree: translation + scale, parts, children.
class RoomNode {
  RoomNode(this.name,
      {Vector3? at,
      Vector3? scale,
      this.parts = const [],
      this.children = const [],
      this.castsShadows = true,
      this.lightChannelMask})
      : at = at ?? Vector3.zero(),
        scale = scale ?? Vector3.all(1);
  final String name;
  final Vector3 at, scale;
  final List<Part> parts;
  final List<RoomNode> children;
  final bool castsShadows;

  /// The node's `Node.lightChannelMask`, or null for the engine default.
  final int? lightChannelMask;

  Matrix4 get localTransform =>
      Matrix4.translation(at)..scaleByVector3(scale);
}

// ---------------------------------------------------------------- mesh data

class _Arrays {
  final positions = <double>[], normals = <double>[], uvs = <double>[];
  final indices = <int>[];
  int get vertexCount => positions.length ~/ 3;

  /// The texture of the part being emitted: UVs then run in metres divided
  /// by its size, so it tiles at real scale. Null: each face spans 0..1.
  TextureRef? tile;

  void vertex(Vector3 p, Vector3 n, double u, double v) {
    positions.addAll([p.x, p.y, p.z]);
    normals.addAll([n.x, n.y, n.z]);
    uvs.addAll([u, v]);
  }

  /// Corners top-left, top-right, bottom-right, bottom-left as a viewer in
  /// front of the face sees them. flutter_scene's view basis is right =
  /// up × forward, so that viewer's right is n × up, and (tl, tr, br) winds
  /// with e1 × e2 along n: the engine's front face.
  void quad(Vector3 tl, Vector3 tr, Vector3 br, Vector3 bl, Vector3 n) {
    final base = vertexCount;
    final t = tile;
    if (t == null) {
      vertex(tl, n, 0, 0);
      vertex(tr, n, 1, 0);
      vertex(br, n, 1, 1);
      vertex(bl, n, 0, 1);
    } else {
      // The face's own right and up, so u grows to the viewer's right and v
      // downward, as on an untextured face.
      final right = (tr - tl)..normalize(), up = (tl - bl)..normalize();
      for (final p in [tl, tr, br, bl]) {
        vertex(p, n, p.dot(right) / t.width, -p.dot(up) / t.height);
      }
    }
    indices.addAll([base, base + 1, base + 2, base, base + 2, base + 3]);
  }

  /// A face centred at [c] facing [n], [halfR] to each side and [halfU]
  /// along the viewer's [up].
  void face(Vector3 c, Vector3 n, Vector3 up, double halfR, double halfU) {
    final r = n.cross(up)..scale(halfR);
    final u = up * halfU;
    quad(c - r + u, c + r + u, c + r - u, c - r - u, n);
  }

  void box(Vector3 min, Vector3 max) {
    final c = (min + max) * 0.5, e = (max - min) * 0.5;
    final x = Vector3(1, 0, 0), y = Vector3(0, 1, 0), z = Vector3(0, 0, 1);
    face(c + x * e.x, x, y, e.z, e.y);
    face(c - x * e.x, -x, y, e.z, e.y);
    face(c + z * e.z, z, y, e.x, e.y);
    face(c - z * e.z, -z, y, e.x, e.y);
    face(c + y * e.y, y, z, e.x, e.z);
    face(c - y * e.y, -y, z, e.x, e.z);
  }

  void cylinder(CylinderPart p, {int segments = 16}) {
    final rb = p.bottomRadius, rt = p.topRadius, h = p.height, b = p.base;
    Vector3 ring(double r, double y, double a) =>
        b + Vector3(r * math.sin(a), y, r * math.cos(a));
    // Side: outward normal tilted by the taper. Textured, u runs around the
    // (mean) circumference and v down the height, both in metres.
    final t = tile;
    final uScale = t == null ? 1.0 : math.pi * (rb + rt) / t.width;
    final vScale = t == null ? 1.0 : h / t.height;
    final base = vertexCount;
    for (var i = 0; i <= segments; i++) {
      final a = 2 * math.pi * i / segments;
      final n = Vector3(h * math.sin(a), rb - rt, h * math.cos(a)).normalized();
      final u = i / segments * uScale;
      vertex(ring(rt, h, a), n, u, 0);
      vertex(ring(rb, 0, a), n, u, vScale);
    }
    for (var i = 0; i < segments; i++) {
      final t0 = base + 2 * i, b0 = t0 + 1, t1 = t0 + 2, b1 = t0 + 3;
      // The viewer's right (n × up) runs toward decreasing angle, so the
      // segment reads t1 (top-left), t0, b0, b1, wound as in [quad].
      indices.addAll([t1, t0, b0, t1, b0, b1]);
    }
    void cap(double r, double y, Vector3 n) {
      if (r <= 0) return;
      final centre = vertexCount;
      // Untextured: the cap's disc fills 0..1. Textured: metres.
      final su = t == null ? 0.5 : r / t.width, sv = t == null ? 0.5 : r / t.height;
      final c = t == null ? 0.5 : 0.0;
      vertex(b + Vector3(0, y, 0), n, c, c);
      for (var i = 0; i <= segments; i++) {
        final a = 2 * math.pi * i / segments;
        vertex(ring(r, y, a), n, c + su * math.sin(a), c + sv * math.cos(a));
      }
      for (var i = 0; i < segments; i++) {
        final p0 = centre + 1 + i, p1 = p0 + 1;
        indices.addAll(n.y > 0 ? [centre, p0, p1] : [centre, p1, p0]);
      }
    }

    cap(rt, h, Vector3(0, 1, 0));
    cap(rb, 0, Vector3(0, -1, 0));
  }
}

/// One mesh's vertex data for [parts] (flat normals on boxes and quads,
/// smooth sides on cylinders). Pure CPU: no GPU needed.
///
/// [mirrored]: the mesh will sit under a scale.x = −1 parent (room B). The
/// engine flips the winding there, but not the UVs, so u is flipped here to
/// keep textures (Task 24's screen poster) reading left to right. For a
/// repeating texture 1 − u tiles exactly like −u.
MeshData partsMeshData(List<Part> parts, {bool mirrored = false}) {
  final a = _Arrays();
  for (final p in parts) {
    a.tile = p.finish.texture;
    switch (p) {
      case BoxPart():
        a.box(p.min, p.max);
      case QuadPart():
        a.face(p.center, p.normal, Vector3(0, 1, 0), p.width / 2, p.height / 2);
      case CylinderPart():
        a.cylinder(p);
      case ClothPart():
        final offset = a.vertexCount;
        a.positions.addAll(p.data.positions);
        a.normals.addAll(p.data.normals!);
        a.uvs.addAll(p.data.texCoords!);
        a.indices.addAll(p.data.indices!.map((i) => i + offset));
    }
  }
  if (mirrored) {
    for (var i = 0; i < a.uvs.length; i += 2) {
      a.uvs[i] = 1 - a.uvs[i];
    }
  }
  return MeshData(
    positions: Float32List.fromList(a.positions),
    vertexCount: a.vertexCount,
    normals: Float32List.fromList(a.normals),
    texCoords: Float32List.fromList(a.uvs),
    indices: a.indices,
  );
}

// -------------------------------------------------------------- room layout

BoxPart _wall(Box2 b, Finish f, {double y0 = 0, double y1 = FloorPlan.ceiling}) =>
    BoxPart.footprint(b, y0, y1, f);

/// The walls node: FloorPlan.wallsA plus room A's half of the shared wall,
/// so the visible walls are exactly the colliders. The window wall is glass
/// over the opening (see `window_glass`) and the railing is a glass
/// balustrade.
RoomNode _walls() {
  const t = FloorPlan.wallT;
  const depth = FloorPlan.roomDepth;
  const rail = depth + FloorPlan.balconyDepth;
  final paint = <Part>[];
  for (final b in FloorPlan.wallsA) {
    if (b.minZ == depth && b.maxZ == depth + t) {
      // Window wall segment: solid outside the window opening only.
      if (b.minX < windowX0) {
        paint.add(_wall(Box2(b.minX, b.minZ, math.min(b.maxX, windowX0), b.maxZ), _paint));
      }
      if (b.maxX > windowX1) {
        paint.add(_wall(Box2(math.max(b.minX, windowX1), b.minZ, b.maxX, b.maxZ), _paint));
      }
    } else if (b.minZ == rail) {
      paint.add(_wall(b, _paint, y1: 0.1)); // railing curb
    } else {
      paint.add(_wall(b, _paint));
    }
  }
  // Headers over the window opening and the bathroom door gap.
  paint
    ..add(_wall(const Box2(windowX0, depth, windowX1, depth + t), _paint, y0: _windowTop))
    ..add(_wall(const Box2(FloorPlan.bathX1 - 0.06, FloorPlan.bathDoorZ0, FloorPlan.bathX1,
        FloorPlan.bathDoorZ1), _paint, y0: _doorTop));
  // Room A's half of the shared wall; room B's mirror supplies the other
  // half, so either room still has a whole wall when the other is hidden.
  for (final b in FloorPlan.sharedWall) {
    paint.add(_wall(Box2(b.minX, b.minZ, 0, b.maxZ), _paint));
  }
  paint.add(_wall(const Box2(-t / 2, FloorPlan.doorZ0, 0, FloorPlan.doorZ1), _paint,
      y0: _doorTop));

  final railBox = FloorPlan.wallsA.firstWhere((b) => b.minZ == rail);
  return RoomNode('walls', parts: [
    ...paint,
    _wall(railBox, _chrome, y0: 1.0, y1: 1.08), // top rail
  ], children: [
    RoomNode('railing_glass', castsShadows: false, parts: [
      QuadPart(Vector3((railBox.minX + railBox.maxX) / 2, 0.55, (railBox.minZ + railBox.maxZ) / 2),
          Vector3(0, 0, -1), railBox.maxX - railBox.minX, 0.9, _railingGlass),
    ]),
  ]);
}

RoomNode _floor() {
  const t = FloorPlan.wallT;
  const inside = FloorPlan.roomDepth + t;
  const edge = -FloorPlan.roomWidth - t;
  const bathZ = FloorPlan.bathZ1 + 0.06;
  return RoomNode('floor', parts: [
    _wall(const Box2(edge, -t, FloorPlan.bathX1, bathZ), _bathFloor, y0: -0.1, y1: 0),
    _wall(const Box2(FloorPlan.bathX1, -t, 0, bathZ), _parquetFloor, y0: -0.1, y1: 0),
    _wall(const Box2(edge, bathZ, 0, inside), _parquetFloor, y0: -0.1, y1: 0),
    _wall(const Box2(edge, inside, 0, FloorPlan.roomDepth + FloorPlan.balconyDepth + t),
        _balconyTile, y0: -0.1, y1: 0),
  ]);
}

RoomNode _furniture(String name, List<Part> Function(Box2 b) parts) =>
    RoomNode(name, parts: parts(FloorPlan.furnitureA[name]!));

List<RoomNode> _furnitureNodes() => [
      _furniture('bed', (b) => [
            BoxPart.footprint(b, 0, 0.3, _bedFrameWood),
            BoxPart.footprint(
                Box2(b.minX, b.minZ + .1, b.maxX - .1, b.maxZ - .1),
                0.3, 0.55, _linen),
            // Upholstered headboard with five channel tufts.
            BoxPart.footprint(Box2(b.minX, b.minZ, b.minX + 0.1, b.maxZ), 0.3, 1.35, _headboardVelvet),
            for (var i = 0; i < 5; i++)
              BoxPart.footprint(
                  Box2(b.minX + 0.1, b.minZ + 0.04 + i * 0.424, b.minX + 0.13,
                      b.minZ + 0.424 + i * 0.424),
                  0.62, 1.3, _headboardVelvet),
            // Two sleeping pillows, two decorative ones in front of them.
            for (final (z0, z1) in [(b.minZ + 0.15, b.minZ + 1.05), (b.maxZ - 1.05, b.maxZ - 0.15)])
              ClothPart(pillowMesh(
                  center: Vector3(b.minX + .38, .65, (z0 + z1) / 2),
                  length: .47, width: z1 - z0, thickness: .2,
                  textureSize: Vector2(_linenWeave.width, _linenWeave.height),
                  phase: z0), _linen),
            for (final (z0, z1) in [(b.minZ + 0.35, b.minZ + 0.95), (b.maxZ - 0.95, b.maxZ - 0.35)])
              ClothPart(pillowMesh(
                  center: Vector3(b.minX + .61, .76, (z0 + z1) / 2),
                  length: .4, width: z1 - z0, thickness: .18,
                  textureSize: Vector2(_jacquard.width, _jacquard.height),
                  upright: true, phase: z0), _pillowJacquard),
            // Linen duvet and wool throw roll over the inset mattress;
            // their hems stay inside the existing bed collider footprint.
            ClothPart(blanketMesh(
                headX: b.minX + .65, footX: b.maxX - .1,
                minZ: b.minZ + .1, maxZ: b.maxZ - .1, height: .595,
                textureSize: Vector2(_linenWeave.width, _linenWeave.height)), _linen),
            ClothPart(blanketMesh(
                headX: b.maxX - .67, footX: b.maxX - .085,
                minZ: b.minZ + .085, maxZ: b.maxZ - .085, height: .614,
                hanging: .17, thickness: .012,
                textureSize: Vector2(_woolWeave.width, _woolWeave.height)), _throwWool),
          ]),
      _furniture('bench', (b) => [
            BoxPart.footprint(b, 0.36, 0.46, _benchLeather),
            for (final (x, z) in [
              (b.minX + 0.05, b.minZ + 0.05), (b.maxX - 0.05, b.minZ + 0.05),
              (b.minX + 0.05, b.maxZ - 0.05), (b.maxX - 0.05, b.maxZ - 0.05),
            ])
              CylinderPart(Vector3(x, 0, z),
                  bottomRadius: 0.018, topRadius: 0.018, height: 0.36, finish: _brass),
          ]),
      _furniture('coffee_table', (b) => [
            BoxPart.footprint(b, 0.38, 0.42, _blackStone),
            for (final (x, z) in [
              (b.minX + 0.08, b.minZ + 0.08), (b.maxX - 0.08, b.minZ + 0.08),
              (b.minX + 0.08, b.maxZ - 0.08), (b.maxX - 0.08, b.maxZ - 0.08),
            ])
              CylinderPart(Vector3(x, 0, z),
                  bottomRadius: 0.02, topRadius: 0.02, height: 0.38, finish: _brass),
            // Two coffee-table books and a brass bowl.
            BoxPart(Vector3(-2.0, 0.42, 2.9), Vector3(-1.7, 0.45, 3.15), _canvas),
            BoxPart(Vector3(-1.98, 0.45, 2.93), Vector3(-1.74, 0.475, 3.12), _artTeal),
            CylinderPart(Vector3(-1.4, 0.42, 3.05),
                bottomRadius: 0.08, topRadius: 0.12, height: 0.06, finish: _brass),
          ]),
      _furniture('sofa', (b) => [
            BoxPart.footprint(b, 0, 0.45, _sofaFabric),
            BoxPart.footprint(Box2(b.minX, b.maxZ - 0.2, b.maxX, b.maxZ), 0.45, 0.85, _sofaFabric),
            BoxPart.footprint(Box2(b.minX, b.minZ, b.minX + 0.15, b.maxZ - 0.2), 0.45, 0.65, _sofaFabric),
            BoxPart.footprint(Box2(b.maxX - 0.15, b.minZ, b.maxX, b.maxZ - 0.2), 0.45, 0.65, _sofaFabric),
          ]),
      _furniture('desk', (b) => [
            BoxPart.footprint(b, 0.72, 0.76, _deskWood),
            BoxPart.footprint(Box2(b.minX, b.minZ, b.minX + 0.05, b.maxZ), 0, 0.72, _deskWood),
            BoxPart.footprint(Box2(b.maxX - 0.05, b.minZ, b.maxX, b.maxZ), 0, 0.72, _deskWood),
            // Monitor behind pc_screen (−3.8, 1.05, 0.25): body, neck, foot.
            BoxPart(Vector3(-4.1, 0.86, 0.21), Vector3(-3.5, 1.24, 0.245), _blackPlastic),
            BoxPart(Vector3(-3.83, 0.76, 0.18), Vector3(-3.77, 0.86, 0.21), _blackPlastic),
            BoxPart(Vector3(-3.95, 0.76, 0.12), Vector3(-3.65, 0.775, 0.3), _blackPlastic),
          ]),
      _furniture('tv_unit', (b) => [
            BoxPart.footprint(b, 0, 0.5, _tvWood),
            // TV body on the bathroom wall, behind tv_screen (z = 2.68).
            BoxPart(Vector3(-7.33, 0.93, b.minZ), Vector3(-6.07, 1.67, 2.675), _blackPlastic),
          ]),
      _furniture('shelf', (b) => [BoxPart.footprint(b, 0, 1.0, _shelfWood)]),
      _furniture('basin', (b) => [
            BoxPart.footprint(b, 0, 0.8, _vanityWood),
            BoxPart.footprint(b, 0.8, 0.85, _porcelain),
          ]),
      _furniture('shower', (b) => [BoxPart.footprint(b, 0, 0.05, _porcelain)]),
      RoomNode('bedside_table', parts: [
        BoxPart(Vector3(-7.95, 0, 5.45), Vector3(-7.45, 0.6, 5.93), _bedsideWood),
        BoxPart(Vector3(-7.45, 0.33, 5.5), Vector3(-7.44, 0.55, 5.88), _bedsideWood), // drawer
        BoxPart(Vector3(-7.44, 0.43, 5.66), Vector3(-7.425, 0.45, 5.72), _brass), // pull
      ]),
    ];

/// [shadeChannel]: the shade's light channel, for a shade that wraps the
/// lamp's light (see `lib/render/shadow_channels.dart`).
RoomNode _lamp(String name, Vector3 at,
        {required double stem,
        required double shadeY,
        required double shadeR,
        int? shadeChannel}) =>
    RoomNode(name, at: at, parts: [
      CylinderPart(Vector3.zero(),
          bottomRadius: shadeR * 0.6, topRadius: shadeR * 0.6, height: 0.02, finish: _brass),
      CylinderPart(Vector3.zero(),
          bottomRadius: 0.015, topRadius: 0.015, height: stem, finish: _brass),
    ], children: [
      // Task 16 lights the shade (emissive) when the lamp is on.
      RoomNode('lamp_shade', at: Vector3(0, shadeY, 0), lightChannelMask: shadeChannel, parts: [
        CylinderPart(Vector3.zero(),
            bottomRadius: shadeR, topRadius: shadeR * 0.65, height: shadeR * 1.4,
            finish: _shadeFabric),
      ]),
    ]);

List<RoomNode> _fixtures() {
  final shelf = FloorPlan.furnitureA['shelf']!;
  return [
    RoomNode('door_connect', at: Vector3(0, 0, FloorPlan.doorZ0), parts: [
      BoxPart(Vector3(-0.025, 0, 0), Vector3(0.025, _doorTop, FloorPlan.doorZ1 - FloorPlan.doorZ0),
          _doorWood),
      BoxPart(Vector3(-0.07, 0.98, 0.72), Vector3(0.07, 1.02, 0.82), _brass),
    ]),
    RoomNode('door_entrance',
        at: Vector3((FloorPlan.entranceX0 + FloorPlan.entranceX1) / 2, 0, 0.03),
        parts: [
          BoxPart(Vector3(-0.5, 0, -0.025), Vector3(0.5, _doorTop, 0.025), _doorWood),
          BoxPart(Vector3(0.33, 0.98, 0.025), Vector3(0.43, 1.02, 0.06), _brass),
        ]),
    _lamp('lamp_bedside', Vector3(-7.7, 0.6, 5.6),
        stem: 0.3, shadeY: 0.22, shadeR: 0.14, shadeChannel: kFixtureSelfShadowChannel),
    _lamp('lamp_floor', Vector3(-0.4, 0, 5.6), stem: 1.45, shadeY: 1.3, shadeR: 0.22),
    // Reading lights over the bed (the spot-lights feature lights them): a
    // brass plate on the outer wall, an arm, and a cone shade over each side
    // of the headboard, beside the art (z 3.5..5.1).
    for (final (name, z) in [('reading_light_left', 3.3), ('reading_light_right', 5.3)])
      RoomNode(name, at: Vector3(-FloorPlan.roomWidth, kReadingLightHeight, z), parts: [
        BoxPart(Vector3(0, -0.06, -0.04), Vector3(0.012, 0.03, 0.04), _brass), // wall plate
        BoxPart(Vector3(0.012, -0.008, -0.008), Vector3(kReadingLightArm, 0.008, 0.008), _brass), // arm
      ], children: [
        RoomNode('reading_light_shade',
            at: Vector3(kReadingLightArm, -0.13, 0),
            lightChannelMask: kFixtureSelfShadowChannel,
            parts: [
          CylinderPart(Vector3.zero(),
              bottomRadius: 0.07, topRadius: 0.03, height: 0.12, finish: _shadeFabric),
        ]),
      ]),
    // Water leaves each emitter's origin going −Y (Task 19): the nozzle's
    // tip. A basin mixer on the basin top (local y = −0.2), with a lever
    // that the water feature lifts while the water runs.
    RoomNode('faucet_spout', at: Vector3(-7.7, 1.05, 0.5), parts: [
      CylinderPart(Vector3(-0.2, -0.2, 0),
          bottomRadius: 0.035, topRadius: 0.035, height: 0.02, finish: _chrome),
      CylinderPart(Vector3(-0.2, -0.18, 0),
          bottomRadius: 0.02, topRadius: 0.02, height: 0.36, finish: _chrome),
      BoxPart(Vector3(-0.2, 0.14, -0.018), Vector3(0.02, 0.18, 0.018), _chrome),
      BoxPart(Vector3(-0.015, 0, -0.018), Vector3(0.02, 0.14, 0.018), _chrome),
    ], children: [
      RoomNode('faucet_lever', at: Vector3(-0.2, 0.18, 0), parts: [
        CylinderPart(Vector3.zero(),
            bottomRadius: 0.022, topRadius: 0.022, height: 0.03, finish: _chrome),
        BoxPart(Vector3(0, 0.01, -0.012), Vector3(0.12, 0.025, 0.012), _chrome),
      ]),
    ]),
    // Bathroom ceiling light (Task 16's lamps feature lights it) and its
    // wall switch beside the bathroom door, on the bedroom side.
    RoomNode('bath_light', at: Vector3(-6.6, FloorPlan.ceiling, 1.3), parts: [
      CylinderPart(Vector3(0, -0.04, 0),
          bottomRadius: 0.18, topRadius: 0.18, height: 0.04, finish: _brass),
    ], children: [
      RoomNode('bath_light_diffuser', parts: [
        CylinderPart(Vector3(0, -0.045, 0),
            bottomRadius: 0.15, topRadius: 0.15, height: 0.005, finish: _opalGlass),
      ]),
    ]),
    RoomNode('bath_switch', parts: [
      BoxPart(Vector3(FloorPlan.bathX1, 1.14, 2.1), Vector3(FloorPlan.bathX1 + 0.01, 1.26, 2.2),
          _porcelain),
    ], children: [
      // The rocker pivots about its centre; the lamps feature tips it.
      RoomNode('bath_switch_rocker', at: Vector3(FloorPlan.bathX1 + 0.01, 1.2, 2.15), parts: [
        BoxPart(Vector3(0, -0.03, -0.02), Vector3(0.008, 0.03, 0.02), _porcelain),
      ]),
    ]),
    RoomNode('shower_head', at: Vector3(-5.8, 2.1, 0.55), parts: [
      CylinderPart(Vector3.zero(), bottomRadius: 0.1, topRadius: 0.1, height: 0.03, finish: _chrome),
      CylinderPart(Vector3(0, 0.03, 0),
          bottomRadius: 0.012, topRadius: 0.012, height: FloorPlan.ceiling - 2.13, finish: _chrome),
    ]),
    RoomNode('shower_glass', castsShadows: false, parts: [
      BoxPart(Vector3(-6.41, 0, 0), Vector3(-6.39, 2.0, 1.1), _showerGlass),
    ]),
    RoomNode('mirror', at: Vector3(-7.99, 1.55, 0.55), parts: [
      QuadPart(Vector3.zero(), Vector3(1, 0, 0), 0.9, 0.9, _mirror),
    ]),
    RoomNode('window_glass', castsShadows: false, parts: [
      // Two panes either side of the open balcony doorway.
      for (final (x0, x1) in [(windowX0, -3.6), (-2.4, windowX1)])
        QuadPart(Vector3((x0 + x1) / 2, _windowTop / 2, FloorPlan.roomDepth + FloorPlan.wallT / 2),
            Vector3(0, 0, -1), x1 - x0, _windowTop, _windowGlass),
    ]),
    // Curtains: 1.4 m panels bunched open (x-scale 0.25) at the window
    // edges; Task 18 eases the scale to 1 to close them.
    for (final (name, edge, side) in [
      ('curtain_left', windowX0, 1.0),
      ('curtain_right', windowX1, -1.0),
    ])
      RoomNode(name,
          at: Vector3(edge + side * 0.7 * 0.25, 0, 5.925),
          scale: Vector3(0.25, 1, 1),
          parts: [BoxPart(Vector3(-0.7, 0.03, -0.025), Vector3(0.7, 2.75, 0.025), _curtainFabric)]),
    RoomNode('tv_screen', at: Vector3(-6.7, 1.3, 2.68), parts: [
      QuadPart(Vector3.zero(), Vector3(0, 0, 1), 1.2, 0.675, _screen),
    ]),
    RoomNode('pc_screen', at: Vector3(-3.8, 1.05, 0.25), parts: [
      QuadPart(Vector3.zero(), Vector3(0, 0, 1), 0.55, 0.34, _screen),
    ]),
    for (var i = 0; i < 6; i++)
      RoomNode('book_$i', at: Vector3(shelf.minX + 0.1 + i * 0.045, 1.0, (shelf.minZ + shelf.maxZ) / 2),
          parts: [BoxPart(Vector3(-0.015, 0, -0.085), Vector3(0.015, 0.24, 0.085), _books[i])]),
  ];
}

/// Skirting (walnut, 10 cm) and crown moulding (8 cm) along the bedroom's
/// walls, each as [x0, z0, x1, z1] on a wall face with the room side given
/// by its sign. Doorways are left out of the skirting.
RoomNode _trim() {
  const t = FloorPlan.wallT;
  const s = 0.015, m = 0.04; // skirting and moulding depth
  const top = FloorPlan.ceiling;
  // (along X?, the face coordinate, room side (+1/−1), spans for skirting, span for moulding)
  final walls = <(bool, double, double, List<(double, double)>, (double, double))>[
    // Corridor wall (z = 0), bedroom part, around the entrance door.
    (true, 0, 1, [(FloorPlan.bathX1, FloorPlan.entranceX0), (FloorPlan.entranceX1, -t / 2)],
        (FloorPlan.bathX1, -t / 2)),
    // Window wall (z = 6), either side of the window.
    (true, FloorPlan.roomDepth, -1, [(-FloorPlan.roomWidth, windowX0), (windowX1, -t / 2)],
        (-FloorPlan.roomWidth, -t / 2)),
    // Bathroom wall, bedroom face (z = 2.66).
    (true, FloorPlan.bathZ1 + 0.06, 1, [(-FloorPlan.roomWidth, FloorPlan.bathX1)],
        (-FloorPlan.roomWidth, FloorPlan.bathX1)),
    // Outer wall (x = −8), bedroom part.
    (false, -FloorPlan.roomWidth, 1, [(FloorPlan.bathZ1 + 0.06, FloorPlan.roomDepth)],
        (FloorPlan.bathZ1 + 0.06, FloorPlan.roomDepth)),
    // Bathroom side wall, bedroom face (x = −5.2), around the bathroom door.
    (false, FloorPlan.bathX1, 1, [(0, FloorPlan.bathDoorZ0), (FloorPlan.bathDoorZ1, FloorPlan.bathZ1 + 0.06)],
        (0, FloorPlan.bathZ1 + 0.06)),
    // Shared wall (x = −0.06), around the connecting door.
    (false, -t / 2, -1, [(0, FloorPlan.doorZ0), (FloorPlan.doorZ1, FloorPlan.roomDepth)],
        (0, FloorPlan.roomDepth)),
  ];
  BoxPart piece(bool alongX, double face, double side, double a, double b, double depth,
      double y0, double y1, Finish f) {
    final d0 = side > 0 ? face : face - depth, d1 = side > 0 ? face + depth : face;
    return alongX
        ? BoxPart(Vector3(a, y0, d0), Vector3(b, y1, d1), f)
        : BoxPart(Vector3(d0, y0, a), Vector3(d1, y1, b), f);
  }

  return RoomNode('trim', parts: [
    for (final (alongX, face, side, spans, (m0, m1)) in walls) ...[
      for (final (a, b) in spans) piece(alongX, face, side, a, b, s, 0, 0.1, _vanityWood),
      piece(alongX, face, side, m0, m1, m, top - 0.08, top, _ceilingPaint),
    ],
  ]);
}

/// A framed abstract canvas on a wall face at x = [face], its room side
/// toward +X. [blocks] are (z0, y0, z1, y1, finish) colour fields.
RoomNode _art(String name, double face, double z0, double y0, double z1, double y1,
        List<(double, double, double, double, Finish)> blocks) =>
    RoomNode(name, parts: [
      BoxPart(Vector3(face, y0, z0), Vector3(face + 0.03, y1, z1), _brass), // frame
      BoxPart(Vector3(face + 0.03, y0 + 0.05, z0 + 0.05), Vector3(face + 0.035, y1 - 0.05, z1 - 0.05),
          _canvas),
      for (final (bz0, by0, bz1, by1, f) in blocks)
        BoxPart(Vector3(face + 0.035, by0, bz0), Vector3(face + 0.038, by1, bz1), f),
    ]);

List<RoomNode> _props() => [
      RoomNode('rug_bed', parts: [
        BoxPart(Vector3(-7.25, 0, 2.98), Vector3(-4.6, 0.012, 5.6), _rugTeddy),
      ]),
      RoomNode('rug_lounge', parts: [
        BoxPart(Vector3(-2.9, 0, 2.35), Vector3(-0.55, 0.012, 4.75), _rugJute),
      ]),
      _art('art_bed', -FloorPlan.roomWidth, 3.5, 1.5, 5.1, 2.4, [
        (3.7, 1.7, 4.2, 2.2, _artTerracotta),
        (4.3, 1.69, 4.6, 2.0, _artMustard), // clear of the charcoal line
        (4.4, 2.05, 4.95, 2.28, _artTeal),
        (3.65, 1.64, 4.95, 1.66, _artCharcoal),
      ]),
      // On the shared wall, facing −X: room A's side of x = −0.06.
      RoomNode('art_sofa', at: Vector3(-FloorPlan.wallT / 2, 0, 0), scale: Vector3(-1, 1, 1), children: [
        _art('art_sofa_canvas', 0, 3.4, 1.3, 4.6, 2.1, [
          (3.55, 1.45, 3.95, 1.95, _artTeal),
          (4.05, 1.4, 4.45, 1.7, _artTerracotta),
          (4.1, 1.78, 4.4, 1.98, _artMustard),
        ]),
      ]),
      _trim(),
      RoomNode('pendant', parts: [
        CylinderPart(Vector3(-1.7, 2.3, 3.05),
            bottomRadius: 0.006, topRadius: 0.006, height: FloorPlan.ceiling - 2.3, finish: _brass),
        CylinderPart(Vector3(-1.7, 2.05, 3.05),
            bottomRadius: 0.25, topRadius: 0.25, height: 0.25, finish: _brass),
        CylinderPart(Vector3(-1.7, 2.04, 3.05),
            bottomRadius: 0.23, topRadius: 0.23, height: 0.01, finish: _porcelain),
      ]),
      RoomNode('vase', parts: [
        CylinderPart(Vector3(-3.25, 0.76, 0.32),
            bottomRadius: 0.055, topRadius: 0.07, height: 0.2, finish: _porcelain),
        for (final (dx, dz, h) in [(-0.02, 0.0, 0.3), (0.02, 0.015, 0.34), (0.0, -0.02, 0.27)])
          CylinderPart(Vector3(-3.25 + dx, 0.9, 0.32 + dz),
              bottomRadius: 0.004, topRadius: 0.004, height: h - 0.14, finish: _leafGreen),
        for (final (dx, dz, y, f) in [
          (-0.02, 0.0, 1.06, _bloomPink), (0.02, 0.015, 1.1, _bloomWhite),
          (0.0, -0.02, 1.03, _bloomPink), (0.045, -0.03, 1.02, _bloomWhite),
          (-0.05, 0.03, 1.0, _bloomWhite),
        ])
          CylinderPart(Vector3(-3.25 + dx, y, 0.32 + dz),
              bottomRadius: 0.03, topRadius: 0.038, height: 0.04, finish: f),
      ]),
      RoomNode('orchid', parts: [
        CylinderPart(Vector3(-7.8, 0.85, 0.85),
            bottomRadius: 0.045, topRadius: 0.06, height: 0.1, finish: _porcelain),
        CylinderPart(Vector3(-7.8, 0.95, 0.85),
            bottomRadius: 0.004, topRadius: 0.004, height: 0.32, finish: _leafGreen),
        // Flat blooms facing the room, arching along the stem.
        for (final (dz, y) in [(0.0, 1.27), (0.03, 1.265), (0.06, 1.25), (0.085, 1.23)]) ...[
          BoxPart(Vector3(-7.8, y - 0.025, 0.85 + dz - 0.025),
              Vector3(-7.79, y + 0.025, 0.85 + dz + 0.025), _bloomWhite),
          BoxPart(Vector3(-7.79, y - 0.008, 0.85 + dz - 0.008),
              Vector3(-7.785, y + 0.008, 0.85 + dz + 0.008), _bloomPink),
        ],
      ]),
      RoomNode('towels', parts: [
        for (var i = 0; i < 3; i++)
          BoxPart(Vector3(-7.92 + i * 0.01, 0.85 + i * 0.05, 0.04 + i * 0.005),
              Vector3(-7.62 - i * 0.01, 0.9 + i * 0.05, 0.26 - i * 0.005), _linen),
      ]),
      // A brass border behind the mirror (x = −7.99), in front of the tiles.
      RoomNode('mirror_frame', parts: [
        BoxPart(Vector3(-7.998, 1.05, 0.05), Vector3(-7.994, 2.05, 1.05), _brass),
      ]),
      // Tiles on the bathroom's walls: behind the basin, and the shower's two.
      RoomNode('bath_cladding', parts: [
        BoxPart(Vector3(-FloorPlan.roomWidth, 0, 0), Vector3(-7.998, 2.4, FloorPlan.bathZ1),
            _bathTilesWall),
        BoxPart(Vector3(-FloorPlan.roomWidth, 0, 0), Vector3(FloorPlan.bathX1 - 0.06, 2.4, 0.002),
            _bathTilesWall),
        BoxPart(Vector3(FloorPlan.bathX1 - 0.062, 0, 0), Vector3(FloorPlan.bathX1 - 0.06, 2.4,
            FloorPlan.bathDoorZ0), _bathTilesWall),
      ]),
    ];

/// Every texture the parts under [spec] name (repeats included).
Iterable<TextureRef> textureRefs(RoomNode spec) sync* {
  for (final p in spec.parts) {
    final t = p.finish.texture;
    if (t != null) yield t;
  }
  for (final c in spec.children) {
    yield* textureRefs(c);
  }
}

/// Room A as data. Pure: safe to call in unit tests.
RoomNode roomASpec() => RoomNode('room', children: [
      _floor(),
      RoomNode('ceiling', parts: [
        _wall(const Box2(-FloorPlan.roomWidth - FloorPlan.wallT, -FloorPlan.wallT, 0,
            FloorPlan.roomDepth + FloorPlan.wallT), _ceilingPaint,
            y0: FloorPlan.ceiling, y1: FloorPlan.ceiling + 0.1),
      ]),
      _walls(),
      ..._furnitureNodes(),
      ..._fixtures(),
      ..._props(),
    ]);

// ------------------------------------------------------------------ nodes

PhysicallyBasedMaterial _material(Finish f, RoomTextures? textures) {
  final l = shadingLayers(f);
  final m = PhysicallyBasedMaterial()
    ..baseColorFactor = Vector4(f.r, f.g, f.b, f.alpha)
    ..metallicFactor = f.metallic
    ..roughnessFactor = l.roughness
    ..specular = l.specular
    ..clearcoat = l.clearcoat
    ..anisotropy = l.anisotropy;
  if (l.clearcoat > 0) m.clearcoatRoughness = l.clearcoatRoughness;
  final sheen = l.sheenColor;
  if (sheen != null) {
    m
      ..sheenColor = Vector4(sheen.x, sheen.y, sheen.z, 1)
      ..sheenRoughness = l.sheenRoughness;
  }
  final t = f.texture;
  if (t != null && textures != null) {
    m.baseColorTexture = textures.color(t);
    m.normalTexture = textures.normal(t);
  }
  if (f.alpha < 1) {
    m
      ..alphaMode = AlphaMode.blend
      ..doubleSided = true;
  }
  return m;
}

/// [parts] grouped by finish, in first-appearance order: the builder makes
/// one mesh primitive per entry, so an entry's index is its primitive's.
Map<Finish, List<Part>> _byFinish(List<Part> parts) {
  final byFinish = <Finish, List<Part>>{};
  for (final p in parts) {
    (byFinish[p.finish] ??= []).add(p);
  }
  return byFinish;
}

/// The finish of each mesh primitive the builder makes from [parts].
List<Finish> primitiveFinishes(List<Part> parts) => _byFinish(parts).keys.toList();

/// One primitive of a built node that wears decorative bedding.
class BeddingSlot {
  const BeddingSlot(this.primitive, this.role, this.finish);
  final int primitive;
  final BeddingMaterialRole role;
  final Finish finish;
}

/// The primitives built from [parts] whose finish is tagged as bedding.
List<BeddingSlot> beddingSlots(List<Part> parts) {
  final finishes = primitiveFinishes(parts);
  return [
    for (var i = 0; i < finishes.length; i++)
      if (finishes[i].bedding != BeddingMaterialRole.none)
        BeddingSlot(i, finishes[i].bedding, finishes[i]),
  ];
}

/// A built node's bedding primitives, with what they were built with so a
/// feature can relight them and put them back: the authored material and
/// the photo textures of each slot.
class BeddingMaterialTarget {
  BeddingMaterialTarget(this.node, this.slots, this.originals,
      {required this.colorTextures, required this.normalTextures});
  final Node node;
  final List<BeddingSlot> slots;

  /// Per slot: the material the builder gave it.
  final List<Material> originals;

  /// Per slot: its base-colour and normal photo textures, null when not
  /// loaded.
  final List<TextureSource?> colorTextures, normalTextures;
}

/// Builds [spec] into nodes: one primitive per finish, a fresh material per
/// node (so features can restyle one node without touching another). Every
/// node with bedding slots is added to [bedding].
Node _build(RoomNode spec, bool mirrored, RoomTextures? textures,
    List<BeddingMaterialTarget>? bedding) {
  final node = Node(name: spec.name, localTransform: spec.localTransform)
    ..shadowCastingMode = spec.castsShadows ? ShadowCastingMode.on : ShadowCastingMode.off;
  final channel = spec.lightChannelMask;
  if (channel != null) node.lightChannelMask = channel;
  if (spec.parts.isNotEmpty) {
    final mesh = node.mesh = Mesh.primitives(primitives: [
      for (final MapEntry(key: f, value: parts) in _byFinish(spec.parts).entries)
        MeshPrimitive(
            MeshGeometry.fromMeshData(partsMeshData(parts, mirrored: mirrored)),
            _material(f, textures)),
    ]);
    final slots = beddingSlots(spec.parts);
    if (bedding != null && slots.isNotEmpty) {
      bedding.add(BeddingMaterialTarget(
        node,
        slots,
        [for (final s in slots) mesh.primitives[s.primitive].material],
        colorTextures: [
          for (final s in slots)
            s.finish.texture == null ? null : textures?.color(s.finish.texture!)
        ],
        normalTextures: [
          for (final s in slots)
            s.finish.texture == null ? null : textures?.normal(s.finish.texture!)
        ],
      ));
    }
  }
  for (final c in spec.children) {
    node.add(_build(c, mirrored, textures, bedding));
  }
  return node;
}

/// Room A's node tree (needs the GPU: call after
/// `Scene.initializeStaticResources()`). Pass [mirrored] for the copy that
/// becomes room B under a scale.x = −1 parent, and the loaded [textures]
/// (see [textureRefs]); without them every part shows its plain colour.
/// The bed's decorative bedding primitives are appended to [bedding].
Node buildRoomA(
        {bool mirrored = false,
        RoomTextures? textures,
        List<BeddingMaterialTarget>? bedding}) =>
    _build(roomASpec(), mirrored, textures, bedding);
