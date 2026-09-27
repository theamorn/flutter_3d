import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/features/static_shadows_feature.dart';
import 'package:flutter_3d/hotel/hotel_context.dart';
import 'package:flutter_3d/math/floor_plan.dart';

class _RoomsContext extends Fake implements HotelContext {
  @override
  final Map<RoomId, Node> rooms = {};
}

Node tree() => Node(name: 'room_a')
  ..add(Node(name: 'walls'))
  ..add(Node(name: 'bed'))
  ..add(Node(name: 'curtain_left'))
  ..add(Node(name: 'faucet_spout')..add(Node(name: 'faucet_lever')..add(Node(name: 'lever_tip'))))
  ..add(Node(name: 'bath_switch')..add(Node(name: 'bath_switch_rocker')));

Node named(Node n, String name) {
  Node? find(Node m) {
    if (m.name == name) return m;
    for (final c in m.children) {
      final hit = find(c);
      if (hit != null) return hit;
    }
    return null;
  }

  return find(n) ?? (throw StateError('no node $name'));
}

void main() {
  test('everything static is marked; movers and their subtrees stay dynamic', () {
    final root = tree();
    final marked = markStaticShadows(root);
    for (final name in ['room_a', 'walls', 'bed', 'faucet_spout', 'bath_switch']) {
      expect(named(root, name).shadowStatic, isTrue, reason: name);
    }
    for (final name in ['curtain_left', 'faucet_lever', 'lever_tip', 'bath_switch_rocker']) {
      expect(named(root, name).shadowStatic, isFalse, reason: name);
    }
    expect(marked, hasLength(5));
  });

  test('only nodes it changed are returned, so unmarking restores exactly', () {
    final root = tree();
    named(root, 'walls').shadowStatic = true;
    final marked = markStaticShadows(root);
    for (final n in marked) {
      n.shadowStatic = false;
    }
    expect(named(root, 'walls').shadowStatic, isTrue);
    expect(named(root, 'bed').shadowStatic, isFalse);
  });

  test('room roots remounted while enabled receive static shadows', () async {
    final ctx = _RoomsContext();
    final feature = StaticShadowsFeature();
    final first = tree();
    ctx.rooms[RoomId.a] = first;
    await feature.mount(ctx);

    final replacement = tree();
    ctx.rooms[RoomId.a] = replacement;
    feature.tick(ctx, 0.016);

    expect(named(first, 'bed').shadowStatic, isFalse);
    expect(named(replacement, 'bed').shadowStatic, isTrue);
    feature.unmount(ctx);
    expect(named(replacement, 'bed').shadowStatic, isFalse);
  });
}
