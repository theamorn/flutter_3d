import 'dart:async';
import 'dart:ui' show PlatformDispatcher, Size;

import 'package:flutter/foundation.dart' show debugPrint, listEquals;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import '../math/mirror_capture_layout.dart';
import '../render/prewarm.dart';
import 'reflection_features.dart' show kBathroomReflectionGroup;

/// The material each custom mirror draws with.
const String kMirrorCaptureFmat = 'assets/materials/mirror_capture.fmat';

/// The render layer a custom mirror sits on while it shows its capture.
/// Every custom capture leaves it out, so no mirror feeds back into itself
/// or the other room's mirror. Layers 1, 2 and 4 are taken (island
/// no-reflect, the sea, what the sea reflects).
const int kCustomMirrorLayer = 1 << 5;

/// What a custom mirror capture draws: everything but the mirrors.
const int kCustomMirrorCaptureMask = kRenderLayerAll & ~kCustomMirrorLayer;

/// How far in front of the glass the capture clips (oblique near plane).
const double kMirrorClipBias = 0.001;

/// Bathroom mirrors drawn from a capture the hotel renders itself, instead
/// of the engine's planar reflector: each mirror gets a linear-HDR
/// [RenderTexture], an offscreen [RenderView] in `Scene.views` rendered by
/// a fresh [PlanarReflectionCamera] every frame, and `mirror_capture.fmat`,
/// which samples the latest completed capture through the view-projection
/// that capture was rendered with.
///
/// A mirror the camera cannot see (occlusion hid it, or the camera is
/// behind the glass) takes its view out of `Scene.views`, so a dormant
/// mirror renders nothing. Each bound mirror is registered with the
/// context, so occlusion culling keeps what it reflects drawn.
class CustomMirrorFeature extends HotelFeature {
  @override
  String get id => 'mirror_custom';
  @override
  String get label => 'Bathroom mirror (custom HDR capture)';
  @override
  CostTier get tier => CostTier.expensive;
  @override
  bool get defaultOn => false;
  @override
  String? get exclusiveGroup => kBathroomReflectionGroup;

  /// One material per mirror, loaded once and kept across toggles.
  final List<PreprocessedMaterial> _materials = [];
  final List<_CustomMirror> _mirrors = [];

  /// The capture size of each active mirror, for diagnostics.
  List<(int, int)> get activeCaptures => [
        for (final m in _mirrors)
          if (m.active) (m.target.width, m.target.height),
      ];
  String _lastReport = '';

  @override
  Future<void> mount(HotelContext ctx) async {
    while (_materials.length < 2) {
      _materials.add(await loadFmatMaterial(kMirrorCaptureFmat));
    }
    _follow(ctx);
  }

  @override
  void tick(HotelContext ctx, double dt) {
    _follow(ctx);
    final view = PlatformDispatcher.instance.implicitView;
    final viewport = view == null ? Size.zero : view.physicalSize / view.devicePixelRatio;
    for (final m in _mirrors) {
      m.update(ctx, viewport);
    }
    final report = activeCaptures.map((s) => '${s.$1}x${s.$2}').join(', ');
    if (report != _lastReport) {
      _lastReport = report;
      debugPrint('custom mirror: ${report.isEmpty ? 'no active capture' : 'capturing $report'}');
    }
  }

  /// Binds the rooms' current mirrors, rebinding after a room remount.
  void _follow(HotelContext ctx) {
    final nodes = ctx.nodesNamed('mirror');
    if (listEquals([for (final m in _mirrors) m.node], nodes)) return;
    _release(ctx);
    for (var i = 0; i < nodes.length && i < _materials.length; i++) {
      _mirrors.add(_CustomMirror(this, nodes[i], _materials[i]));
    }
  }

  void _release(HotelContext ctx) {
    for (final m in _mirrors) {
      m.dispose(ctx);
    }
    _mirrors.clear();
    ctx.reflectionCaptures.unregisterAll(this);
  }

