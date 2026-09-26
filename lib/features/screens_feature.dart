import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart'
    show GpuTextureSource, Mesh, Node, UnlitMaterial, WidgetComponent, WidgetInput, WidgetUpdatePolicy;
import 'package:vector_math/vector_math.dart' show Vector3;
import 'package:webview_flutter/webview_flutter.dart';
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import '../ui/screen_overlay.dart';
import 'interaction_registry.dart';
import 'player_feature.dart';

const kTvUrl = 'https://www.youtube.com/@GoogleDevelopers';       // TODO(user): replace with the real channel
const kPcUrl = 'https://www.facebook.com/GoogleDevelopersThailand'; // TODO(user): replace with the real page

/// The two screens in each room: node name, page, tap label, poster.
const _kinds = [
  (name: 'tv_screen', url: kTvUrl, tap: 'Watch TV', icon: Icons.play_arrow_rounded, poster: 'Tap to watch'),
  (name: 'pc_screen', url: kPcUrl, tap: 'Open PC', icon: Icons.open_in_browser, poster: 'Tap to open'),
];

/// Poster capture height, logical px (the TV's is 640 × 360).
const double _posterHeight = 360;

/// One screen in one room.
class _Screen {
  _Screen(this.node, this.quad, this.url, this.roomMesh, this.posterMesh);
  final Node node;
  final ScreenQuad quad;
  final String url;

  /// The room's own mesh, put back on unmount, and the same geometry with
  /// the poster material.
  final Mesh roomMesh, posterMesh;
  Interactable? tap;
}

/// What the overlay shows while a screen is focused.
class _Focus {
  _Focus(this.corners, this.controller, this.close);
  final List<Vector3> corners;
  final WebViewController controller;
  final VoidCallback close;
}

/// Engine rule 7: a WebView is a platform view and can't be a mesh texture.
/// The screens show a captured poster; a tap glides the camera square onto
/// the screen and lays the live page over its projected quad.
class ScreensFeature extends HotelFeature {
  @override
  String get id => 'screens';
  @override
  String get label => 'TV + PC screens';
  @override
  CostTier get tier => CostTier.free;
  @override
  bool get toggleable => false;

  static final ValueNotifier<_Focus?> _focus = ValueNotifier(null);

  /// The SceneView's size, as the overlay last laid out (full screen).
  static Size _viewport = Size.zero;

  final List<_Screen> _screens = [];
  final List<(Node, WidgetComponent)> _posters = [];
  final FocusEase _ease = FocusEase();
  _Screen? _focused;

  @override
  Future<void> mount(HotelContext ctx) async {
    for (final kind in _kinds) {
      final nodes = ctx.nodesNamed(kind.name);
      if (nodes.isEmpty) continue;
      final material = UnlitMaterial();
      final screens = [
        for (final node in nodes)
          _Screen(
            node,
            ScreenQuad.fromMesh(node.mesh!.primitives.single.geometry.extractMeshData(), node.globalTransform),
            kind.url,
            node.mesh!,
            // MeshPrimitive.material = x alone doesn't reach a mounted node's
            // render items; assigning a mesh with the same geometry does.
            node.mesh!.clone()..primitives.single.material = material,
          ),
      ];
      _screens.addAll(screens);
      // One capture per kind, bound to both rooms: room B's quad is built
      // with u flipped (d63cf81), so the same texture reads left to right.
      final quad = screens.first.quad;
      final poster = WidgetComponent.bindOnly(
        child: _PosterCard(icon: kind.icon, label: kind.poster),
        size: Size((_posterHeight * quad.width / quad.height).roundToDouble(), _posterHeight),
        update: WidgetUpdatePolicy.manual,
        input: WidgetInput.manual, // taps belong to the interactable
        bind: (texture) {
          material.baseColorTexture = GpuTextureSource(texture);
          // Swapped in on the first capture, so the screen stays the room's
          // black instead of flashing the unlit white placeholder.
          for (final s in screens) {
            s.node.mesh = s.posterMesh;
          }
        },
      );
      nodes.first.addComponent(poster);
      _posters.add((nodes.first, poster));
      _requestPoster(poster);
      for (final s in screens) {
        s.tap = Interactable(node: s.node, label: kind.tap, onTap: () => _enter(ctx, s));
        ctx.interactions.register(s.tap!);
      }
    }
  }

