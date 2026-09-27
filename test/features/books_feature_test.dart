import 'dart:async';
import 'dart:io';
import 'dart:ui' show Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:flutter_scene/src/fmat/fmat.dart';
import 'package:vector_math/vector_math.dart';

import 'package:flutter_3d/data/pokemon.dart';
import 'package:flutter_3d/features/books_feature.dart';
import 'package:flutter_3d/features/interaction_registry.dart';
import 'package:flutter_3d/hotel/feature.dart';
import 'package:flutter_3d/hotel/hotel_context.dart';
import 'package:flutter_3d/math/fp_movement.dart';
import 'package:flutter_3d/ui/screen_overlay.dart';

class _FakeContext extends Fake implements HotelContext {
  _FakeContext({required this.shelfNodes}) {
    camera.position = Vector3(0, 1.6, 0);
    camera.target = Vector3(0, 1.6, 1);
  }

  final Map<String, List<Node>> shelfNodes;

  @override
  final PerspectiveCamera camera = PerspectiveCamera(
    fovRadiansY: 60 * degrees2Radians,
    position: Vector3(0, 1.6, 0),
    target: Vector3(0, 1.6, 1),
  );

  @override
  Vector2 playerXZ = Vector2(0, 0);

  @override
  double playerYaw = 0.0;

  @override
  final InteractionRegistry interactions = InteractionRegistry();

  @override
  List<Node> nodesNamed(String name) => shelfNodes[name] ?? const [];
}

/// A PokéAPI whose replies the test hands out, in any order.
class _ScriptedClient extends PokeApiClient {
  final Map<int, Completer<PokemonResult>> pending = {};

  @override
  Future<PokemonResult> fetch(int id) => (pending[id] = Completer()).future;

  void reply(int id) => pending.remove(id)!.complete(PokemonLoaded(Pokemon(
      id: id, name: 'p$id', types: const [], stats: const {}, artworkUrl: '',
      heightDm: 1, weightHg: 1)));
}

