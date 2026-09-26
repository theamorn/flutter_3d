import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

import '../data/pokemon.dart';
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import '../math/fp_movement.dart';
import 'book_page.dart';
import 'interaction_registry.dart';
import 'player_feature.dart';

/// Distance from the camera to the open book, metres.
const double kOpenBookDistance = 0.45;

/// Dimensions of each page in world units (metres).
const double kPageHeight = 0.32;
const double kPageWidth = kPageHeight * (512.0 / 700.0); // ~0.234 m

/// Time in seconds for one page flip animation.
const double kPageTurnDuration = 0.5;

/// Logical pixel drag threshold on look pad to trigger a page turn.
const double kSwipeThreshold = 25.0;

/// Advances or rewinds the book Pokémon index by 2 (two pages per view).
int advanceBookIndex(int current, {required bool forward, int count = 6}) {
  if (count <= 0) return 0;
  final step = forward ? 2 : -2;
  return ((current + step) % count + count) % count;
}

/// Generates a subdivided quad mesh for the curling page.
///
/// 24 horizontal segments x 1 vertical segment across [width].
/// Vertices and winding are front-facing (+Z outward normal).
MeshData buildCurlingPageMeshData({
  required double width,
  required double height,
  int segments = 24,
}) {
  final positions = <double>[];
  final normals = <double>[];
  final uvs = <double>[];
  final tangents = <double>[];
  final indices = <int>[];

  final hh = height / 2;
  for (var i = 0; i <= segments; i++) {
    final t = i / segments;
    final x = t * width;

    // Vertex 2*i: top
    positions.addAll([x, hh, 0.0]);
    normals.addAll([0.0, 0.0, 1.0]);
    uvs.addAll([t, 0.0]);
    tangents.addAll([1.0, 0.0, 0.0, 1.0]);

    // Vertex 2*i + 1: bottom
    positions.addAll([x, -hh, 0.0]);
    normals.addAll([0.0, 0.0, 1.0]);
    uvs.addAll([t, 1.0]);
    tangents.addAll([1.0, 0.0, 0.0, 1.0]);
  }

  for (var i = 0; i < segments; i++) {
    final tl = i * 2;
    final bl = tl + 1;
    final tr = tl + 2;
    final br = tl + 3;
    // Front face with normal +Z: (tl, bl, br) and (tl, br, tr)
    indices.addAll([tl, bl, br, tl, br, tr]);
  }

  return MeshData(
    positions: Float32List.fromList(positions),
    vertexCount: (segments + 1) * 2,
    normals: Float32List.fromList(normals),
    texCoords: Float32List.fromList(uvs),
    tangents: Float32List.fromList(tangents),
    indices: indices,
  );
}

/// Generates a thin box mesh for the open book's cover.
MeshData buildCoverBoxMeshData({
  required double width,
  required double height,
  required double depth,
}) {
  final hw = width / 2;
  final hh = height / 2;
  final hd = depth / 2;

  final p = <double>[
    // Front (+Z)
    -hw, -hh, hd,  hw, -hh, hd,  hw, hh, hd,  -hw, hh, hd,
    // Back (-Z)
    hw, -hh, -hd, -hw, -hh, -hd, -hw, hh, -hd,  hw, hh, -hd,
    // Top (+Y)
    -hw, hh, hd,   hw, hh, hd,   hw, hh, -hd,  -hw, hh, -hd,
    // Bottom (-Y)
    -hw, -hh, -hd, hw, -hh, -hd, hw, -hh, hd,  -hw, -hh, hd,
    // Left (-X)
    -hw, -hh, -hd, -hw, -hh, hd, -hw, hh, hd,  -hw, hh, -hd,
    // Right (+X)
    hw, -hh, hd,   hw, -hh, -hd, hw, hh, -hd,  hw, hh, hd,
  ];

  final n = <double>[
    // Front
    0, 0, 1,  0, 0, 1,  0, 0, 1,  0, 0, 1,
    // Back
    0, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0, -1,
    // Top
    0, 1, 0,  0, 1, 0,  0, 1, 0,  0, 1, 0,
    // Bottom
    0, -1, 0, 0, -1, 0, 0, -1, 0, 0, -1, 0,
    // Left
    -1, 0, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0,
    // Right
    1, 0, 0,  1, 0, 0,  1, 0, 0,  1, 0, 0,
  ];

  final uv = <double>[
    for (var i = 0; i < 6; i++) ...[0, 1, 1, 1, 1, 0, 0, 0],
  ];

  final indices = <int>[
    for (var i = 0; i < 6; i++) ...[
      i * 4, i * 4 + 1, i * 4 + 2,
      i * 4, i * 4 + 2, i * 4 + 3,
    ],
  ];

  return MeshData(
    positions: Float32List.fromList(p),
    vertexCount: 24,
    normals: Float32List.fromList(n),
    texCoords: Float32List.fromList(uv),
    indices: indices,
  );
}

