import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_3d/features/lamps_feature.dart';
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
    'lamps toggle independently and unmount removes lights and taps',
    () async {
      final ctx = _Context();
      for (final room in RoomId.values) {
        final root = Node(name: room.name);
        root.add(Node(name: 'lamp_bedside'));
        root.add(Node(name: 'lamp_floor'));
        ctx.rooms[room] = root;
      }
      final feature = LampsFeature();
      await feature.mount(ctx);
      final taps = ctx.interactions.all.toList();
      expect(taps, hasLength(4));
      PointLight light(int i) => taps[i].node.children.single
          .getComponent<PointLightComponent>()!
          .light;
      expect(light(0).intensity, 8);
      taps[0].onTap();
      expect(light(0).intensity, 0);
      expect(light(1).intensity, 8);
      taps[0].onTap();
      expect(light(0).intensity, 8);
      feature.unmount(ctx);
      expect(ctx.interactions.all, isEmpty);
      expect(taps.every((t) => t.node.children.isEmpty), true);
      await feature.mount(ctx);
      expect(ctx.interactions.all, hasLength(4));
      feature.unmount(ctx);
    },
  );
}
