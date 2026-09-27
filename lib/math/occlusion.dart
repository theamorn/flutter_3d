import 'package:vector_math/vector_math.dart';
import '../features/placeholder_rooms.dart' show windowX0, windowX1;
import 'floor_plan.dart';

/// Cells-and-portals occlusion for the two rooms. flutter_scene only frustum
/// culls, so a bed behind the bathroom wall or the sea behind the side wall
/// is drawn whenever it's in front of the camera. Here the walls split the
/// world into cells joined by portals (doorways, windows), and a cell is
/// seen only through the chain of portals that leads to it: its view is the
/// camera frustum narrowed by the planes through the eye and each portal's
/// edges. Pure maths, GPU-free.

/// Where the eye can stand, and where content lives.
enum Cell { bathA, roomA, bathB, roomB, outdoors }

/// Inside iff `normal · p + constant ≥ 0`, as vector_math's [Frustum] and
/// flutter_scene's `RenderView.cullingPlanes`.
typedef PlaneSet = List<Plane>;

/// The planes of the wall openings, on each wall's mid-plane (any ray through
/// a thick doorway crosses its mid-plane inside the opening, so the
/// mid-plane rectangle over-covers the tunnel: conservative).
const double kBathPortalX = FloorPlan.bathX1 - 0.03;
const double kWindowPortalZ = FloorPlan.roomDepth + FloorPlan.wallT / 2;

/// Openings are treated as full-height: slightly generous, never too tight.
const double _top = FloorPlan.ceiling;

/// An eye this close to a portal's plane (and over its opening) sees
/// through it at any angle, so the portal doesn't narrow the view. More than
/// the walker's radius, so standing in a doorway is covered.
const double kPortalNearDistance = 0.35;

/// A rectangle between two cells.
class Portal {
  /// [insideA] is any point on [a]'s side of the rectangle's plane.
  Portal(this.corners, this.a, this.b, {required Vector3 insideA})
      : assert(corners.length == 4),
        plane = _facing(corners, insideA);

  /// In order around the rectangle.
  final List<Vector3> corners;
  final Cell a, b;

  /// The rectangle's plane, [a]'s side positive.
  final Plane plane;

  static Plane _facing(List<Vector3> c, Vector3 insideA) {
    final n = (c[1] - c[0]).cross(c[3] - c[0])..normalize();
    final plane = Plane.normalconstant(n, -n.dot(c[0]));
    return plane.distanceToVector3(insideA) >= 0 ? plane : Plane.normalconstant(-n, n.dot(c[0]));
  }

  /// Whether [p] is on [cell]'s side of the plane.
  bool onSideOf(Cell cell, Vector3 p) => (plane.distanceToVector3(p) > 0) == (cell == a);
}

Vector3 _mx(Vector3 v) => Vector3(-v.x, v.y, v.z);

Portal _mirrored(Portal p, Cell a, Cell b, Vector3 insideA) =>
    Portal([for (final c in p.corners) _mx(c)], a, b, insideA: _mx(insideA));

/// A rectangle in the plane x = [x] spanning [z0, z1] × [y0, y1].
List<Vector3> _xRect(double x, double z0, double z1, double y0, double y1) =>
    [Vector3(x, y0, z0), Vector3(x, y0, z1), Vector3(x, y1, z1), Vector3(x, y1, z0)];

/// A rectangle in the plane z = [z] spanning [x0, x1] × [y0, y1].
List<Vector3> _zRect(double z, double x0, double x1, double y0, double y1) =>
    [Vector3(x0, y0, z), Vector3(x1, y0, z), Vector3(x1, y1, z), Vector3(x0, y1, z)];

/// Every open portal. The connecting door counts while its leaf is off the
/// frame ([connectingDoorOpen]); the entrance door never opens onto
/// anything.
List<Portal> hotelPortals({required bool connectingDoorOpen}) {
  final inBath = Vector3(-FloorPlan.roomWidth, 0, 0), inRoom = Vector3(-1, 0, 1);
  final bathA = Portal(_xRect(kBathPortalX, FloorPlan.bathDoorZ0, FloorPlan.bathDoorZ1, 0, _top),
      Cell.bathA, Cell.roomA, insideA: inBath);
  final windowA = Portal(_zRect(kWindowPortalZ, windowX0, windowX1, 0, _top), Cell.roomA, Cell.outdoors,
      insideA: inRoom);
  return [
    bathA,
    windowA,
    _mirrored(bathA, Cell.bathB, Cell.roomB, inBath),
    _mirrored(windowA, Cell.roomB, Cell.outdoors, inRoom),
    if (connectingDoorOpen)
      Portal(_xRect(0, FloorPlan.doorZ0, FloorPlan.doorZ1, 0, _top), Cell.roomA, Cell.roomB,
          insideA: inRoom),
  ];
}