class BooksFeature extends HotelFeature {
  BooksFeature({PokeApiClient? client}) : client = client ?? PokeApiClient();

  final PokeApiClient client;

  @override
  String get id => 'books';
  @override
  String get label => 'Pokémon books';
  @override
  CostTier get tier => CostTier.free;
  @override
  bool get toggleable => false;

  final List<Interactable> _shelfTaps = [];
  PreprocessedMaterial? _curlMaterial;

  // Open book state
  Node? _openShelfNode;
  Node? _openBookRoot;
  Node? _backdropNode;
  Interactable? _backdropTap;

  int _currentIndex = 0;
  final ValueNotifier<PokemonResult?> _leftResult = ValueNotifier(null);
  final ValueNotifier<PokemonResult?> _rightResult = ValueNotifier(null);

  WidgetComponent? _leftComponent;
  WidgetComponent? _rightComponent;
  Node? _curlingNode;

  bool _isCurling = false;
  double _curlProgress = 0.0;
  bool _curlForward = true;

  double? _lockedYaw;
  double? _lockedPitch;

  bool get isBookOpen => _openBookRoot != null;
  int get currentPokemonIndex => _currentIndex;
  ValueNotifier<PokemonResult?> get leftResultNotifier => _leftResult;
  ValueNotifier<PokemonResult?> get rightResultNotifier => _rightResult;

  @override
  Future<void> mount(HotelContext ctx) async {
    try {
      _curlMaterial ??= await loadFmatMaterial('assets/materials/page_curl.fmat');
    } catch (_) {
      // In test environments without asset bundle / GPU, ignore.
    }

    for (var i = 0; i < 6; i++) {
      final shelfNodes = ctx.nodesNamed('book_$i');
      for (final node in shelfNodes) {
        final tap = Interactable(
          node: node,
          label: 'Read book',
          onTap: () => openBook(ctx, i, node),
        );
        _shelfTaps.add(tap);
        ctx.interactions.register(tap);
      }
    }
  }

  @override
  void unmount(HotelContext ctx) {
    if (isBookOpen) {
      closeBook(ctx);
    }
    for (final tap in _shelfTaps) {
      ctx.interactions.unregister(tap);
    }
    _shelfTaps.clear();
  }

