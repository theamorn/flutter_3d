import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/math/floor_plan.dart';
import 'package:flutter_3d/math/fp_movement.dart';
import 'package:flutter_3d/math/occlusion.dart';

/// The main camera's cells from the eye at [xz] facing [yaw] (0 = +Z).
/// Aspect 1 (a 90° wide view): wider than the phone's portrait view, so
/// only the portals, not a narrow frustum, can hide things.
Map<Cell, List<PlaneSet>> view(double x, double z, double yaw,
    {bool doorOpen = false, double pitch = 0}) {
  final eye = Vector3(x, FloorPlan.eyeHeight, z);
  final camera = PerspectiveCamera(
    position: eye,
    target: eye + forwardOf(yaw, pitch),
    fovRadiansY: 90 * degrees2Radians,
    fovNear: 0.05,
    fovFar: 900,
  );
  return visibleCells(eye, cellOf(eye), frustumPlanes(camera.getFrustum(const Size(100, 100))),
      hotelPortals(connectingDoorOpen: doorOpen));
}

Aabb3 box(double x0, double y0, double z0, double x1, double y1, double z1) =>
    Aabb3.minMax(Vector3(x0, y0, z0), Vector3(x1, y1, z1));

/// Room A's bathroom mirror (see placeholder_rooms: quad at x = −7.99).
final Aabb3 mirrorA = box(-7.99, 1.1, 0.1, -7.99, 2.0, 1.0);
final Plane mirrorPlaneA = Plane.normalconstant(Vector3(1, 0, 0), 7.99);

/// The sea, as the ocean feature builds it.
final Aabb3 sea = box(-380, -90, 40, 380, -90, 800);