  @override
  void unmount(HotelContext ctx) {
    _release(ctx);
    _lastReport = '';
  }
}

class _CustomMirror {
  _CustomMirror(this.owner, this.node, this.material)
      : _ownMesh = node.mesh,
        _ownLayers = node.layers {
    view = RenderView(
      camera: PerspectiveCamera(),
      target: target,
      layerMask: kCustomMirrorCaptureMask,
    );
    target.addListener(_captured);
    final original = _ownMesh?.primitives.firstOrNull?.material;
    if (original is PhysicallyBasedMaterial) {
      final c = original.baseColorFactor;
      material.parameters.setVec4('base_color', Vector4(c.x * 0.2, c.y * 0.2, c.z * 0.2, 1));
    }
    material.parameters.setFloat('capture_ready', 0);
  }

  final CustomMirrorFeature owner;
  final Node node;
  final PreprocessedMaterial material;
  final RenderTexture target = RenderTexture(width: kMirrorCaptureMax, height: kMirrorCaptureMax, linearColor: true);
  late final RenderView view;
  final Mesh? _ownMesh;
  final int _ownLayers;
  Scene? _scene;
  bool _wearing = false;
  bool active = false;

  /// Points the capture at this frame's camera, or puts the mirror to sleep
  /// when nobody can see it.
  void update(HotelContext ctx, Size viewport) {
    final plane = computeMirrorPlane(node.globalTransform, Vector3(1, 0, 0));
    if (plane == null) {
      _sleep(ctx);
      return;
    }
    ctx.reflectionCaptures.register(owner, node, plane);
    final eye = ctx.camera.position;
    final facing = plane.normal.dot(eye) + plane.constant > 0;
    if (!facing || !_shown(node)) {
      _sleep(ctx);
      return;
    }
    final (w, h) = computeMirrorTargetSize(viewport.width, viewport.height);
    target.resize(w, h);
    view.camera = PlanarReflectionCamera(
      source: ctx.camera,
      plane: plane,
      clipBias: kMirrorClipBias,
    );
    if (!active) {
      ctx.scene.views.add(view);
      _scene = ctx.scene;
      active = true;
    }
  }

  /// A completed capture: bind it with the matrix of the camera that drew it
  /// (still on the view, since the next frame's camera is set in the next
  /// tick). Shows the capture from the first completed one on.
  void _captured() {
    final texture = target.texture;
    if (texture == null) return;
    final viewProjection = view.camera.getViewTransform(
      Size(target.width.toDouble(), target.height.toDouble()),
    );
    material.parameters
      ..setTexture('capture', texture, sampler: target.sampledSampler)
      ..setMat4('capture_view_projection', viewProjection)
      ..setFloat('capture_ready', 1);
    if (!_wearing) _wear();
  }

  void _wear() {
    final own = _ownMesh;
    if (own == null) return;
    node.mesh = Mesh.primitives(primitives: [
      for (final p in own.primitives)
        MeshPrimitive(p.geometry, material)
          ..visible = p.visible
          ..castsShadow = p.castsShadow,
    ]);
    node.layers = kCustomMirrorLayer;
    _wearing = true;
    final scene = _scene;
    if (scene != null) unawaited(prewarmPipelines(scene, view.camera));
  }

  void _sleep(HotelContext ctx) {
    if (!active) return;
    _scene?.views.remove(view);
    active = false;
  }

  void dispose(HotelContext ctx) {
    _sleep(ctx);
    target.removeListener(_captured);
    final own = _ownMesh;
    if (own != null && !identical(node.mesh, own)) node.mesh = own;
    node.layers = _ownLayers;
    _wearing = false;
    ctx.reflectionCaptures.unregister(owner, node);
  }

  /// Whether [n] and every ancestor are visible (occlusion hides an unseen
  /// mirror, portal culling a whole room).
  static bool _shown(Node n) {
    for (Node? at = n; at != null; at = at.parent) {
      if (!at.visible) return false;
    }
    return true;
  }
}