/// The cell holding [p]: past the window wall is outdoors (the balconies are
/// open air), the bathroom corner is its own cell, the rest is the room.
Cell cellOf(Vector3 p) {
  if (p.z > kWindowPortalZ) return Cell.outdoors;
  final roomA = p.x < 0;
  final x = roomA ? p.x : -p.x;
  final bath = x < kBathPortalX && p.z < FloorPlan.bathZ1 + 0.03;
  return roomA ? (bath ? Cell.bathA : Cell.roomA) : (bath ? Cell.bathB : Cell.roomB);
}

/// Room A's or room B's cells.
bool isRoomACell(Cell c) => c == Cell.bathA || c == Cell.roomA;
bool isRoomBCell(Cell c) => c == Cell.bathB || c == Cell.roomB;

/// The cell [box] lies wholly inside (to [slack]), or null when it spans a
/// wall (structure: walls, floor, ceiling, trim, window glass).
Cell? cellContaining(Aabb3 box, {double slack = 0.05}) {
  final cell = cellOf(box.center);
  if (cell == Cell.outdoors) return null;
  final roomA = isRoomACell(cell);
  // Room A's frame: mirror room B's box in x.
  final minX = roomA ? box.min.x : -box.max.x, maxX = roomA ? box.max.x : -box.min.x;
  const bathZ = FloorPlan.bathZ1 + 0.03;
  final bath = cell == Cell.bathA || cell == Cell.bathB;
  final x1 = bath ? kBathPortalX : 0.0, z1 = bath ? bathZ : FloorPlan.roomDepth;
  final inside = minX >= -FloorPlan.roomWidth - slack &&
      maxX <= x1 + slack &&
      box.min.z >= -slack &&
      box.max.z <= z1 + slack;
  // The bedroom is an L around the bathroom: a box reaching into the
  // bathroom's corner spans its walls.
  if (inside && !bath && minX < kBathPortalX - slack && box.min.z < bathZ - slack) return null;
  return inside ? cell : null;
}

/// The [Frustum]'s six planes.
PlaneSet frustumPlanes(Frustum f) =>
    [f.plane0, f.plane1, f.plane2, f.plane3, f.plane4, f.plane5];

/// Whether [box] is outside none of [planes].
bool aabbInside(Aabb3 box, PlaneSet planes) {
  for (final p in planes) {
    final n = p.normal;
    // The box corner furthest along the normal.
    final x = n.x >= 0 ? box.max.x : box.min.x;
    final y = n.y >= 0 ? box.max.y : box.min.y;
    final z = n.z >= 0 ? box.max.z : box.min.z;
    if (n.x * x + n.y * y + n.z * z + p.constant < 0) return false;
  }
  return true;
}

bool _polygonInside(List<Vector3> corners, PlaneSet planes) {
  for (final p in planes) {
    if (corners.every((c) => p.distanceToVector3(c) < 0)) return false;
  }
  return true;
}

/// The four planes through [eye] and each edge of [rect], facing into the
/// pyramid that looks through it. Empty when [eye] lies in the rectangle's
/// plane.
PlaneSet portalPlanes(Vector3 eye, List<Vector3> rect) {
  final center = (rect[0] + rect[1] + rect[2] + rect[3])..scale(0.25);
  final out = <Plane>[];
  for (var i = 0; i < 4; i++) {
    final a = rect[i] - eye, b = rect[(i + 1) % 4] - eye;
    final n = a.cross(b);
    if (n.length2 < 1e-12) return const [];
    n.normalize();
    var plane = Plane.normalconstant(n, -n.dot(eye));
    if (plane.distanceToVector3(center) < 0) {
      plane = Plane.normalconstant(-n, n.dot(eye));
    }
    out.add(plane);
  }
  return out;
}

