import 'package:flutter/foundation.dart';
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
  final ValueNotifier<int> lightingRevision = ValueNotifier(0);
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
      expect(light(0).intensity, 4);
      taps[0].onTap();
      expect(light(0).intensity, 0);
      expect(light(1).intensity, 4);
      taps[0].onTap();
      expect(light(0).intensity, 4);
      feature.unmount(ctx);
      expect(ctx.interactions.all, isEmpty);
      expect(taps.every((t) => t.node.children.isEmpty), true);
      await feature.mount(ctx);
      expect(ctx.interactions.all, hasLength(4));
      feature.unmount(ctx);
    },
  );

  test('each bathroom switch toggles its own dim ceiling light', () async {
    final ctx = _Context();
    final switches = <Node>[], lights = <Node>[];
    for (final room in RoomId.values) {
      final root = Node(name: room.name);
      final light = Node(name: 'bath_light');
      final sw = Node(name: 'bath_switch')..add(Node(name: 'bath_switch_rocker'));
      root
        ..add(light)
        ..add(sw);
      lights.add(light);
      switches.add(sw);
      ctx.rooms[room] = root;
    }
    final feature = LampsFeature();
    await feature.mount(ctx);
    final taps = ctx.interactions.all.toList();
    expect(taps.map((t) => t.node), switches, reason: 'the switches are what you tap');
    PointLight bath(int i) =>
        lights[i].children.single.getComponent<PointLightComponent>()!.light;
    final rocker = switches[0].children.single;
    final restPose = rocker.localTransform.clone();

    expect(bath(0).intensity, kBathLightIntensity, reason: 'on by default');
    expect(kBathLightIntensity, lessThan(kLampIntensity), reason: 'a low light');
    taps[0].onTap();
    expect(bath(0).intensity, 0);
    expect(bath(1).intensity, kBathLightIntensity, reason: 'room B is untouched');
    expect(rocker.localTransform, isNot(restPose), reason: 'the rocker flips');
    taps[0].onTap();
    expect(bath(0).intensity, kBathLightIntensity);
    expect(rocker.localTransform, restPose);

    taps[0].onTap(); // leave it off, then unmount
    feature.unmount(ctx);
    expect(ctx.interactions.all, isEmpty);
    expect(lights.every((l) => l.children.isEmpty), true);
    expect(rocker.localTransform, restPose);
  });

  test('switching any lamp or the bathroom light bumps the lighting revision', () async {
    final ctx = _Context();
    for (final room in RoomId.values) {
      final root = Node(name: room.name)
        ..add(Node(name: 'lamp_bedside'))
        ..add(Node(name: 'lamp_floor'))
        ..add(Node(name: 'bath_light'))
        ..add(Node(name: 'bath_switch'));
      ctx.rooms[room] = root;
    }
    await LampsFeature().mount(ctx);
    final taps = ctx.interactions.all.toList();
    expect(taps, hasLength(6));
    for (final tap in taps) {
      tap.onTap();
    }
    expect(ctx.lightingRevision.value, 6);
  });
}
