import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/features/placeholder_rooms.dart';
import 'package:flutter_3d/math/floor_plan.dart';

/// World bounds (room A space) of every part under the node named [name].
List<Aabb3> boundsUnder(String name) {
  final out = <Aabb3>[];
  void walk(RoomNode n, Matrix4 parent, bool inside) {
    final m = parent * n.localTransform;
    final hit = inside || n.name == name;
    if (hit) {
      for (final p in n.parts) {
        out.add(Aabb3.copy(p.bounds)..transform(m));
      }
    }
    for (final c in n.children) {
      walk(c, m, hit);
    }
  }

  walk(roomASpec(), Matrix4.identity(), false);
  return out;
}

Aabb3 hull(List<Aabb3> boxes) =>
    boxes.skip(1).fold(Aabb3.copy(boxes.first), (a, b) => a..hull(b));

void main() {
  for (final name in ['reading_light_left', 'reading_light_right']) {
    test('$name hangs on the outer wall above the headboard', () {
      final parts = boundsUnder(name);
      expect(parts, isNotEmpty);
      final b = hull(parts);
      expect(b.min.x, greaterThanOrEqualTo(-FloorPlan.roomWidth - 1e-6), reason: 'not in the wall');
      expect(b.max.x, lessThan(-7.4), reason: 'behind the headboard (x = −7.4)');
      expect(b.min.y, greaterThan(1.3), reason: 'above the headboard (1.35 m) and heads');
      expect(b.max.y, lessThan(1.5), reason: 'below the art (from 1.5 m)');
    });
  }

  test('the fixtures clear the art, the bedside table and its lamp', () {
    final lights = [...boundsUnder('reading_light_left'), ...boundsUnder('reading_light_right')];
    for (final other in ['art_bed', 'bedside_table', 'lamp_bedside']) {
      for (final a in lights) {
        for (final b in boundsUnder(other)) {
          expect(a.intersectsWithAabb3(b), isFalse, reason: 'touches $other');
        }
      }
    }
  });

  test('each has a shade child for the spot feature to light', () {
    expect(boundsUnder('reading_light_shade'), hasLength(2));
  });
}
