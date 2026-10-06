import 'package:flutter_3d/features/placeholder_rooms.dart';
import 'package:flutter_3d/render/shadow_channels.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every node under [root] with its slash-joined path from the room root's
/// children (the room root itself is not part of a path).
List<(String, RoomNode)> _paths(RoomNode root) {
  final out = <(String, RoomNode)>[];
  void walk(RoomNode n, String prefix) {
    for (final c in n.children) {
      final path = prefix.isEmpty ? c.name : '$prefix/${c.name}';
      out.add((path, c));
      walk(c, path);
    }
  }

  walk(root, '');
  return out;
}

void main() {
  group('channel bits', () {
    test('ordinary surfaces cast into a fixture light\'s shadow map', () {
      // Walls, doorframes and pillows keep the engine default, which holds
      // the ordinary channel.
      expect(kDefaultLightChannelMask & kOrdinaryLightChannel, isNot(0));
      expect(castsShadowFor(kDefaultLightChannelMask, kFixtureExcludedCasterMask), isTrue);
      expect(castsShadowFor(kOrdinaryLightChannel, kFixtureExcludedCasterMask), isTrue);
    });

    test('fixture pieces do not, but every light still lights them', () {
      expect(castsShadowFor(kFixtureSelfShadowChannel, kFixtureExcludedCasterMask), isFalse);
      expect(litBy(kFixtureSelfShadowChannel, kDirectLightMask), isTrue);
      expect(litBy(kDefaultLightChannelMask, kDirectLightMask), isTrue);
    });

    test('the comparison mask lets fixtures cast again', () {
      expect(castsShadowFor(kFixtureSelfShadowChannel, kIncludeFixtureCasterMask), isTrue);
      expect(kFixtureExcludedCasterMask, 0xFD);
      expect(kIncludeFixtureCasterMask, 0xFF);
    });
  });

  group('source-enclosing fixture parts', () {
    test('the room marks exactly the parts that enclose a light source', () {
      final marked = {
        for (final (path, n) in _paths(roomASpec()))
          if (n.lightChannelMask == kFixtureSelfShadowChannel) path,
      };
      expect(marked, kSourceEnclosingParts);
    });

    test('each marked part really encloses its fixture\'s light (geometry check)', () {
      final nodes = {for (final (path, n) in _paths(roomASpec())) path: n};
      for (final path in kSourceEnclosingParts) {
        final fixture = path.substring(0, path.indexOf('/'));
        final source = kFixtureLightSources[fixture];
        expect(source, isNotNull, reason: fixture);
        expect(encloses(nodes[path]!, source!), isTrue, reason: path);
      }
    });

    test('no other fixture part encloses a light, and no wall or bedding is marked', () {
      final nodes = {for (final (path, n) in _paths(roomASpec())) path: n};
      for (final MapEntry(key: fixture, value: source) in kFixtureLightSources.entries) {
        for (final MapEntry(key: path, value: node) in nodes.entries) {
          if (!path.startsWith('$fixture/')) continue;
          expect(encloses(node, source), kSourceEnclosingParts.contains(path), reason: path);
        }
      }
      for (final path in ['walls', 'bed', 'floor', 'ceiling']) {
        expect(nodes[path]?.lightChannelMask, isNull, reason: path);
      }
    });
  });
}