  /// A manual-policy capture request made before SceneView hosts the poster
  /// (it does so on the frame after mount) is dropped, so ask after each
  /// frame until the first capture lands.
  static void _requestPoster(WidgetComponent poster, [int frames = 60]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!poster.isAttached || poster.controller.captureCount > 0 || frames == 0) return;
      poster.controller.requestCapture();
      _requestPoster(poster, frames - 1);
    });
  }

  void _enter(HotelContext ctx, _Screen s) {
    // One owner of the camera at a time.
    if (PlayerFeature.focusLocked) return;
    final cam = ctx.camera;
    final pose = s.quad.focusPose(focusDistance(s.quad, fovY: cam.fovRadiansY, viewport: _viewport));
    if (!_ease.enter(CameraPose(cam.position.clone(), cam.target.clone()), pose)) return;
    _focused = s;
    PlayerFeature.focusLocked = true;
  }

  @override
  void tick(HotelContext ctx, double dt) {
    final was = _ease.phase;
    final pose = _ease.step(dt);
    if (pose == null) return;
    ctx.camera.position = pose.eye.clone();
    ctx.camera.target = pose.target.clone();
    if (was == FocusPhase.entering && _ease.phase == FocusPhase.focused) {
      final s = _focused!;
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black);
      unawaited(controller.loadRequest(Uri.parse(s.url)));
      _focus.value = _Focus(s.quad.corners, controller, _close);
    } else if (was == FocusPhase.leaving && _ease.phase == FocusPhase.idle) {
      _focused = null;
      PlayerFeature.focusLocked = false;
    }
  }

  /// ✕: drop the page and glide back to where the player stood.
  void _close() {
    if (_ease.leave()) _closePage();
  }

  static void _closePage() {
    final controller = _focus.value?.controller;
    _focus.value = null;
    // The native view outlives its widget until the controller is collected,
    // and a playing video keeps its sound, so blank it now.
    if (controller != null) unawaited(controller.loadRequest(Uri.parse('about:blank')));
  }

  @override
  void unmount(HotelContext ctx) {
    _closePage();
    final home = _ease.reset();
    if (home != null) {
      // Interrupted mid-focus: hand the camera and the walk back.
      ctx.camera.position = home.eye.clone();
      ctx.camera.target = home.target.clone();
      PlayerFeature.focusLocked = false;
    }
    _focused = null;
    // First, so a late capture can't re-bind the poster.
    for (final (node, poster) in _posters) {
      node.removeComponent(poster);
    }
    _posters.clear();
    for (final s in _screens) {
      final tap = s.tap;
      if (tap != null) ctx.interactions.unregister(tap);
      s.node.mesh = s.roomMesh;
    }
    _screens.clear();
  }

  /// The focused page over its screen (placed by HotelPage).
  static Widget overlay(HotelContext ctx) => LayoutBuilder(builder: (context, box) {
        _viewport = box.biggest;
        return ValueListenableBuilder<_Focus?>(
          valueListenable: _focus,
          builder: (context, focus, _) {
            if (focus == null) return const SizedBox.shrink();
            final cam = ctx.camera;
            final rect = projectedBounds(focus.corners,
                eye: cam.position, target: cam.target, up: cam.up, fovY: cam.fovRadiansY, viewport: box.biggest);
            if (rect == null) return const SizedBox.shrink();
            return ScreenOverlay(
              bounds: rect,
              onClose: focus.close,
              child: WebViewWidget(key: ObjectKey(focus.controller), controller: focus.controller),
            );
          },
        );
      });
}

/// The still frame a screen shows until it's tapped: black, with a label.
/// Opaque everywhere, so no dark fringes on the capture (traps.md 39).
class _PosterCard extends StatelessWidget {
  const _PosterCard({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Colors.black,
        child: Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white, size: 72),
            const SizedBox(width: 12),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontSize: 44, decoration: TextDecoration.none)),
          ]),
        ),
      );
}
