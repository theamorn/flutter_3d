import 'dart:math' as math;

import 'package:flutter_3d/features/placeholder_rooms.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

List<Part> bedParts() {
  RoomNode? bed;
  void visit(RoomNode node) {
    if (node.name == 'bed') bed = node;
    for (final child in node.children) {
      visit(child);
    }
  }

  visit(roomASpec());
  return bed!.parts;
}

Vector3 vertex(List<double> values, int i) =>
    Vector3(values[3 * i], values[3 * i + 1], values[3 * i + 2]);

void main() {
  test('pillows have curved surfaces instead of six flat box faces', () {
    final pillows = bedParts().where(
      (p) =>
          p.finish.texture?.id == 'quatrefoil_jacquard_fabric' ||
          (p.finish.texture?.id == 'rough_linen' && p.bounds.min.y >= .549),
    );
    expect(pillows.length, greaterThanOrEqualTo(4));
    for (final pillow in pillows) {
      final data = partsMeshData([pillow]);
      final curved = [
        for (var i = 0; i < data.vertexCount; i++)
          if (vertex(
                data.normals!,
                i,
              ).storage.map((n) => n.abs()).reduce(math.max) <
              .98)
            i,
      ];
      expect(curved.length, greaterThan(data.vertexCount ~/ 3));
    }
  });

  test('the foot blanket drapes below the mattress with soft top folds', () {
    final throwPart = bedParts().singleWhere(
      (p) => p.finish.texture?.id == 'poly_wool_herringbone',
    );
    final data = partsMeshData([throwPart]);
    final positions = [
      for (var i = 0; i < data.vertexCount; i++) vertex(data.positions, i),
    ];
    expect(positions.map((p) => p.y).reduce(math.min), lessThan(.48));
    expect(
      positions.map((p) => p.y).reduce(math.min),
      greaterThan(.3),
      reason: 'the hem must stay above the wooden frame',
    );
    // Only the upward-facing fabric over the flat mattress, excluding
    // the rolled sides, head hem and underside.
    final topHeights = [
      for (var i = 0; i < positions.length; i++)
        if (vertex(data.normals!, i).y > .9 &&
            positions[i].x > -5.94 &&
            positions[i].x < -5.62 &&
            positions[i].z > 3.55 &&
            positions[i].z < 5.05)
          positions[i].y,
    ];
    expect(topHeights, isNotEmpty);
    expect(
      topHeights.reduce(math.max) - topHeights.reduce(math.min),
      greaterThan(.015),
    );
  });

  test(
    'bedding meshes have finite UVs and outward non-degenerate triangles',
    () {
      final bedding = bedParts().where(
        (p) => [
          'rough_linen',
          'quatrefoil_jacquard_fabric',
          'poly_wool_herringbone',
        ].contains(p.finish.texture?.id),
      );
      for (final part in bedding) {
        final MeshData data = partsMeshData([part]);
        expect(data.texCoords!.length, data.vertexCount * 2);
        expect(data.texCoords!.every((v) => v.isFinite), isTrue);
        final ids = data.indices!;
        for (var i = 0; i < ids.length; i += 3) {
          final a = vertex(data.positions, ids[i]);
          final b = vertex(data.positions, ids[i + 1]);
          final c = vertex(data.positions, ids[i + 2]);
          final face = (b - a).cross(c - a);
          expect(face.length, greaterThan(1e-9));
          final normal =
              vertex(data.normals!, ids[i]) +
              vertex(data.normals!, ids[i + 1]) +
              vertex(data.normals!, ids[i + 2]);
          expect(
            face.dot(normal),
            greaterThan(0),
            reason: '${part.finish.texture?.id} triangle ${i ~/ 3}: $a, $b, $c',
          );
        }
        for (var i = 0; i < data.vertexCount; i++) {
          expect(vertex(data.normals!, i).length, closeTo(1, 1e-4));
        }
        final mirrored = partsMeshData([part], mirrored: true);
        expect(mirrored.positions, data.positions);
        for (var i = 0; i < data.vertexCount; i++) {
          expect(
            mirrored.texCoords![i * 2],
            closeTo(1 - data.texCoords![i * 2], 1e-5),
          );
        }
      }
    },
  );
}
