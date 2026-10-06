import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import '../math/floor_plan.dart';
import 'placeholder_rooms.dart';
import 'room_textures.dart';

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
    final textures = await RoomTextures.load(textureRefs(roomASpec()));
    final bedding = <BeddingMaterialTarget>[];
    final a = buildRoomA(textures: textures, bedding: bedding)..name = 'room_a';
    final b = Node(name: 'room_b', localTransform: Matrix4.diagonal3Values(-1, 1, 1))
      ..add(buildRoomA(mirrored: true, textures: textures, bedding: bedding));
    ctx.scene.add(a);
    ctx.scene.add(b);
    ctx.rooms[RoomId.a] = a;
    ctx.rooms[RoomId.b] = b;
    ctx.beddingTargets = bedding;
    // One shared connecting door: hide room B's mirrored copy of the leaf.
    ctx.nodesNamed('door_connect').last.visible = false;
  }

  @override
  void unmount(HotelContext ctx) {
    for (final room in ctx.rooms.values) {
      ctx.scene.remove(room);
    }
    ctx.rooms.clear();
    ctx.beddingTargets = const [];
  }
}
