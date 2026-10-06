import 'package:flutter_3d/features/placeholder_rooms.dart';
import 'package:flutter_3d/render/material_binding_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every node in [root], depth first.
Iterable<RoomNode> _walk(RoomNode root) sync* {
  yield root;
  for (final c in root.children) {
    yield* _walk(c);
  }
}

/// A stand-in for a scene node: identity, nothing else.
class _Target {
  _Target(this.name);
  final String name;
  @override
  String toString() => name;
}

void main() {
  group('MaterialBindingPolicy', () {
    test('binds each wanted target once', () {
      final a = _Target('a'), b = _Target('b');
      final policy = MaterialBindingPolicy<_Target, String>();
      final first = policy.reconcile([a, b]);
      expect(first.bind, [a, b]);
      expect(first.release, isEmpty);
      policy
        ..bind(a, 'mesh a')
        ..bind(b, 'mesh b');
      final again = policy.reconcile([a, b]);
      expect(again.bind, isEmpty);
      expect(again.release, isEmpty);
    });

    test('a room remount hands back the superseded original exactly once', () {
      final old = _Target('bed (old room)'), fresh = _Target('bed (new room)');
      final policy = MaterialBindingPolicy<_Target, String>()..bind(old, 'original');
      final remount = policy.reconcile([fresh]);
      expect(remount.release, [(old, 'original')]);
      expect(remount.bind, [fresh]);
      policy.bind(fresh, 'fresh original');
      // The old target is gone from the policy: no second restore.
      final later = policy.reconcile([fresh]);
      expect(later.release, isEmpty);
      expect(later.bind, isEmpty);
    });

    test('binding a bound target again keeps the true original', () {
      final a = _Target('a');
      final policy = MaterialBindingPolicy<_Target, String>()
        ..bind(a, 'authored mesh')
        ..bind(a, 'already swapped mesh');
      expect(policy.releaseAll(), [(a, 'authored mesh')]);
    });

    test('releaseAll returns every original once, then nothing', () {
      final a = _Target('a'), b = _Target('b');
      final policy = MaterialBindingPolicy<_Target, String>()
        ..bind(a, 'ma')
        ..bind(b, 'mb');
      expect(policy.releaseAll(), [(a, 'ma'), (b, 'mb')]);
      expect(policy.releaseAll(), isEmpty);
      expect(policy.isBound(a), isFalse);
    });

    test('never touches a surface it was not asked to bind', () {
      final wanted = _Target('pillow'), unrelated = _Target('linen');
      final policy = MaterialBindingPolicy<_Target, String>();
      final changes = policy.reconcile([wanted]);
      expect(changes.bind, isNot(contains(unrelated)));
      policy.bind(wanted, 'm');
      expect(policy.isBound(unrelated), isFalse);
      expect(policy.reconcile(const []).release, [(wanted, 'm')]);
    });
  });

  group('bedding roles', () {
    test('only the jacquard pillows and the wool throw are tagged', () {
      final tagged = <Finish>{
        for (final n in _walk(roomASpec()))
          for (final p in n.parts)
            if (p.finish.bedding != BeddingMaterialRole.none) p.finish,
      };
      expect(tagged.map((f) => f.bedding).toSet(),
          {BeddingMaterialRole.jacquardPillow, BeddingMaterialRole.woolThrow});
      expect(tagged, hasLength(2));
      final byRole = {for (final f in tagged) f.bedding: f.texture?.id};
      expect(byRole[BeddingMaterialRole.jacquardPillow], 'quatrefoil_jacquard_fabric');
      expect(byRole[BeddingMaterialRole.woolThrow], 'poly_wool_herringbone');
    });

    test('the sleeping linen stays untagged', () {
      for (final n in _walk(roomASpec())) {
        for (final p in n.parts) {
          if (p.finish.texture?.id == 'rough_linen') {
            expect(p.finish.bedding, BeddingMaterialRole.none, reason: n.name);
          }
        }
      }
    });

    test('bedding slots index the bed mesh primitives in builder order', () {
      final bed = _walk(roomASpec()).singleWhere((n) => n.name == 'bed');
      final finishes = primitiveFinishes(bed.parts);
      final slots = beddingSlots(bed.parts);
      expect(slots.map((s) => s.role).toSet(),
          {BeddingMaterialRole.jacquardPillow, BeddingMaterialRole.woolThrow});
      for (final s in slots) {
        expect(finishes[s.primitive], same(s.finish));
        expect(s.finish.bedding, s.role);
      }
      // One primitive per finish, so each role is one slot.
      expect(slots, hasLength(2));
      // The linen primitive (duvet + sleeping pillows) is not a slot.
      final linen = finishes.indexWhere((f) => f.texture?.id == 'rough_linen');
      expect(linen, isNonNegative);
      expect(slots.map((s) => s.primitive), isNot(contains(linen)));
    });

    test('no other node has bedding slots', () {
      for (final n in _walk(roomASpec())) {
        if (n.name == 'bed') continue;
        expect(beddingSlots(n.parts), isEmpty, reason: n.name);
      }
    });
  });
}