  void openBook(HotelContext ctx, int initialIndex, Node shelfNode) {
    if (isBookOpen) return;

    _openShelfNode = shelfNode;
    shelfNode.visible = false;
    _currentIndex = initialIndex % kBookPokemon.length;

    _lockedYaw = ctx.playerYaw;
    final fwd = ctx.camera.forward.normalized();
    _lockedPitch = math.asin(fwd.y.clamp(-1.0, 1.0));

    // Spawn open book in front of camera
    final eye = ctx.camera.position;
    final bookPos = eye + fwd * kOpenBookDistance;

    final root = Node(
      name: 'open_book_root',
      localTransform: Matrix4.translation(bookPos),
    );
    root.lookAt(eye, up: ctx.camera.up);
    try {
      ctx.scene.root.add(root);
    } catch (_) {
      // In tests without a real GPU Scene
    }
    _openBookRoot = root;

    // Cover box behind pages
    try {
      final coverData = buildCoverBoxMeshData(
        width: kPageWidth * 2 + 0.02,
        height: kPageHeight + 0.02,
        depth: 0.008,
      );
      final coverMat = PhysicallyBasedMaterial()
        ..baseColorFactor = Vector4(0.23, 0.12, 0.12, 1.0)
        ..roughnessFactor = 0.7
        ..metallicFactor = 0.0;
      final coverNode = Node(
        name: 'book_cover',
        localTransform: Matrix4.translation(Vector3(0, 0, -0.005)),
      );
      coverNode.mesh = Mesh(MeshGeometry.fromMeshData(coverData), coverMat);
      root.add(coverNode);
    } catch (_) {
      // Without GPU runtime in unit test.
    }

    // Left page node
    final leftNode = Node(
      name: 'book_left_page',
      localTransform: Matrix4.translation(Vector3(-kPageWidth / 2, 0, 0.001)),
    );
    root.add(leftNode);

    // Right page node
    final rightNode = Node(
      name: 'book_right_page',
      localTransform: Matrix4.translation(Vector3(kPageWidth / 2, 0, 0.001)),
    );
    root.add(rightNode);

    // Curling page node
    try {
      final curlData = buildCurlingPageMeshData(
        width: kPageWidth,
        height: kPageHeight,
        segments: 24,
      );
      final curlMat = _curlMaterial ?? UnlitMaterial();
      final curlNode = Node(
        name: 'book_curling_page',
        localTransform: Matrix4.translation(Vector3(0, 0, 0.002)),
      );
      curlNode.mesh = Mesh(MeshGeometry.fromMeshData(curlData), curlMat);
      curlNode.visible = false;
      root.add(curlNode);
      _curlingNode = curlNode;
    } catch (_) {
      // Without GPU runtime in unit test.
    }

    // Dismiss backdrop (slightly behind the book)
    final backdropPos = eye + fwd * (kOpenBookDistance + 0.02);
    final backdrop = Node(
      name: 'book_backdrop',
      localTransform: Matrix4.translation(backdropPos),
    );
    backdrop.lookAt(eye, up: ctx.camera.up);
    try {
      final backdropData = buildCoverBoxMeshData(width: 3.0, height: 3.0, depth: 0.001);
      final transparentMat = UnlitMaterial()
        ..baseColorFactor = Vector4(0.0, 0.0, 0.0, 0.01)
        ..alphaMode = AlphaMode.blend;
      backdrop.mesh = Mesh(MeshGeometry.fromMeshData(backdropData), transparentMat);
    } catch (_) {
      // Without GPU runtime in unit test.
    }
    try {
      ctx.scene.root.add(backdrop);
    } catch (_) {
      // In tests without a real GPU Scene
    }
    _backdropNode = backdrop;

    _backdropTap = Interactable(
      node: backdrop,
      label: 'Close book',
      onTap: () => closeBook(ctx),
    );
    ctx.interactions.register(_backdropTap!);

    // Build and attach left and right page WidgetComponents
    _buildPageWidgets(leftNode, rightNode);
    _fetchCurrentPages();
  }

  void _buildPageWidgets(Node leftNode, Node rightNode) {
    final leftComp = WidgetComponent(
      child: ValueListenableBuilder<PokemonResult?>(
        valueListenable: _leftResult,
        builder: (context, result, _) => BookPage(
          result: result,
          onRetry: () => _fetchPage(isLeft: true),
        ),
      ),
      size: kBookPageSize,
      pixelRatio: 2.0,
      worldHeight: kPageHeight,
      update: WidgetUpdatePolicy.everyFrame,
      input: WidgetInput.automatic,
    );
    leftNode.addComponent(leftComp);
    _leftComponent = leftComp;

    final rightComp = WidgetComponent(
      child: ValueListenableBuilder<PokemonResult?>(
        valueListenable: _rightResult,
        builder: (context, result, _) => BookPage(
          result: result,
          onRetry: () => _fetchPage(isLeft: false),
        ),
      ),
      size: kBookPageSize,
      pixelRatio: 2.0,
      worldHeight: kPageHeight,
      update: WidgetUpdatePolicy.everyFrame,
      input: WidgetInput.automatic,
      bind: (tex) {
        _curlMaterial?.parameters.setTexture('page_tex', tex);
      },
    );
    rightNode.addComponent(rightComp);
    _rightComponent = rightComp;
  }