/// Whether [eye] is so close to [portal] that it doesn't narrow the view.
bool _nearPortal(Vector3 eye, Portal portal) {
  final c = portal.corners;
  final u = c[1] - c[0], v = c[3] - c[0];
  if (portal.plane.distanceToVector3(eye).abs() > kPortalNearDistance) return false;
  final du = (eye - c[0]).dot(u) / u.length, dv = (eye - c[0]).dot(v) / v.length;
  return du > -kPortalNearDistance &&
      du < u.length + kPortalNearDistance &&
      dv > -kPortalNearDistance &&
      dv < v.length + kPortalNearDistance;
}

/// The plane sets through which [eye], standing in [start] and seeing
/// [view], sees each cell: [start] through [view] itself, every other cell
/// through [view] narrowed by each portal on the way. A cell that isn't a
/// key is hidden. A portal is only seen through from its own cell's side
/// (the bathroom door, round the corner from the bed, faces away). An eye
/// in a doorway passes it unnarrowed, even though the opening itself is
/// then behind the near plane. Paths never reuse a portal, and stop after
/// [maxDepth] portals.
Map<Cell, List<PlaneSet>> visibleCells(
  Vector3 eye,
  Cell start,
  PlaneSet view,
  List<Portal> portals, {
  int maxDepth = 4,
}) {
  final out = <Cell, List<PlaneSet>>{};
  void visit(Cell cell, PlaneSet planes, List<Portal> path) {
    (out[cell] ??= []).add(planes);
    if (path.length >= maxDepth) return;
    for (final p in portals) {
      if (path.contains(p) || (p.a != cell && p.b != cell)) continue;
      final next = p.a == cell ? p.b : p.a;
      if (_nearPortal(eye, p)) {
        visit(next, planes, [...path, p]);
      } else if (p.onSideOf(cell, eye) && _polygonInside(p.corners, planes)) {
        visit(next, [...planes, ...portalPlanes(eye, p.corners)], [...path, p]);
      }
    }
  }

  visit(start, view, const []);
  return out;
}

/// Whether [box], in [cell], is seen through any of [cells]' plane sets.
bool seen(Map<Cell, List<PlaneSet>> cells, Cell cell, Aabb3 box) =>
    cells[cell]?.any((planes) => aabbInside(box, planes)) ?? false;

/// [p] mirrored across [plane] (unit normal).
Vector3 reflectAcross(Vector3 p, Plane plane) =>
    p - plane.normal * (2 * plane.distanceToVector3(p));

/// What a planar mirror shows: the cells its reflected camera sees through
/// the mirror's rectangle ([mirrorBox], flat along [plane]'s normal), only
/// in front of the glass. Null when [eye] is behind the mirror.
Map<Cell, List<PlaneSet>>? mirrorCells(
    Vector3 eye, Plane plane, Aabb3 mirrorBox, List<Portal> portals) {
  if (plane.distanceToVector3(eye) <= 0) return null;
  final rect = _flatRect(mirrorBox, plane.normal);
  final reflected = reflectAcross(eye, plane);
  final cone = portalPlanes(reflected, rect);
  if (cone.isEmpty) return null;
  return visibleCells(reflected, cellOf(mirrorBox.center), [...cone, plane], portals);
}

/// [box]'s face across its thinnest axis ([normal]'s dominant one).
List<Vector3> _flatRect(Aabb3 box, Vector3 normal) {
  final ax = normal.x.abs(), ay = normal.y.abs(), az = normal.z.abs();
  final c = box.center, lo = box.min, hi = box.max;
  if (ax >= ay && ax >= az) return _xRect(c.x, lo.z, hi.z, lo.y, hi.y);
  if (az >= ay) return _zRect(c.z, lo.x, hi.x, lo.y, hi.y);
  return [Vector3(lo.x, c.y, lo.z), Vector3(hi.x, c.y, lo.z), Vector3(hi.x, c.y, hi.z), Vector3(lo.x, c.y, hi.z)];
}

/// Merges [more] into [into].
void addCells(Map<Cell, List<PlaneSet>> into, Map<Cell, List<PlaneSet>> more) {
  for (final MapEntry(key: cell, value: sets) in more.entries) {
    (into[cell] ??= []).addAll(sets);
  }
}
