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
import '../ui/screen_overlay.dart';
import 'book_page.dart';
import 'interaction_registry.dart';
import 'player_feature.dart';

/// Distance from the camera to the open book, metres, unless the spread
/// needs more room to fit the view (a portrait phone).
const double kOpenBookDistance = 0.45;

/// Dimensions of each page in world units (metres).
const double kPageHeight = 0.32;
const double kPageWidth = kPageHeight * (512.0 / 700.0); // ~0.234 m

/// The open book (both pages and the cover's 1 cm rim), metres.
const double kSpreadWidth = kPageWidth * 2 + 0.02;
const double kSpreadHeight = kPageHeight + 0.02;

/// Largest share of the view the open spread fills.
const double kSpreadFill = 0.95;

/// The SceneView fills the window, so the window is the viewport.
Size _windowSize() {
  final view = WidgetsBinding.instance.platformDispatcher.implicitView;
  return view == null ? Size.zero : view.physicalSize / view.devicePixelRatio;
}

/// Time in seconds for one page flip animation.
const double kPageTurnDuration = 0.5;

/// Look-pad drag, logical px, one swipe needs to turn a page.
const double kSwipeThreshold = 40.0;

/// Seconds the look pad must rest before the next swipe can turn a page.
const double kSwipePause = 0.15;

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
  Vector2? _lockedXZ;

  /// Horizontal drag (px, + = right) of the swipe in progress; a swipe turns
  /// at most one page ([_swipeSpent]) until the pad rests for [kSwipePause].
  double _swipe = 0;
  double _swipeIdle = 0;
  bool _swipeSpent = false;

  /// Bumped per request and on close, so a reply for a page no longer shown
  /// (turned away from, or from a previous book) is dropped.
  int _leftRequest = 0, _rightRequest = 0;

  bool get isBookOpen => _openBookRoot != null;
  @visibleForTesting
  Node? get openBookRoot => _openBookRoot;
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

  void openBook(HotelContext ctx, int initialIndex, Node shelfNode, {Size? viewport}) {
    if (isBookOpen) return;

    _openShelfNode = shelfNode;
    shelfNode.visible = false;
    _currentIndex = initialIndex % kBookPokemon.length;

    _lockedYaw = ctx.playerYaw;
    _lockedXZ = ctx.playerXZ.clone();
    _swipe = 0;
    _swipeIdle = 0;
    _swipeSpent = false;
    final fwd = ctx.camera.forward.normalized();
    _lockedPitch = math.asin(fwd.y.clamp(-1.0, 1.0));

    // Spawn open book in front of camera, far enough that both pages fit
    final eye = ctx.camera.position;
    final distance = fitDistance(kSpreadWidth, kSpreadHeight,
        fovY: ctx.camera.fovRadiansY,
        viewport: viewport ?? _windowSize(),
        min: kOpenBookDistance,
        fill: kSpreadFill);
    final bookPos = eye + fwd * distance;

    final root = Node(
      name: 'open_book_root',
      localTransform: Matrix4.translation(bookPos),
    );
    // +Z along the view, as the camera looks: a WidgetComponent's quad shows
    // to a camera looking down its +Z, and +X is then the reader's right.
    // Nearer the reader is −Z.
    root.lookAt(bookPos + fwd, up: ctx.camera.up);
    try {
      ctx.scene.root.add(root);
    } catch (_) {
      // In tests without a real GPU Scene
    }
    _openBookRoot = root;

    // Cover box behind pages (its near face at +1 mm)
    final coverNode = Node(
      name: 'book_cover',
      localTransform: Matrix4.translation(Vector3(0, 0, 0.005)),
    );
    root.add(coverNode);
    try {
      final coverData = buildCoverBoxMeshData(
        width: kSpreadWidth,
        height: kSpreadHeight,
        depth: 0.008,
      );
      final coverMat = PhysicallyBasedMaterial()
        ..baseColorFactor = Vector4(0.23, 0.12, 0.12, 1.0)
        ..roughnessFactor = 0.7
        ..metallicFactor = 0.0;
      coverNode.mesh = Mesh(MeshGeometry.fromMeshData(coverData), coverMat);
    } catch (_) {
      // Without GPU runtime in unit test.
    }

    // Page nodes, mirrored in x: WidgetComponent's own quad (0.23) is only
    // front-facing from the side where its u runs right to left. The engine
    // flips winding under a negative scale, so the mirrored quad stays
    // visible to the reader and its text reads left to right.
    Matrix4 page(double x) =>
        Matrix4.translationValues(x, 0, -0.001)..scaleByVector3(Vector3(-1, 1, 1));
    final leftNode = Node(name: 'book_left_page', localTransform: page(-kPageWidth / 2));
    root.add(leftNode);
    final rightNode = Node(name: 'book_right_page', localTransform: page(kPageWidth / 2));
    root.add(rightNode);

    // Curling page node, over the right page. page_curl.fmat lifts the page
    // along its mesh's +Z normal; mirroring z points that at the reader.
    final curlNode = Node(
      name: 'book_curling_page',
      localTransform: Matrix4.translationValues(0, 0, -0.002)..scaleByVector3(Vector3(1, 1, -1)),
    )..visible = false;
    root.add(curlNode);
    _curlingNode = curlNode;
    try {
      final curlData = buildCurlingPageMeshData(
        width: kPageWidth,
        height: kPageHeight,
        segments: 24,
      );
      final curlMat = _curlMaterial ?? UnlitMaterial();
      curlNode.mesh = Mesh(MeshGeometry.fromMeshData(curlData), curlMat);
    } catch (_) {
      // Without GPU runtime in unit test.
    }

    // Dismiss backdrop (slightly behind the book)
    final backdropPos = eye + fwd * (distance + 0.02);
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
      // Paper, not a screen: take exposure, tone mapping and fog like the
      // book around it. 0.24 made WidgetComponent display-referred by default.
      displayReferred: false,
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
      // Paper, not a screen: take exposure, tone mapping and fog like the
      // book around it. 0.24 made WidgetComponent display-referred by default.
      displayReferred: false,
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
    final request = isLeft ? ++_leftRequest : ++_rightRequest;

    if (isLeft) {
      _leftResult.value = null;
    } else {
      _rightResult.value = null;
    }
    _requestCapture(isLeft ? _leftComponent : _rightComponent);

    final res = await client.fetch(id);
    if (!isBookOpen || request != (isLeft ? _leftRequest : _rightRequest)) return;

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
    _lockedXZ = null;
    _isCurling = false;
    _leftRequest++;
    _rightRequest++;
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

  /// Swipe left turns forward, right turns back: one page per swipe.
  void _swipeStep(double dragX, double dt) {
    if (dragX == 0) {
      _swipeIdle += dt;
      if (_swipeIdle > kSwipePause) {
        _swipe = 0;
        _swipeSpent = false;
      }
      return;
    }
    _swipeIdle = 0;
    if (_swipeSpent) return;
    // A change of direction starts the swipe over.
    _swipe = (_swipe * dragX < 0 ? 0 : _swipe) + dragX;
    if (!_isCurling && _swipe.abs() >= kSwipeThreshold) {
      turnPage(forward: _swipe < 0);
      _swipeSpent = true;
    }
  }

  @override
  void tick(HotelContext ctx, double dt) {
    if (!isBookOpen) return;

    final lockedYaw = _lockedYaw;
    final lockedPitch = _lockedPitch;
    final lockedXZ = _lockedXZ;
    if (lockedYaw != null && lockedPitch != null && lockedXZ != null) {
      // The player tick turned this frame's look-pad drag into yaw; read it
      // back as the swipe, gathered over frames (one frame's share of an
      // ordinary swipe is only ~15 px).
      _swipeStep((ctx.playerYaw - lockedYaw) / kLookSensitivity, dt);

      // Keep the reader and the camera locked onto the book
      ctx.playerXZ = lockedXZ.clone();
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

