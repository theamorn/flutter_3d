import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/features/placeholder_rooms.dart';
import 'package:flutter_3d/features/spot_lights_feature.dart';
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

/// World positions (room A space) of every node named [name].
List<Vector3> originsOf(String name) {
  final out = <Vector3>[];
  void walk(RoomNode n, Matrix4 parent) {
    final m = parent * n.localTransform;
    if (n.name == name) out.add(m.getTranslation());
    for (final c in n.children) {
      walk(c, m);
    }
  }

  walk(roomASpec(), Matrix4.identity());
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
      expect(b.max.x, lessThan(-7.4), reason: 'clear of the bed (x = −7.4)');
      expect(b.min.y, greaterThan(1.35), reason: 'above the headboard (1.35 m)');
      expect(b.max.y, lessThan(FloorPlan.ceiling - 0.08), reason: 'below the crown moulding');
    });
  }

  test("each reading light's beam clears the headboard onto the pillows", () {
    // The headboard stands 0.6 m off the wall (x −7.4 .. −7.27, 1.35 m
    // tall); the pillows in front of it top out at about 0.75 m.
    const headboardTop = 1.35, pillowTop = 0.75;
    final aim = readingLightAim();
    final fixtures = [...originsOf('reading_light_left'), ...originsOf('reading_light_right')];
    expect(fixtures, hasLength(2));
    for (final fixture in fixtures) {
      final source = fixture + kReadingLightSourceAt;
      for (final x in [-7.4, -7.27]) {
        final y = source.y + aim.y * (x - source.x) / aim.x;
        expect(y, greaterThan(headboardTop + 0.1), reason: 'the beam passes over the headboard at x = $x');
      }
      final hit = source + aim * ((pillowTop - source.y) / aim.y);
      expect(hit.x, inInclusiveRange(-7.25, -6.6), reason: 'the beam lands on the pillows');
    }
  });

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