int? _shownId(ValueNotifier<PokemonResult?> page) => switch (page.value) {
      PokemonLoaded(:final pokemon) => pokemon.id,
      _ => null,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('page_curl.fmat', () {
    test('compiles page_curl shader with vertex deformation', () {
      final fmatFile = File('assets/materials/page_curl.fmat');
      expect(fmatFile.existsSync(), isTrue);

      final content = fmatFile.readAsStringSync();
      final compiled = compileFmat(content, fileName: 'assets/materials/page_curl.fmat');

      expect(compiled.material.name, 'page_curl');
      expect(compiled.sidecar['shading_model'], 'unlit');
      expect(compiled.sidecar['blending'], 'opaque');
      expect(compiled.sidecar['culling'], 'none');

      final params = compiled.sidecar['parameters'] as List;
      final paramNames = params.map((p) => p['name']).toList();
      expect(paramNames, containsAll(['progress', 'page_width']));

      final samplers = compiled.sidecar['samplers'] as List;
      final samplerNames = samplers.map((s) => s['name']).toList();
      expect(samplerNames, contains('page_tex'));

      expect(compiled.vertexGlsl, isNotEmpty);
      expect(compiled.sidecar['vertex'], isNotNull);
    });

    test('buildCurlingPageMeshData produces front-facing (+Z) triangles', () {
      final meshData = buildCurlingPageMeshData(width: 0.25, height: 0.35, segments: 24);
      expect(meshData.vertexCount, (24 + 1) * 2);
      expect(meshData.indices!.length, 24 * 6);

      final derived = MeshData.build(
        positions: meshData.positions,
        indices: meshData.indices,
      );
      final normals = derived.normals!;
      for (var i = 2; i < normals.length; i += 3) {
        expect(normals[i], greaterThan(0.9), reason: 'Normal $i should point to +Z');
      }
    });

    test('buildCoverBoxMeshData produces 24 vertices and 36 indices', () {
      final box = buildCoverBoxMeshData(width: 0.5, height: 0.35, depth: 0.01);
      expect(box.vertexCount, 24);
      expect(box.indices!.length, 36);
      expect(box.positions.length, 24 * 3);
      expect(box.normals!.length, 24 * 3);
    });
  });

  group('advanceBookIndex', () {
    test('advances forward by 2 and wraps around', () {
      expect(advanceBookIndex(0, forward: true), 2);
      expect(advanceBookIndex(2, forward: true), 4);
      expect(advanceBookIndex(4, forward: true), 0);
    });

    test('rewinds backward by 2 and wraps around', () {
      expect(advanceBookIndex(0, forward: false), 4);
      expect(advanceBookIndex(4, forward: false), 2);
      expect(advanceBookIndex(2, forward: false), 0);
    });
  });

  group('BooksFeature', () {
    test('catalog contract: free, non-toggleable, id books', () {
      final feature = BooksFeature();
      expect(feature.id, 'books');
      expect(feature.label, 'Pokémon books');
      expect(feature.tier, CostTier.free);
      expect(feature.toggleable, isFalse);
    });

    test('mounts shelf book interactables and unmounts them cleanly', () async {
      final shelf = <String, List<Node>>{};
      for (var i = 0; i < 6; i++) {
        shelf['book_$i'] = [Node(name: 'book_$i')];
      }
      final ctx = _FakeContext(shelfNodes: shelf);
      final feature = BooksFeature();

      await feature.mount(ctx);
      expect(ctx.interactions.all.length, 6);

      feature.unmount(ctx);
      expect(ctx.interactions.all, isEmpty);
    });

    test('opening a book hides shelf node and sets up open book state', () async {
      final bookNode = Node(name: 'book_0');
      final ctx = _FakeContext(shelfNodes: {'book_0': [bookNode]});
      final feature = BooksFeature();

      await feature.mount(ctx);
      expect(bookNode.visible, isTrue);

      feature.openBook(ctx, 0, bookNode);
      expect(feature.isBookOpen, isTrue);
      expect(bookNode.visible, isFalse);
      expect(feature.currentPokemonIndex, 0);

      feature.closeBook(ctx);
      expect(feature.isBookOpen, isFalse);
      expect(bookNode.visible, isTrue);
    });

    test('turnPage triggers curl animation and advances index on completion', () async {
      final bookNode = Node(name: 'book_0');
      final ctx = _FakeContext(shelfNodes: {'book_0': [bookNode]});
      final feature = BooksFeature();

      feature.openBook(ctx, 0, bookNode);
      expect(feature.currentPokemonIndex, 0);

      feature.turnPage(forward: true);
      // Step halfway through duration
      feature.tick(ctx, kPageTurnDuration / 2);
      expect(feature.currentPokemonIndex, 0);

      // Step past completion
      feature.tick(ctx, kPageTurnDuration);
      expect(feature.currentPokemonIndex, 2);

      feature.closeBook(ctx);
    });

    test('a slow reply for a page already turned away from is dropped', () async {
      final bookNode = Node(name: 'book_0');
      final ctx = _FakeContext(shelfNodes: {'book_0': [bookNode]});
      final client = _ScriptedClient();
      final feature = BooksFeature(client: client);

      feature.openBook(ctx, 0, bookNode); // asks for #1 and #4
      feature.turnPage(forward: true);
      feature.tick(ctx, kPageTurnDuration * 1.1); // now asks for #7 and #25
      client.reply(7);
      client.reply(25);
      await pumpEventQueue();
      client.reply(1); // the slow network finally answers the old pages
      client.reply(4);
      await pumpEventQueue();

      expect(_shownId(feature.leftResultNotifier), 7);
      expect(_shownId(feature.rightResultNotifier), 25);
      feature.closeBook(ctx);
    });

    test('a reply meant for the previous book is dropped', () async {
      final book0 = Node(name: 'book_0'), book3 = Node(name: 'book_3');
      final ctx = _FakeContext(shelfNodes: {'book_0': [book0], 'book_3': [book3]});
      final client = _ScriptedClient();
      final feature = BooksFeature(client: client);

      feature.openBook(ctx, 0, book0); // asks for #1 and #4
      feature.closeBook(ctx);
      feature.openBook(ctx, 3, book3); // asks for #25 and #133
      client.reply(1);
      client.reply(4);
      await pumpEventQueue();

      expect(feature.leftResultNotifier.value, isNull); // still loading #25
      expect(feature.rightResultNotifier.value, isNull);
      feature.closeBook(ctx);
    });

    test('the reader stays where they opened the book', () {
      final bookNode = Node(name: 'book_0');
      final ctx = _FakeContext(shelfNodes: {'book_0': [bookNode]})
        ..playerXZ = Vector2(-1, 2);
      final feature = BooksFeature(client: _ScriptedClient());

      feature.openBook(ctx, 0, bookNode);
      for (var i = 0; i < 30; i++) {
        ctx.playerXZ += Vector2(0.02, 0); // the joystick's walk this frame
        feature.tick(ctx, 1 / 60);
      }

      expect(ctx.playerXZ.x, closeTo(-1, 1e-9));
      expect(ctx.playerXZ.y, closeTo(2, 1e-9));
      expect(ctx.camera.position.x, closeTo(-1, 1e-6));
      expect(ctx.camera.position.z, closeTo(2, 1e-6));
      feature.closeBook(ctx);
    });

    test('an ordinary-speed swipe spread over many frames turns the page', () {
      final bookNode = Node(name: 'book_0');
      final ctx = _FakeContext(shelfNodes: {'book_0': [bookNode]});
      final feature = BooksFeature(client: _ScriptedClient());

      feature.openBook(ctx, 0, bookNode);
      // ~900 px/s leftward: 15 px of look-pad drag per 60 Hz frame, 150 px.
      for (var i = 0; i < 10; i++) {
        ctx.playerYaw += -15 * kLookSensitivity; // what the player tick applied
        feature.tick(ctx, 1 / 60);
      }
      feature.tick(ctx, kPageTurnDuration * 1.1);

      expect(feature.currentPokemonIndex, 2);
      feature.closeBook(ctx);
    });

    test('one swipe turns one page', () {
      final bookNode = Node(name: 'book_0');
      final ctx = _FakeContext(shelfNodes: {'book_0': [bookNode]});
      final feature = BooksFeature(client: _ScriptedClient());

      feature.openBook(ctx, 0, bookNode);
      // A long, steady 40-frame swipe outlasts one page turn.
      for (var i = 0; i < 40; i++) {
        ctx.playerYaw += -15 * kLookSensitivity;
        feature.tick(ctx, 1 / 60);
      }
      feature.tick(ctx, kPageTurnDuration * 1.1);

      expect(feature.currentPokemonIndex, 2);
      feature.closeBook(ctx);
    });

    test('the open book faces the reader: pages in front of the cover, left page on the left', () {
      final bookNode = Node(name: 'book_0');
      final ctx = _FakeContext(shelfNodes: {'book_0': [bookNode]});
      final feature = BooksFeature(client: _ScriptedClient());

      feature.openBook(ctx, 0, bookNode);
      final root = feature.openBookRoot!;
      Node part(String name) => root.children.firstWhere((c) => c.name == name);
      Vector3 axisZ(Node n) {
        final m = n.globalTransform.storage;
        return Vector3(m[8], m[9], m[10])..normalize();
      }

      final eye = ctx.camera.position;
      final fwd = ctx.camera.forward.normalized();
      final right = ctx.camera.up.cross(fwd)..normalize();
      double depth(String name) => (part(name).globalTransform.getTranslation() - eye).dot(fwd);

      // A WidgetComponent's quad shows to a camera looking down its node's +Z
      // and maps u = 0 to its local +X (flutter_scene 0.23), so +X must point
      // to the reader's left for the page to read left to right.
      Vector3 axisX(Node n) {
        final m = n.globalTransform.storage;
        return Vector3(m[0], m[1], m[2])..normalize();
      }

      for (final page in ['book_left_page', 'book_right_page']) {
        expect(axisZ(part(page)).dot(fwd), closeTo(1, 1e-6));
        expect(axisX(part(page)).dot(right), closeTo(-1, 1e-6));
      }
      // In front of the cover's near face (the cover is 8 mm deep).
      expect(depth('book_left_page'), lessThan(depth('book_cover') - 0.004));
      expect(depth('book_right_page'), lessThan(depth('book_cover') - 0.004));
      final leftToRight = part('book_right_page').globalTransform.getTranslation() -
          part('book_left_page').globalTransform.getTranslation();
      expect(leftToRight.dot(right), greaterThan(0));
      // page_curl.fmat lifts the page along its mesh's +Z normal: toward the reader.
      expect(depth('book_curling_page'), lessThan(depth('book_right_page')));
      expect(axisZ(part('book_curling_page')).dot(fwd), lessThan(-0.99));
      feature.closeBook(ctx);
    });

    group('the open spread fits the view', () {
      /// Screen bounds of the cover's front face (the whole spread).
      Rect coverOnScreen(_FakeContext ctx, Node root, Size viewport) {
        final cover = root.children.firstWhere((c) => c.name == 'book_cover').globalTransform;
        const hw = kPageWidth + 0.01, hh = kPageHeight / 2 + 0.01;
        return projectedBounds([
          for (final (x, y) in [(-hw, hh), (hw, hh), (hw, -hh), (-hw, -hh)])
            cover.transform3(Vector3(x, y, -0.004)),
        ],
            eye: ctx.camera.position,
            target: ctx.camera.target,
            up: ctx.camera.up,
            fovY: ctx.camera.fovRadiansY,
            viewport: viewport)!;
      }

      test('portrait: both pages fit across the screen', () {
        final bookNode = Node(name: 'book_0');
        final ctx = _FakeContext(shelfNodes: {'book_0': [bookNode]});
        final feature = BooksFeature(client: _ScriptedClient());
        const portrait = Size(402, 874);

        feature.openBook(ctx, 0, bookNode, viewport: portrait);
        final r = coverOnScreen(ctx, feature.openBookRoot!, portrait);

        expect(r.left, greaterThanOrEqualTo(0));
        expect(r.right, lessThanOrEqualTo(portrait.width));
        expect(r.width, greaterThan(portrait.width * 0.9)); // no smaller than it must be
        feature.closeBook(ctx);
      });

      test('landscape: the book stays at arm\'s length', () {
        final bookNode = Node(name: 'book_0');
        final ctx = _FakeContext(shelfNodes: {'book_0': [bookNode]});
        final feature = BooksFeature(client: _ScriptedClient());

        feature.openBook(ctx, 0, bookNode, viewport: const Size(874, 402));
        final at = feature.openBookRoot!.globalTransform.getTranslation();

        expect((at - ctx.camera.position).length, closeTo(kOpenBookDistance, 1e-6));
        feature.closeBook(ctx);
      });
    });
  });
}
