import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/features/placeholder_rooms.dart';
import 'package:flutter_3d/math/colliders.dart';
import 'package:flutter_3d/math/floor_plan.dart';

/// Every node in [root] with its world transform (room A space) and the
/// names of its ancestors, itself included.
List<(RoomNode, Matrix4, List<String>)> placedWithPath(RoomNode root) {
  final out = <(RoomNode, Matrix4, List<String>)>[];
  void walk(RoomNode n, Matrix4 parent, List<String> path) {
    final m = parent * n.localTransform;
    final p = [...path, n.name];
    out.add((n, m, p));
    for (final c in n.children) {
      walk(c, m, p);
    }
  }

  walk(root, Matrix4.identity(), const []);
  return out;
}

List<(RoomNode, Matrix4)> placed(RoomNode root) =>
    [for (final (n, m, _) in placedWithPath(root)) (n, m)];

Aabb3 worldBounds(Part p, Matrix4 m) => Aabb3.copy(p.bounds)..transform(m);

(RoomNode, Matrix4) only(RoomNode root, String name) {
  final hits = placed(root).where((e) => e.$1.name == name).toList();
  expect(hits, hasLength(1), reason: 'node "$name"');
  return hits.single;
}

/// World bounds of every part under the node named [name], descendants included.
List<Aabb3> partsUnder(RoomNode root, String name) {
  only(root, name);
  return [
    for (final (n, m, path) in placedWithPath(root))
      if (path.contains(name))
        for (final p in n.parts) worldBounds(p, m),
  ];
}

Aabb3 union(List<Aabb3> boxes) {
  final u = Aabb3.copy(boxes.first);
  for (final b in boxes.skip(1)) {
    u.hull(b);
  }
  return u;
}

void expectVec(Vector3 actual, Vector3 expected, {String? reason}) {
  expect((actual - expected).length, lessThan(1e-5),
      reason: '${reason ?? ''} got $actual, want $expected');
}

const tol = 1e-5;

bool footprintInside(Aabb3 b, Box2 c) =>
    b.min.x >= c.minX - tol &&
    b.max.x <= c.maxX + tol &&
    b.min.z >= c.minZ - tol &&
    b.max.z <= c.maxZ + tol;

/// Room A's own half of the shared wall (room B gets the mirrored half).
final sharedHalfA = [
  for (final b in FloorPlan.sharedWall) Box2(b.minX, b.minZ, 0, b.maxZ)
];

