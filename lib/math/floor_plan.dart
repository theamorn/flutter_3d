import 'package:vector_math/vector_math.dart';
import 'colliders.dart';

enum RoomId { a, b }

/// The two mirrored family rooms, in metres. Room A is authored in
/// x ∈ [−8, 0]; room B is its mirror in x. +Z points toward the ocean.
class FloorPlan {
  static const double roomWidth = 8,
      roomDepth = 6,
      balconyDepth = 1.8,
      ceiling = 2.8,
      eyeHeight = 1.6,
      wallT = 0.12;

  /// Connecting door span on x = 0.
  static const double doorZ0 = 2.0, doorZ1 = 2.9;

  /// Bathroom box corner (room A): x ∈ [−8, bathX1], z ∈ [0, bathZ1].
  static const double bathX1 = -5.2, bathZ1 = 2.6;
  static const double bathDoorZ0 = 1.2, bathDoorZ1 = 2.0;

  /// Room entrance door span on the corridor wall (z = 0), room A.
  static const double entranceX0 = -2.3, entranceX1 = -1.3;

  static RoomId roomOf(Vector2 xz) => xz.x < 0 ? RoomId.a : RoomId.b;

  static Vector2 mirror(Vector2 xz) => Vector2(-xz.x, xz.y);

  /// Room A furniture footprints (Task 9 builds placeholder meshes from these).
  static const Map<String, Box2> furnitureA = {
    'bed': Box2(-7.4, 3.2, -5.4, 5.4),
    'sofa': Box2(-2.6, 3.6, -0.8, 4.4),
    'desk': Box2(-4.6, 0.0, -3.0, 0.6),
    'tv_unit': Box2(-7.6, 2.66, -5.8, 2.9), // against the bathroom wall, facing the bed
    'shelf': Box2(-1.2, 0.0, -0.5, 0.4), // clear of the entrance door (x ∈ [−2.3, −1.3])
    'basin': Box2(-8.0, 0.0, -7.4, 1.0),
    'shower': Box2(-6.4, 0.0, -5.2, 1.1),
  };

  static const double _depth = roomDepth; // window wall at z = 6
  static const double _rail = roomDepth + balconyDepth; // railing at z = 7.8

  /// Room A walls, excluding the shared wall on x = 0. Task 9 builds the
  /// visible walls from these same boxes, so what you see is what you hit.
  static const List<Box2> wallsA = [
    Box2(-roomWidth - wallT, -wallT, 0, 0), // corridor wall
    Box2(-roomWidth - wallT, -wallT, -roomWidth, _rail + wallT), // outer side wall
    // Window wall, with a 1.2 m balcony-door gap at x ∈ [−3.6, −2.4].
    Box2(-roomWidth, _depth, -3.6, _depth + wallT),
    Box2(-2.4, _depth, 0, _depth + wallT),
    Box2(-roomWidth, _rail, 0, _rail + wallT), // balcony railing
    Box2(-wallT / 2, _depth, 0, _rail), // balcony divider
    // Bathroom: side wall with the door gap, then the wall along z = 2.6.
    Box2(bathX1 - 0.06, 0, bathX1, bathDoorZ0),
    Box2(bathX1 - 0.06, bathDoorZ1, bathX1, bathZ1 + 0.06),
    Box2(-roomWidth, bathZ1, bathX1, bathZ1 + 0.06),
  ];

  /// The shared wall, symmetric about x = 0, with the connecting-door gap.
  static const List<Box2> sharedWall = [
    Box2(-wallT / 2, 0, wallT / 2, doorZ0),
    Box2(-wallT / 2, doorZ1, wallT / 2, _depth),
  ];

  /// Static wall + furniture boxes for BOTH rooms (room B = mirror of A),
  /// with the connecting-door gap left open. The door leaf is dynamic (Task 17).
  static List<Box2> staticColliders() {
    final a = [...wallsA, ...furnitureA.values];
    return [...a, ...a.map((b) => b.mirrored()), ...sharedWall];
  }
}