void main() {
  test('cells: bathroom corner, bedroom, balconies outdoors, B mirrored', () {
    expect(cellOf(Vector3(-6.8, 1.6, 0.55)), Cell.bathA);
    expect(cellOf(Vector3(-4, 1.6, 3)), Cell.roomA);
    expect(cellOf(Vector3(-6.8, 1.6, 4)), Cell.roomA);
    expect(cellOf(Vector3(-3, 1.6, 7.3)), Cell.outdoors);
    expect(cellOf(Vector3(6.8, 1.6, 0.55)), Cell.bathB);
    expect(cellOf(Vector3(4, 1.6, 3)), Cell.roomB);
  });

  test('content sits in one cell; anything spanning a wall is structure', () {
    expect(cellContaining(box(-8, 0, 0, -5.26, 2.4, 2.6)), Cell.bathA); // cladding
    expect(cellContaining(mirrorA), Cell.bathA);
    expect(cellContaining(box(-7.4, 0, 3.2, -5.4, 1.35, 5.4)), Cell.roomA); // bed
    expect(cellContaining(box(-5.2, 1.14, 2.1, -5.19, 1.26, 2.2)), Cell.roomA); // bath switch
    expect(cellContaining(box(5.4, 0, 3.2, 7.4, 1.35, 5.4)), Cell.roomB); // B's bed
    expect(cellContaining(box(-8.12, -0.1, -0.12, 0, 2.8, 7.92)), isNull); // walls
    expect(cellContaining(box(-4.4, 0, 6.06, -1.6, 2.4, 6.06)), isNull); // window glass
    // A rug reaching under the bathroom wall.
    expect(cellContaining(box(-7, 0, 2, -4, 0.01, 4)), isNull);
  });

  test('portal planes hold the portal and drop what is behind the eye', () {
    final eye = Vector3(-3, 1.6, 1.5);
    final rect = hotelPortals(connectingDoorOpen: false).first.corners;
    final planes = portalPlanes(eye, rect);
    expect(planes, hasLength(4));
    final center = (rect[0] + rect[2])..scale(0.5);
    for (final p in planes) {
      expect(p.distanceToVector3(center), greaterThan(0));
    }
    // Straight through the doorway and on: inside. Behind the eye: out.
    final beyond = eye + (center - eye) * 3;
    expect(aabbInside(Aabb3.minMax(beyond, beyond), planes), isTrue);
    final behind = eye - (center - eye);
    expect(aabbInside(Aabb3.minMax(behind, behind), planes), isFalse);
  });

  test('facing the TV wall: the bathroom behind it is hidden', () {
    final cells = view(-6.7, 3.8, math.pi); // the tour's TV stop
    expect(cells.keys, isNot(contains(Cell.bathA)));
    expect(seen(cells, Cell.bathA, mirrorA), isFalse);
    expect(seen(cells, Cell.roomA, box(-7.33, 0.93, 2.66, -6.07, 1.67, 2.68)), isTrue); // TV
  });

  test('facing the bathroom door: only what lines up with the doorway', () {
    final cells = view(-3, 1.5, -math.pi / 2);
    expect(cells.keys, contains(Cell.bathA));
    // The shower glass is straight through the door; the towels, tucked in
    // the corner by the corridor wall, are not.
    expect(seen(cells, Cell.bathA, box(-6.41, 0, 0.8, -6.39, 2, 1.1)), isTrue);
    expect(seen(cells, Cell.bathA, box(-7.92, 0.85, 0.04, -7.62, 1.0, 0.26)), isFalse);
  });

  test('sideways to the sea: the side wall hides it, the window shows it', () {
    expect(seen(view(-3, 3.5, math.pi / 2), Cell.outdoors, sea), isFalse);
    expect(seen(view(-4, 3.5, -math.pi / 2), Cell.outdoors, sea), isFalse);
    expect(seen(view(-4, 4.8, 0), Cell.outdoors, sea), isTrue);
    // From the balcony the sea is just the frustum's business.
    expect(seen(view(-3, 7.3, 0, pitch: -0.8), Cell.outdoors, sea), isTrue);
  });

  test('the far room is reached only through the open connecting door', () {
    final bedB = box(5.4, 0, 3.2, 7.4, 1.35, 5.4);
    expect(view(-1.5, 2.45, math.pi / 2).keys, isNot(contains(Cell.roomB)));
    final open = view(-1.5, 2.45, math.pi / 2, doorOpen: true);
    expect(open.keys, contains(Cell.roomB));
    // Looking away from the open door: room B stays hidden.
    expect(view(-1.5, 2.45, -math.pi / 2, doorOpen: true).keys, isNot(contains(Cell.roomB)));
    expect(seen(open, Cell.roomB, bedB), isTrue); // its foot lines up with the door
    expect(seen(open, Cell.roomB, box(3, 0, 0, 4.6, 1.24, 0.6)), isFalse); // B's desk, off to the side
  });

  test('standing in a doorway, the doorway does not narrow the view', () {
    // In the doorway's plane, facing into the bathroom: the opening is
    // behind the near plane, yet the whole bathroom is in view.
    final cells = view(kBathPortalX, 1.6, -math.pi / 2);
    expect(cells.keys, containsAll([Cell.bathA, Cell.roomA]));
    // The towels, far off to the side of the opening.
    expect(seen(cells, Cell.bathA, box(-7.92, 0.85, 0.04, -7.62, 1.0, 0.26)), isTrue);
  });

  test('a mirror sees its room and, through the doorway, the bedroom', () {
    final eye = Vector3(-6.8, FloorPlan.eyeHeight, 0.55);
    final portals = hotelPortals(connectingDoorOpen: false);
    final cells = mirrorCells(eye, mirrorPlaneA, mirrorA, portals)!;
    expect(cells.keys, containsAll([Cell.bathA, Cell.roomA]));
    // The shower glass behind the viewer shows in the glass.
    expect(seen(cells, Cell.bathA, box(-6.41, 0, 0, -6.39, 2, 1.1)), isTrue);
    // Nothing behind the mirror's own wall.
    expect(seen(cells, Cell.bathA, box(-8.5, 1, 0.3, -8.2, 2, 0.8)), isFalse);
    // Behind the glass there's no reflection to see.
    expect(mirrorCells(Vector3(-8.5, 1.6, 0.5), mirrorPlaneA, mirrorA, portals), isNull);
  });
}