void main() {
  final room = roomASpec();

  test('every node-contract name appears exactly once in room A', () {
    const names = [
      'floor', 'walls', 'ceiling', 'door_connect', 'lamp_bedside',
      'lamp_floor', 'faucet_spout', 'shower_head', 'shower_glass', 'mirror',
      'window_glass', 'curtain_left', 'curtain_right', 'tv_screen',
      'pc_screen', 'book_0', 'book_1', 'book_2', 'book_3', 'book_4', 'book_5',
      'door_entrance',
    ];
    for (final n in names) {
      only(room, n);
    }
  });

  test('visible walls stand only where a collider is (what you see is what you hit)', () {
    final colliders = [...FloorPlan.wallsA, ...sharedHalfA];
    final visible = [
      ...partsUnder(room, 'walls'),
      ...partsUnder(room, 'window_glass'),
    ];
    for (final b in visible) {
      if (b.min.y >= 2.0) continue; // headers over openings: you walk under them
      expect(colliders.any((c) => footprintInside(b, c)), true,
          reason: 'wall piece $b has no collider under it');
    }
  });

  test('every wall collider is visibly filled at waist height', () {
    final visible = [
      ...partsUnder(room, 'walls'),
      ...partsUnder(room, 'window_glass'),
    ];
    bool covered(double x, double z) => visible.any((b) =>
        b.min.y <= 1.0 &&
        b.max.y >= 1.0 &&
        x >= b.min.x - 0.01 &&
        x <= b.max.x + 0.01 &&
        z >= b.min.z - 0.01 &&
        z <= b.max.z + 0.01);
    for (final c in [...FloorPlan.wallsA, ...sharedHalfA]) {
      final alongX = c.maxX - c.minX >= c.maxZ - c.minZ;
      final cx = (c.minX + c.maxX) / 2, cz = (c.minZ + c.maxZ) / 2;
      final (a, b) = alongX ? (c.minX, c.maxX) : (c.minZ, c.maxZ);
      for (var t = a; t <= b; t += 0.05) {
        final (x, z) = alongX ? (t, cz) : (cx, t);
        expect(covered(x, z), true, reason: 'collider $c has a see-through hole at ($x, $z)');
      }
    }
  });

  test('each furniture collider has a visible piece with the same footprint', () {
    for (final MapEntry(key: name, value: box) in FloorPlan.furnitureA.entries) {
      final u = union(partsUnder(room, name));
      expect(u.min.x, closeTo(box.minX, tol), reason: name);
      expect(u.max.x, closeTo(box.maxX, tol), reason: name);
      expect(u.min.z, closeTo(box.minZ, tol), reason: name);
      expect(u.max.z, closeTo(box.maxZ, tol), reason: name);
      expect(u.min.y, closeTo(0, tol), reason: '$name stands on the floor');
    }
  });

  test('connecting door leaf: origin at the hinge, 0.9 × 2.1 × 0.05, room A only', () {
    final (door, m) = only(room, 'door_connect');
    expectVec(m.getTranslation(), Vector3(0, 0, FloorPlan.doorZ0));
    final local = door.parts.first.bounds; // the leaf; the handle sticks out
    expect(local.min.z, closeTo(0, tol));
    expect(local.max.z, closeTo(FloorPlan.doorZ1 - FloorPlan.doorZ0, tol));
    expect(local.max.y, closeTo(2.1, tol));
    expect(local.min.x, closeTo(-0.025, 0.02));
    expect(local.max.x, closeTo(0.025, 0.02));
  });

  test('screens and mirror are quads where Tasks 23 and 24 expect them', () {
    void quad(String name, Vector3 centre, Vector3 normal, double w, double h) {
      final (n, m) = only(room, name);
      final q = n.parts.single as QuadPart;
      expectVec(q.normal, normal, reason: name);
      expect(q.width, closeTo(w, tol), reason: name);
      expect(q.height, closeTo(h, tol), reason: name);
      final b = worldBounds(q, m);
      expectVec(b.center, centre, reason: name);
    }

    quad('tv_screen', Vector3(-6.7, 1.3, 2.68), Vector3(0, 0, 1), 1.2, 0.675);
    quad('pc_screen', Vector3(-3.8, 1.05, 0.25), Vector3(0, 0, 1), 0.55, 0.34);
    quad('mirror', Vector3(-7.99, 1.55, 0.55), Vector3(1, 0, 0), 0.9, 0.9);
    // The mirror node itself is unrotated, so its local normal is +X (Task 23).
    expect(only(room, 'mirror').$2.getRotation().isIdentity(), true);
  });

  test('faucet: a mixer standing on the basin with a lever you can tap', () {
    final basin = FloorPlan.furnitureA['basin']!;
    final faucet = union(partsUnder(room, 'faucet_spout'));
    expect(faucet.min.y, closeTo(0.85, tol), reason: 'stands on the basin top');
    expect(footprintInside(faucet, basin), true);
    // The lever is a child of the spout, so a tap on it finds the faucet's
    // interaction (InteractionRegistry.forNode walks up the parents).
    final lever = placedWithPath(room).where((e) => e.$1.name == 'faucet_lever').single;
    expect(lever.$3, containsAllInOrder(['faucet_spout', 'faucet_lever']));
    expect(union(partsUnder(room, 'faucet_lever')).max.x -
        union(partsUnder(room, 'faucet_lever')).min.x, greaterThanOrEqualTo(0.1));
  });

  test('entrance door fills the entrance span on the corridor wall', () {
    final u = union(partsUnder(room, 'door_entrance'));
    expect(u.min.x, closeTo(FloorPlan.entranceX0, tol));
    expect(u.max.x, closeTo(FloorPlan.entranceX1, tol));
    expect(u.min.z, greaterThanOrEqualTo(0));
    expect(u.max.z, lessThan(0.1));
    expect(u.max.y, closeTo(2.1, tol));
  });

  test('books stand on the shelf top at y = 1.0', () {
    final shelf = FloorPlan.furnitureA['shelf']!;
    expect(union(partsUnder(room, 'shelf')).max.y, closeTo(1.0, tol));
    for (var i = 0; i < 6; i++) {
      final b = union(partsUnder(room, 'book_$i'));
      expect(b.min.y, closeTo(1.0, tol), reason: 'book_$i');
      expect(footprintInside(b, shelf), true, reason: 'book_$i off the shelf');
    }
  });

  test('curtains are 1.4 m panels bunched open at the window edges', () {
    for (final (name, edge) in [
      ('curtain_left', windowX0),
      ('curtain_right', windowX1),
    ]) {
      final (n, m) = only(room, name);
      final local = union([for (final p in n.parts) p.bounds]);
      expect(local.max.x - local.min.x, closeTo(1.4, tol), reason: name);
      expect(n.scale.x, closeTo(0.25, tol), reason: '$name open by default');
      final w = union([for (final p in n.parts) worldBounds(p, m)]);
      expect(w.min.x, greaterThanOrEqualTo(windowX0 - tol), reason: name);
      expect(w.max.x, lessThanOrEqualTo(windowX1 + tol), reason: name);
      expect(math.min((w.min.x - edge).abs(), (w.max.x - edge).abs()),
          lessThan(tol), reason: '$name hangs at its window edge');
      expect(w.max.z, lessThan(FloorPlan.roomDepth), reason: '$name inside the glass');
    }
  });

  test('every texture the room names ships in assets/textures', () {
    final refs = textureRefs(room).toList();
    expect(refs, isNotEmpty);
    for (final t in refs) {
      expect(File(t.colorAsset).existsSync(), true, reason: t.colorAsset);
      if (t.hasNormal) expect(File(t.normalAsset).existsSync(), true, reason: t.normalAsset);
      expect(t.width, greaterThan(0));
      expect(t.height, greaterThan(0));
    }
  });

  test('objects get their own materials: the big surfaces are all textured', () {
    Set<String?> texturesOf(String name) => {
          for (final (n, _, path) in placedWithPath(room))
            if (path.contains(name))
              for (final p in n.parts) p.finish.texture?.id,
        };
    for (final name in ['floor', 'walls', 'bed', 'sofa', 'desk', 'bedside_table', 'tv_unit']) {
      expect(texturesOf(name).whereType<String>(), isNotEmpty, reason: name);
    }
    // Variety: tables and cabinets don't all share one wood.
    final woods = {
      for (final name in ['desk', 'bedside_table', 'tv_unit', 'shelf', 'basin'])
        texturesOf(name).whereType<String>().first,
    };
    expect(woods.length, greaterThanOrEqualTo(4));
  });

  test('glass casts no shadow; every other mesh node does', () {
    for (final (n, _) in placed(room)) {
      if (n.parts.isEmpty) continue;
      final glass = n.parts.every((p) => p.finish.alpha < 1);
      expect(n.castsShadows, !glass, reason: n.name);
    }
  });

  group('mesh arrays', () {
    List<Vector3> vecs(List<double> xs) => [
          for (var i = 0; i < xs.length; i += 3) Vector3(xs[i], xs[i + 1], xs[i + 2])
        ];

    void expectWindingMatchesNormals(List<Part> parts, String reason) {
      final d = partsMeshData(parts);
      // The engine derives normals from winding (e1 × e2); front faces must
      // agree with the normals we ship, or the mesh renders inside out.
      final fromWinding =
          MeshData.build(positions: d.positions, indices: d.indices).normals!;
      final ours = vecs(d.normals!), derived = vecs(fromWinding);
      expect(ours.length, d.vertexCount);
      for (var i = 0; i < ours.length; i++) {
        expect(ours[i].dot(derived[i].normalized()), greaterThan(0.9),
            reason: '$reason vertex $i: ${ours[i]} vs winding ${derived[i]}');
      }
    }

    const f = Finish(0.5, 0.5, 0.5);
    test('box, quad and cylinder triangles wind toward their normals', () {
      expectWindingMatchesNormals(
          [BoxPart(Vector3(-1, 0, 2), Vector3(0.5, 0.3, 2.2), f)], 'box');
      for (final n in [
        Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)
      ]) {
        expectWindingMatchesNormals(
            [QuadPart(Vector3(1, 2, 3), n, 0.8, 0.5, f)], 'quad $n');
      }
      expectWindingMatchesNormals([
        CylinderPart(Vector3(1, 0, 1), bottomRadius: 0.2, topRadius: 0.1, height: 0.3, finish: f)
      ], 'cylinder');
    });

    test('box normals point out of the box', () {
      final box = BoxPart(Vector3(-1, 0, 2), Vector3(0.5, 0.3, 2.2), f);
      final d = partsMeshData([box]);
      final ps = vecs(d.positions), ns = vecs(d.normals!);
      final c = box.bounds.center;
      for (var i = 0; i < ps.length; i++) {
        expect((ps[i] - c).dot(ns[i]), greaterThan(0));
      }
    });

    group('textured finishes', () {
      const tex = TextureRef('test', 0.5, 0.25);
      const textured = Finish(1, 1, 1, texture: tex);
      (double, double) span(List<double> uv, int axis) {
        final xs = [for (var i = axis; i < uv.length; i += 2) uv[i]];
        return (xs.reduce(math.min), xs.reduce(math.max));
      }

      test('a face repeats every texture-size metres: 2 m wide, 1 m tall', () {
        final q = QuadPart(Vector3(-3, 1, 2), Vector3(0, 0, 1), 2, 1, textured);
        final uv = partsMeshData([q]).texCoords!;
        final (u0, u1) = span(uv, 0);
        final (v0, v1) = span(uv, 1);
        expect(u1 - u0, closeTo(2 / 0.5, 1e-4));
        expect(v1 - v0, closeTo(1 / 0.25, 1e-4));
      });

      test('the same texture keeps its scale on a small part (no stretching)', () {
        final big = BoxPart(Vector3(0, 0, 0), Vector3(2, 0.1, 2), textured);
        final small = BoxPart(Vector3(0, 0, 0), Vector3(0.5, 0.1, 0.5), textured);
        // Top faces (the last 4 vertices of a box's 6 faces are the bottom).
        final (bu0, bu1) = span(partsMeshData([big]).texCoords!.sublist(32, 40), 0);
        final (su0, su1) = span(partsMeshData([small]).texCoords!.sublist(32, 40), 0);
        expect((bu1 - bu0) / (su1 - su0), closeTo(4, 1e-4));
      });

      test('a cylinder side wraps its circumference in metres', () {
        final c = CylinderPart(Vector3.zero(),
            bottomRadius: 0.1, topRadius: 0.1, height: 0.5, finish: textured);
        final uv = partsMeshData([c]).texCoords!;
        // Side vertices come first: 17 rings of 2.
        final (u0, u1) = span(uv.sublist(0, 68), 0);
        expect(u1 - u0, closeTo(2 * math.pi * 0.1 / 0.5, 1e-4));
      });

      test('untextured parts keep 0..1 UVs (screens, mirror, books)', () {
        final tv = QuadPart(Vector3(-6.7, 1.3, 2.68), Vector3(0, 0, 1), 1.2, 0.675, f);
        final uv = partsMeshData([tv]).texCoords!;
        expect(span(uv, 0), (0.0, 1.0));
        expect(span(uv, 1), (0.0, 1.0));
      });
    });

    test('room B screens still read left-to-right: u runs to the viewer\'s right', () {
      // Room B is room A under scale.x = −1. A texture mapped in room A's UVs
      // would show mirrored there (Task 24 binds a poster to tv_screen).
      final tv = QuadPart(Vector3(-6.7, 1.3, 2.68), Vector3(0, 0, 1), 1.2, 0.675, f);
      for (final mirrored in [false, true]) {
        final d = partsMeshData([tv], mirrored: mirrored);
        final ps = vecs(d.positions), uv = d.texCoords!;
        // World x of each vertex (room B negates x), and the face normal in
        // world space: +Z either way, so the viewer's right is n × up = −X.
        double worldX(int i) => mirrored ? -ps[i].x : ps[i].x;
        final byU = [for (var i = 0; i < ps.length; i++) (uv[i * 2], worldX(i))]
          ..sort((a, b) => a.$1.compareTo(b.$1));
        expect(byU.last.$2, lessThan(byU.first.$2),
            reason: mirrored ? 'room B' : 'room A');
      }
    });

    test('every node in the room winds its triangles toward its normals', () {
      for (final (n, _) in placed(room)) {
        if (n.parts.isNotEmpty) expectWindingMatchesNormals(n.parts, n.name);
      }
    });
  });
}
