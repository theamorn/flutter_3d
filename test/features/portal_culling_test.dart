import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/features/door_feature.dart';
import 'package:flutter_3d/hotel/hotel_context.dart';
import 'package:flutter_3d/math/floor_plan.dart';

class _Context extends Fake implements HotelContext {
  @override
  final Map<RoomId, Node> rooms = {RoomId.a: Node(name: 'room_a'), RoomId.b: Node(name: 'room_b')};
  @override
  Vector2 playerXZ = Vector2(-4, 3); // room A, connecting door shut
  @override
  int occlusionHolds = 0;
}

void main() {
  test('the room you cannot see is hidden', () async {
    final ctx = _Context();
    await PortalCullingFeature().mount(ctx);
    expect(ctx.rooms[RoomId.a]!.visible, isTrue);
    expect(ctx.rooms[RoomId.b]!.visible, isFalse);
  });

  test('under an occlusion hold both rooms show, so probe captures see them', () async {
    final ctx = _Context();
    final f = PortalCullingFeature();
    await f.mount(ctx);
    ctx.occlusionHolds = 1;
    f.tick(ctx, 0.016);
    expect(ctx.rooms[RoomId.b]!.visible, isTrue);
    ctx.occlusionHolds = 0;
    f.tick(ctx, 0.016);
    expect(ctx.rooms[RoomId.b]!.visible, isFalse);
  });
}
