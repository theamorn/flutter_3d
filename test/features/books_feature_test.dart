import 'dart:io';

import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:flutter_scene/src/fmat/fmat.dart';
import 'package:vector_math/vector_math.dart';

import 'package:flutter_3d/features/books_feature.dart';
import 'package:flutter_3d/features/interaction_registry.dart';
import 'package:flutter_3d/hotel/feature.dart';
import 'package:flutter_3d/hotel/hotel_context.dart';

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
  });
}
