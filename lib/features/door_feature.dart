import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import '../math/colliders.dart';
import '../math/door_hinge.dart';
import '../math/floor_plan.dart';
import '../math/portal.dart';
import 'interaction_registry.dart';
import 'player_feature.dart';

/// A shared leaf must not inherit either room's culling visibility. Preserve
/// its world pose while moving it out from under Room A.
void moveDoorToSceneRoot(Node door, Node sceneRoot) {
  final world = door.globalTransform.clone();
  door.parent?.remove(door);
  sceneRoot.add(door);
  door.globalTransform = world;
}

class DoorFeature extends HotelFeature {
  @override
  String get id => 'door';
  @override
  String get label => 'Connecting door';
  @override
  CostTier get tier => CostTier.free;
  @override
  bool get toggleable => false;

  // Portal culling runs after this feature in the catalog. Keep the current
  // hinge angle per scene, separate from doorOpen (which is only the target).
  static final Expando<double> _angleByContext = Expando<double>('door angle');
  static double angleFor(HotelContext ctx) => _angleByContext[ctx] ?? 0;

  Node? _door;
  Node? _originalParent;
  Matrix4? _originalTransform;
  Interactable? _interactable;
  double _angle = 0;

  void _register(HotelContext ctx, Node door) {
    final old = _interactable;
    if (old != null) ctx.interactions.unregister(old);
    final current = Interactable(
      node: door,
      label: ctx.doorOpen.value ? 'Close door' : 'Open door',
      onTap: () {
        ctx.doorOpen.value = !ctx.doorOpen.value;
        _register(ctx, door);
      },
    );
    _interactable = current;
    ctx.interactions.register(current);
  }

  @override
  Future<void> mount(HotelContext ctx) async {
    final matches = ctx.nodesNamed('door_connect');
    if (matches.isEmpty) {
      throw StateError('Connecting door is missing from Room A');
    }
    final door = matches.first;
    _door = door;
    _originalParent = door.parent;
    _originalTransform = door.localTransform.clone();
    moveDoorToSceneRoot(door, ctx.scene.root);
    _angle = 0;
    _angleByContext[ctx] = _angle;
    ctx.dynamicColliders[id] = doorColliders(_angle);
    _register(ctx, door);
  }

  @override
  void tick(HotelContext ctx, double dt) {
    final door = _door;
    if (door == null) return;
    final oldAngle = _angle;
    _angle = stepHinge(_angle, ctx.doorOpen.value, dt);
    _angleByContext[ctx] = _angle;
    // Negative Y turns the +Z leaf against Room A's wall, leaving the gap.
    door.rotation = Quaternion.axisAngle(Vector3(0, 1, 0), -_angle);
    final boxes = doorColliders(_angle);
    ctx.dynamicColliders[id] = boxes;

    // The player tick precedes this one. When a closing leaf re-enters the
    // opening, resolve the new overlap now, including a stationary player.
    if (_angle < oldAngle && boxes.isNotEmpty) {
      final before = ctx.playerXZ;
      final after = moveCircle(
        before,
        before,
        kPlayerRadius,
        playerColliders(ctx.dynamicColliders),
      );
      ctx.playerXZ = after;
      final shift = Vector3(after.x - before.x, 0, after.y - before.y);
      ctx.camera.position = ctx.camera.position + shift;
      ctx.camera.target = ctx.camera.target + shift;
    }
  }

  @override
  void unmount(HotelContext ctx) {
    final interaction = _interactable;
    if (interaction != null) ctx.interactions.unregister(interaction);
    _interactable = null;
    final door = _door;
    final parent = _originalParent;
    final transform = _originalTransform;
    if (door != null && parent != null) {
      door.parent?.remove(door);
      parent.add(door);
      if (transform != null) door.localTransform = transform;
    }
    _door = null;
    _originalParent = null;
    _originalTransform = null;
    _angle = 0;
    _angleByContext[ctx] = 0;
    ctx.dynamicColliders.remove(id);
    ctx.doorOpen.value = false;
  }
}

class PortalCullingFeature extends HotelFeature {
  @override
  String get id => 'portal_culling';
  @override
  String get label => "Hide the room you can't see";
  @override
  CostTier get tier => CostTier.free;

  @override
  Future<void> mount(HotelContext ctx) async => tick(ctx, 0);

  @override
  void tick(HotelContext ctx, double dt) {
    final shown = visibleRooms(
      cameraRoom: FloorPlan.roomOf(ctx.playerXZ),
      doorOpen: doorwayExposed(DoorFeature.angleFor(ctx)),
      cullingEnabled: true,
    );
    for (final id in RoomId.values) {
      final room = ctx.rooms[id];
      if (room != null) room.visible = shown.contains(id);
    }
  }

  @override
  void unmount(HotelContext ctx) {
    for (final room in ctx.rooms.values) {
      room.visible = true;
    }
  }
}
