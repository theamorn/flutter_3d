import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

/// A sewn cushion: two inflated faces meet in a narrow, rounded rim.
/// UVs measure the fabric in metres, including on the upright cushions.
MeshData pillowMesh({
  required Vector3 center,
  required double length,
  required double width,
  required double thickness,
  required Vector2 textureSize,
  bool upright = false,
  double phase = 0,
}) {
  return _clothShell(
    columns: 24,
    rows: 28,
    textureSize: textureSize,
    surface: (s, t, underside) {
      final u = 2 * s - 1, v = 2 * t - 1;
      // Pull in the corners; a cushion retains a rectangular silhouette.
      final x = u * length / 2 * (1 - .12 * math.pow(v.abs(), 8));
      final z = v * width / 2 * (1 - .12 * math.pow(u.abs(), 8));
      final fullness = math.pow((1 - u * u) * (1 - v * v), .48);
      final edge = math.max(u.abs(), v.abs());
      final gathers =
          .004 *
          math.sin(24 * u + 9 * v + phase) *
          math.sin(17 * v - 5 * u) *
          math.pow(edge, 5) *
          fullness;
      final h = .003 + (thickness / 2 - .003) * fullness + gathers;
      final face = underside ? -h : h;
      final p = upright
          // Rotate about Z with positive determinant, then lean toward
          // the headboard. Thus triangle winding also works in room B.
          ? Vector3(face + u * .055, -x, z)
          : Vector3(x, face, z);
      return (center + p, Vector2(s * length, t * width));
    },
  );
}

/// A blanket resting on a mattress, rolling over its sides and foot.
/// The parameter domain follows the cloth around the roll so the weave
/// keeps its scale on the hanging panels instead of stretching vertically.
MeshData blanketMesh({
  required double headX,
  required double footX,
  required double minZ,
  required double maxZ,
  required double height,
  required Vector2 textureSize,
  double hanging = .15,
  double thickness = .016,
}) {
  const radius = .06;
  final halfWidth = (maxZ - minZ) / 2;
  final centerZ = (minZ + maxZ) / 2;
  final rollLength = radius * math.pi / 2;
  final length = footX - headX + rollLength + hanging;
  final width = 2 * (halfWidth + rollLength + hanging);

  (double, double) drape(double distance, double support) {
    if (distance <= support) return (distance, 0);
    final beyond = distance - support;
    if (beyond <= rollLength) {
      final angle = beyond / radius;
      return (
        support + radius * math.sin(angle),
        radius * (1 - math.cos(angle)),
      );
    }
    final tail = beyond - rollLength;
    // Slight flare avoids coincident vertical vertices at draped corners.
    return (support + radius + .008 * tail / hanging, radius + tail);
  }

  Vector3 position(double s, double t, bool underside) {
    final along = s * length;
    final across = (t - .5) * width;
    final (x, dropX) = drape(along, footX - headX);
    final (z, dropZ) = drape(across.abs(), halfWidth);
    final worldX = headX + x, worldZ = centerZ + across.sign * z;
    // Blend the side and foot smoothly around corners, with less drop
    // than summing both panels (which would bury the hem in the frame).
    final drop = math
        .pow(math.pow(dropX, 4) + math.pow(dropZ, 4), .25)
        .toDouble();
    final hangingWeight = (drop / .15).clamp(0.0, 1.0);
    // Crossed, unequal wavelengths read as settled folds, not corrugation.
    final folds =
        .009 * math.sin(worldX * 13 + worldZ * 5) +
        .006 * math.sin(worldZ * 17 - worldX * 7) +
        .003 * math.sin(worldZ * 31 + worldX * 19);
    final turnedEdge = .018 * math.exp(-math.pow((along - .065) / .045, 2));
    final ripple = .007 * hangingWeight * math.sin(along * 24 + across * 9);
    // Follow the support's roll, rather than each small wrinkle, when
    // thickening the cloth. This keeps the underside from crossing itself
    // at tightly gathered corners and separates the vertical hanging faces.
    final angleX = ((along - (footX - headX)) / radius).clamp(0.0, math.pi / 2);
    final angleZ = ((across.abs() - halfWidth) / radius).clamp(
      0.0,
      math.pi / 2,
    );
    final inset = underside ? thickness : 0.0;
    return Vector3(
      worldX - inset * math.sin(angleX),
      height -
          drop +
          folds +
          turnedEdge +
          ripple -
          inset * math.cos(math.max(angleX, angleZ)),
      worldZ - across.sign * inset * math.sin(angleZ),
    );
  }

  return _clothShell(
    columns: 32,
    rows: 64,
    textureSize: textureSize,
    surface: (s, t, underside) {
      return (position(s, t, underside), Vector2(s * length, (t - .5) * width));
    },
  );
}

/// Closed shell with smooth faces and a separate normal domain on the sewn
/// rim. Built once when rooms mount; no cloth updates in the frame loop.
MeshData _clothShell({
  required int columns,
  required int rows,
  required Vector2 textureSize,
  required (Vector3, Vector2) Function(double, double, bool) surface,
}) {
  final positions = <double>[], uvs = <double>[];
  final indices = <int>[];
  final stride = columns + 1;
  final faceCount = stride * (rows + 1);
  for (final underside in [false, true]) {
    for (var row = 0; row <= rows; row++) {
      for (var col = 0; col <= columns; col++) {
        final (p, uv) = surface(col / columns, row / rows, underside);
        positions.addAll([p.x, p.y, p.z]);
        uvs.addAll([uv.x / textureSize.x, uv.y / textureSize.y]);
      }
    }
    final offset = underside ? faceCount : 0;
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < columns; col++) {
        final a = offset + row * stride + col, b = a + 1;
        final c = a + stride, d = c + 1;
        // The other diagonal at these corners connects three rim vertices
        // and creates a folded sliver on a pinched cushion.
        final corner =
            (row == 0 && col == 0) || (row == rows - 1 && col == columns - 1);
        final triangles = corner ? [a, c, d, a, d, b] : [a, c, b, b, c, d];
        for (var i = 0; i < triangles.length; i += 3) {
          indices.addAll(
            underside
                ? [triangles[i], triangles[i + 2], triangles[i + 1]]
                : triangles.sublist(i, i + 3),
          );
        }
      }
    }
  }
  final rim = [
    for (var col = 0; col <= columns; col++) col,
    for (var row = 1; row <= rows; row++) row * stride + columns,
    for (var col = columns - 1; col >= 0; col--) rows * stride + col,
    for (var row = rows - 1; row > 0; row--) row * stride,
  ];
  // Keep the narrow seam's normals separate from the opposing face
  // normals, which would cancel on sharply turned, millimetre-thick hems.
  final rimStart = positions.length ~/ 3;
  for (final index in rim) {
    for (final source in [index, index + faceCount]) {
      positions.addAll(positions.sublist(source * 3, source * 3 + 3));
      uvs.addAll(uvs.sublist(source * 2, source * 2 + 2));
    }
  }
  for (var i = 0; i < rim.length; i++) {
    final a = rimStart + 2 * i;
    final b = rimStart + 2 * ((i + 1) % rim.length);
    indices.addAll([a, b, a + 1, b, b + 1, a + 1]);
  }
  return MeshData.build(
    positions: Float32List.fromList(positions),
    texCoords: Float32List.fromList(uvs),
    indices: indices,
  );
}
