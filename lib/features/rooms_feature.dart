import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import '../math/floor_plan.dart';
import 'placeholder_rooms.dart';

/// The two family rooms. Room B is Room A under a scale.x = −1 parent; the
/// engine flips winding for the negative determinant (engine rule 6).
class RoomsFeature extends HotelFeature {
  @override
  String get id => 'rooms';
  @override
  String get label => 'Rooms';
  @override
  CostTier get tier => CostTier.free;
  @override
  bool get toggleable => false;

  @override
  Future<void> mount(HotelContext ctx) async {
    final a = buildRoomA()..name = 'room_a';
    final b = Node(name: 'room_b', localTransform: Matrix4.diagonal3Values(-1, 1, 1))
      ..add(buildRoomA(mirrored: true));
    ctx.scene.add(a);
    ctx.scene.add(b);
    ctx.rooms[RoomId.a] = a;
    ctx.rooms[RoomId.b] = b;
    // One shared connecting door: hide room B's mirrored copy of the leaf.
    ctx.nodesNamed('door_connect').last.visible = false;
  }

  @override
  void unmount(HotelContext ctx) {
    for (final room in ctx.rooms.values) {
      ctx.scene.remove(room);
    }
    ctx.rooms.clear();
  }
}
