import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';
import '../math/colliders.dart';
import '../math/floor_plan.dart';
import 'room_textures.dart';

/// Room A, authored as plain data (`roomASpec`, GPU-free and unit-tested)
/// and turned into scene nodes by [buildRoomA]. Every mesh is built from
/// boxes, quads and cylinders in room A space (x ∈ [−8, 0]). These
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

/// Surface look of a part: linear RGB base colour plus PBR factors. With a
/// [texture], the colour tints it (the fabrics ship grey, so the tint is
/// their colour) and the part's UVs run in metres.
class Finish {
  const Finish(this.r, this.g, this.b,
      {this.roughness = 0.8, this.metallic = 0, this.alpha = 1, this.texture});
  final double r, g, b, roughness, metallic, alpha;
  final TextureRef? texture;
}

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

const _paint = Finish(0.95, 0.88, 0.78, roughness: 0.9, texture: _stucco);
const _ceilingPaint = Finish(0.90, 0.90, 0.88, roughness: 0.95);
const _parquetFloor = Finish(1, 1, 1, roughness: 0.45, texture: _parquet);
const _bathFloor = Finish(1, 1, 1, roughness: 0.25, texture: _bathTiles);
const _balconyTile = Finish(1, 1, 1, roughness: 0.6, texture: _pavers);
const _linen = Finish(1.0, 0.96, 0.9, roughness: 0.9, texture: _linenWeave);
const _sofaFabric = Finish(0.62, 0.53, 0.43, roughness: 0.9, texture: _caban);
const _bedFrameWood = Finish(0.85, 0.58, 0.40, roughness: 0.5, texture: _americanWalnut);
const _deskWood = Finish(0.85, 0.72, 0.60, roughness: 0.45, texture: _teak);
const _bedsideWood = Finish(1, 1, 1, roughness: 0.2, texture: _cherry);
const _tvWood = Finish(0.45, 0.38, 0.33, roughness: 0.4, texture: _blackOak);
const _shelfWood = Finish(1.0, 0.92, 0.82, roughness: 0.55, texture: _whiteOak);
const _vanityWood = Finish(1, 1, 1, roughness: 0.45, texture: _walnut);
const _doorWood = Finish(0.55, 0.42, 0.33, roughness: 0.4, texture: _blackWalnut);
const _brass = Finish(0.90, 0.70, 0.35, roughness: 0.3, metallic: 1);
const _chrome = Finish(0.80, 0.80, 0.82, roughness: 0.2, metallic: 1);
const _blackPlastic = Finish(0.02, 0.02, 0.02, roughness: 0.4);
const _screen = Finish(0, 0, 0, roughness: 0.15);
const _mirror = Finish(0.95, 0.95, 0.95, roughness: 0.02, metallic: 1);
const _porcelain = Finish(0.95, 0.95, 0.95, roughness: 0.2);
const _shadeFabric = Finish(0.95, 0.88, 0.72, roughness: 0.9, texture: _hessian);
const _curtainFabric = Finish(0.80, 0.70, 0.55, roughness: 0.35, texture: _satin);
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
      this.castsShadows = true})
      : at = at ?? Vector3.zero(),
        scale = scale ?? Vector3.all(1);
  final String name;
  final Vector3 at, scale;
  final List<Part> parts;
  final List<RoomNode> children;
  final bool castsShadows;

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
            BoxPart.footprint(b, 0.3, 0.55, _linen),
            BoxPart.footprint(Box2(b.minX, b.minZ, b.minX + 0.1, b.maxZ), 0.55, 1.1, _bedFrameWood),
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
      ]),
    ];

RoomNode _lamp(String name, Vector3 at,
        {required double stem, required double shadeY, required double shadeR}) =>
    RoomNode(name, at: at, parts: [
      CylinderPart(Vector3.zero(),
          bottomRadius: shadeR * 0.6, topRadius: shadeR * 0.6, height: 0.02, finish: _brass),
      CylinderPart(Vector3.zero(),
          bottomRadius: 0.015, topRadius: 0.015, height: stem, finish: _brass),
    ], children: [
      // Task 16 lights the shade (emissive) when the lamp is on.
      RoomNode('lamp_shade', at: Vector3(0, shadeY, 0), parts: [
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
    _lamp('lamp_bedside', Vector3(-7.7, 0.6, 5.6), stem: 0.3, shadeY: 0.22, shadeR: 0.14),
    _lamp('lamp_floor', Vector3(-0.4, 0, 5.6), stem: 1.45, shadeY: 1.3, shadeR: 0.22),
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
    ]);

// ------------------------------------------------------------------ nodes

PhysicallyBasedMaterial _material(Finish f, RoomTextures? textures) {
  final m = PhysicallyBasedMaterial()
    ..baseColorFactor = Vector4(f.r, f.g, f.b, f.alpha)
    ..metallicFactor = f.metallic
    ..roughnessFactor = f.roughness;
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

/// Builds [spec] into nodes: one primitive per finish, a fresh material per
/// node (so features can restyle one node without touching another).
Node _build(RoomNode spec, bool mirrored, RoomTextures? textures) {
  final node = Node(name: spec.name, localTransform: spec.localTransform)
    ..castsShadows = spec.castsShadows;
  if (spec.parts.isNotEmpty) {
    final byFinish = <Finish, List<Part>>{};
    for (final p in spec.parts) {
      (byFinish[p.finish] ??= []).add(p);
    }
    node.mesh = Mesh.primitives(primitives: [
      for (final MapEntry(key: f, value: parts) in byFinish.entries)
        MeshPrimitive(
            MeshGeometry.fromMeshData(partsMeshData(parts, mirrored: mirrored)),
            _material(f, textures)),
    ]);
  }
  for (final c in spec.children) {
    node.add(_build(c, mirrored, textures));
  }
  return node;
}

/// Room A's node tree (needs the GPU: call after
/// `Scene.initializeStaticResources()`). Pass [mirrored] for the copy that
/// becomes room B under a scale.x = −1 parent, and the loaded [textures]
/// (see [textureRefs]); without them every part shows its plain colour.
Node buildRoomA({bool mirrored = false, RoomTextures? textures}) =>
    _build(roomASpec(), mirrored, textures);
