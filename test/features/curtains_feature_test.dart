import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/features/curtains_feature.dart';
import 'package:flutter_3d/features/interaction_registry.dart';
import 'package:flutter_3d/hotel/hotel_context.dart';
import 'package:flutter_3d/math/floor_plan.dart';

// Replace only the GPU-owning context; scene nodes and interactions are real.
class _Context extends Fake implements HotelContext {
  @override
  final Map<RoomId, Node> rooms = {};
  @override
  final InteractionRegistry interactions = InteractionRegistry();
  @override
  List<Node> nodesNamed(String name) => [
    for (final room in rooms.values)
      for (final node in room.children)
        if (node.name == name) node,
  ];
}

void main() {
  test(
    'paired curtains keep outer edges anchored and rooms independent',
    () async {
      final ctx = _Context();
      for (final room in RoomId.values) {
        final root = Node();
        for (final side in ['left', 'right']) {
          final left = side == 'left';
          root.add(
            Node(
              name: 'curtain_$side',
              localTransform: Matrix4.translationValues(
                left ? -4.225 : -1.775,
                0,
                5.925,
              )..scaleByVector3(Vector3(.25, 1, 1)),
            ),
          );
        }
        ctx.rooms[room] = root;
      }
      final feature = CurtainsFeature();
      await feature.mount(ctx);
      final taps = ctx.interactions.all.toList();
      expect(taps, hasLength(4));
      taps.first.onTap();
      feature.tick(ctx, .4);
      final a = ctx.rooms[RoomId.a]!.children;
      expect(a.first.scale.x, closeTo(.625, 1e-6));
      expect(a.first.position.x - .7 * a.first.scale.x, closeTo(-4.4, 1e-6));
      expect(a.last.position.x + .7 * a.last.scale.x, closeTo(-1.6, 1e-6));
      expect(ctx.rooms[RoomId.b]!.children.first.scale.x, closeTo(.25, 1e-6));
      feature.tick(ctx, .4);
      expect(a.first.scale.x, closeTo(1, 1e-6));
      ctx.interactions.forNode(a.first)!.onTap();
      feature.tick(ctx, .8);
      expect(a.first.scale.x, closeTo(.25, 1e-6));
      feature.unmount(ctx);
      expect(ctx.interactions.all, isEmpty);
    },
  );
}