  void _fetchCurrentPages() {
    _fetchPage(isLeft: true);
    _fetchPage(isLeft: false);
  }

  Future<void> _fetchPage({required bool isLeft}) async {
    final index = isLeft
        ? _currentIndex
        : (_currentIndex + 1) % kBookPokemon.length;
    final id = kBookPokemon[index];

    if (isLeft) {
      _leftResult.value = null;
    } else {
      _rightResult.value = null;
    }
    _requestCapture(isLeft ? _leftComponent : _rightComponent);

    final res = await client.fetch(id);
    if (!isBookOpen) return;

    if (isLeft) {
      _leftResult.value = res;
    } else {
      _rightResult.value = res;
    }
    _requestCapture(isLeft ? _leftComponent : _rightComponent);
  }

  void _requestCapture(WidgetComponent? comp) {
    if (comp == null) return;
    try {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (comp.isAttached) {
          comp.controller.requestCapture();
        }
      });
    } catch (_) {
      // WidgetsBinding not initialized in some unit tests.
    }
  }

  void closeBook(HotelContext ctx) {
    if (!isBookOpen) return;

    if (_backdropTap != null) {
      ctx.interactions.unregister(_backdropTap!);
      _backdropTap = null;
    }

    final backdrop = _backdropNode;
    if (backdrop != null) {
      backdrop.parent?.remove(backdrop);
      _backdropNode = null;
    }

    final bookRoot = _openBookRoot;
    if (bookRoot != null) {
      bookRoot.parent?.remove(bookRoot);
      _openBookRoot = null;
    }

    _leftComponent = null;
    _rightComponent = null;
    _curlingNode = null;

    _openShelfNode?.visible = true;
    _openShelfNode = null;

    _lockedYaw = null;
    _lockedPitch = null;
    _isCurling = false;
  }

  void turnPage({required bool forward}) {
    if (!isBookOpen || _isCurling) return;

    _isCurling = true;
    _curlProgress = 0.0;
    _curlForward = forward;

    final curl = _curlingNode;
    if (curl != null) {
      curl.visible = true;
      final mat = _curlMaterial;
      if (mat != null) {
        mat.parameters
          ..setFloat('progress', 0.0)
          ..setFloat('page_width', kPageWidth);
        final tex = forward
            ? _rightComponent?.controller.texture
            : _leftComponent?.controller.texture;
        if (tex != null) {
          mat.parameters.setTexture('page_tex', tex);
        }
      }
    }
  }

  @override
  void tick(HotelContext ctx, double dt) {
    if (!isBookOpen) return;

    final lockedYaw = _lockedYaw;
    final lockedPitch = _lockedPitch;
    if (lockedYaw != null && lockedPitch != null) {
      // Detect drag on look pad
      final deltaYaw = ctx.playerYaw - lockedYaw;
      final dragX = deltaYaw / kLookSensitivity;

      if (!_isCurling) {
        if (dragX < -kSwipeThreshold) {
          turnPage(forward: true);
        } else if (dragX > kSwipeThreshold) {
          turnPage(forward: false);
        }
      }

      // Keep player camera locked onto the book
      ctx.playerYaw = lockedYaw;
      aimCamera(ctx.camera, FpState(ctx.playerXZ, lockedYaw, lockedPitch));
      PlayerFeature.stick.value = Offset.zero;
    }

    // Step page curl animation
    if (_isCurling) {
      _curlProgress += dt / kPageTurnDuration;
      final p = _curlProgress.clamp(0.0, 1.0);
      _curlMaterial?.parameters.setFloat('progress', p);

      if (_curlProgress >= 1.0) {
        _isCurling = false;
        _curlingNode?.visible = false;
        _currentIndex = advanceBookIndex(
          _currentIndex,
          forward: _curlForward,
          count: kBookPokemon.length,
        );
        _fetchCurrentPages();
      }
    }
  }
}

