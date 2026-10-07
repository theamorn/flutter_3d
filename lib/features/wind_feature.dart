import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import '../math/colliders.dart';
import '../math/floor_plan.dart';
import '../render/flagpole.dart';
import '../render/tree_sway.dart';
import '../render/wind.dart';
import 'occlusion_feature.dart' show roomContentsRoot;

/// Each balcony flag's foot, in room A space: by the rail, just left of the
/// window, so the flag flies across the view from inside the room. (The
/// rooms are 90 m above the beach, where a flag would be a speck.)
final Vector3 kBalconyFlagFoot = Vector3(-4.2, 0, 7.55);

/// The pole's footprint, room A space, so the player walks around it.
const Box2 kBalconyFlagCollider = Box2(-4.3, 7.45, -4.1, 7.65);

/// The hotel in the shared wind ([windFor]): a Thai flag on each balcony,
/// the instanced beach palms swaying (`foliage_sway.fmat`), and `ctx.wind`
/// for the rain on the windows to slant and the falling rain to drift. The
/// storm (`ctx.weather`) blows harder.
class WindFeature extends HotelFeature {
  @override
  String get id => 'wind';
  @override
  String get label => 'Wind (balcony flag, swaying palms, slanted rain)';
  @override
  CostTier get tier => CostTier.cheap;
  @override
  bool get defaultOn => false;

  final Map<RoomId, Flagpole> _flags = {};
  TreeSway? _palms;
  Node? _palmsNode;
  double _clock = 0;

  @override
  Future<void> mount(HotelContext ctx) async {
    for (final id in RoomId.values) {
      if (_flags[id] == null) {
        _flags[id] = await Flagpole.build(name: 'balcony_flag', poleHeight: 2.3, flagLength: 1.2);
      }
      _flags[id]!.root.position = kBalconyFlagFoot;
    }
    _palms ??= await TreeSway.load(1);
    ctx.dynamicColliders[id] = [kBalconyFlagCollider, kBalconyFlagCollider.mirrored()];
    tick(ctx, 0);
  }

  @override
  void tick(HotelContext ctx, double dt) {
    _clock += dt;
    _followRooms(ctx);
    _followPalms(ctx);
    final wind = windFor(weather: ctx.weather, time: _clock);
    for (final flag in _flags.values) {
      flag.apply(wind);
    }
    _palms?.apply(wind);
    ctx.wind = wind;
  }

  /// Keeps each room's flag on its balcony; the rooms can remount.
  void _followRooms(HotelContext ctx) {
    _flags.forEach((id, flag) {
      final room = ctx.rooms[id];
      final parent = room == null ? null : roomContentsRoot(room);
      if (identical(flag.root.parent, parent)) return;
      flag.root.detach();
      parent?.add(flag.root);
    });
  }

  /// Sways the current beach palms; the instancing feature can remount and
  /// replace their node.
  void _followPalms(HotelContext ctx) {
    final palms = _palms;
    if (palms == null) return;
    Node? node;
    for (final n in ctx.scene.root.children) {
      if (n.name == 'beach_palms') node = n;
    }
    if (identical(node, _palmsNode)) return;
    palms.release();
    _palmsNode = node;
    // The merged palm (vertex-coloured trunk and crown) is 4.8 m tall.
    if (node != null) {
      palms.bind([node], (_) => const TreeSwayStyle(height: 4.8, bend: 0.55, flutter: 0.08));
    }
  }

  @override
  void unmount(HotelContext ctx) {
    _palms?.release();
    _palmsNode = null;
    for (final flag in _flags.values) {
      flag.root.detach();
    }
    ctx.dynamicColliders.remove(id);
    ctx.wind = null;
  }
}
