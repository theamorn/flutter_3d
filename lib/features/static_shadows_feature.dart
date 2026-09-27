import 'package:flutter_scene/scene.dart';
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

/// Room nodes that move while mounted, with everything under them: they stay
/// dynamic shadow casters. The door leaf moves to the scene root once the
/// door feature mounts, but is listed in case it has not yet.
const Set<String> kShadowMovers = {
  'door_connect',
  'curtain_left',
  'curtain_right',
  'faucet_lever',
  'bath_switch_rocker',
};

/// Marks [root]'s subtree as static shadow casters, skipping [movers] and
/// their subtrees. Returns only the nodes it changed, so unmarking them
/// restores exactly what was there.
List<Node> markStaticShadows(Node root, {Set<String> movers = kShadowMovers}) {
  final out = <Node>[];
  void walk(Node n) {
    if (movers.contains(n.name)) return;
    if (!n.shadowStatic) {
      n.shadowStatic = true;
      out.add(n);
    }
    for (final c in n.children) {
      walk(c);
    }
  }

  walk(root);
  return out;
}

/// Cached static shadows: walls and furniture render into cached sun
/// shadow-map tiles once (the engine re-renders them only when the sun or a
/// caster changes), and only the movers render every frame.
class StaticShadowsFeature extends HotelFeature {
  @override
  String get id => 'static_shadows';
  @override
  String get label => 'Cached static shadows';
  @override
  CostTier get tier => CostTier.free;

  final Map<Node, List<Node>> _markedByRoom = {};

  void _syncRooms(HotelContext ctx) {
    final currentRooms = ctx.rooms.values.toSet();
    final removedRooms = _markedByRoom.keys
        .where((room) => !currentRooms.contains(room))
        .toList(growable: false);
    for (final room in removedRooms) {
      for (final node in _markedByRoom.remove(room)!) {
        node.shadowStatic = false;
      }
    }
    for (final room in currentRooms) {
      _markedByRoom.putIfAbsent(room, () => markStaticShadows(room));
    }
  }

  @override
  Future<void> mount(HotelContext ctx) async => _syncRooms(ctx);

  @override
  void tick(HotelContext ctx, double dt) => _syncRooms(ctx);

  @override
  void unmount(HotelContext ctx) {
    for (final marked in _markedByRoom.values) {
      for (final node in marked) {
        node.shadowStatic = false;
      }
    }
    _markedByRoom.clear();
  }
}
