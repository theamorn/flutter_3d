import 'dart:async';

import 'package:flutter/material.dart' hide Material;
import 'package:flutter_scene/scene.dart'
    show
        GpuTextureSource,
        Material,
        Mesh,
        Node,
        PreprocessedMaterial,
        UnlitMaterial,
        WidgetComponent,
        WidgetInput,
        WidgetUpdatePolicy,
        loadFmatMaterial;
import 'package:vector_math/vector_math.dart' show Vector3;
import 'package:webview_flutter/webview_flutter.dart';
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import '../ui/screen_overlay.dart';
import 'interaction_registry.dart';
import 'player_feature.dart';

/// What the TV and PC open (confirmed with the user, 2026-09-27).
const kTvUrl = 'https://www.youtube.com/@GoogleDevelopers';
const kPcUrl = 'https://www.facebook.com/GoogleDevelopersThailand';

/// Retro CRT / VHS glass shader adapted from `bdero/flutter_scene`'s
/// `crt_effect.fmat`.
const kCrtScreenFmat = 'assets/materials/crt_screen.fmat';

/// The two screens in each room: node name, page, tap label, poster.
const _kinds = [
  (
    name: 'tv_screen',
    url: kTvUrl,
    tap: 'Watch TV',
    icon: Icons.play_arrow_rounded,
    poster: 'Tap to watch',
    vhs: 0.38,
    distortion: 0.14,
  ),
  (
    name: 'pc_screen',
    url: kPcUrl,
    tap: 'Open PC',
    icon: Icons.open_in_browser,
    poster: 'Tap to open',
    vhs: 0.14,
    distortion: 0.06,
  ),
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
/// The screens show a captured poster rendered through a live lit CRT/VHS
/// glass shader (`crt_screen.fmat`); a tap glides the camera square onto the
/// screen and lays the live page over its projected quad.
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
  final List<PreprocessedMaterial> _crtMaterials = [];
  final FocusEase _ease = FocusEase();
  _Screen? _focused;
  double _time = 0;

  @override
  Future<void> mount(HotelContext ctx) async {
    _time = 0;
    for (final kind in _kinds) {
      final nodes = ctx.nodesNamed(kind.name);
      if (nodes.isEmpty) continue;
      PreprocessedMaterial? crt;
      try {
        crt = await loadFmatMaterial(kCrtScreenFmat);
        crt.parameters
          ..setFloat('vhs_intensity', kind.vhs)
          ..setFloat('distortion', kind.distortion);
        _crtMaterials.add(crt);
      } on Object {
        // Fallback when running in headless tests without compiled shader assets.
        crt = null;
      }
      final fallback = UnlitMaterial();
      final Material activeMaterial = crt ?? fallback;
      final screens = [
        for (final node in nodes)
          _Screen(
            node,
            ScreenQuad.fromMesh(node.mesh!.primitives.single.geometry.extractMeshData(), node.globalTransform),
            kind.url,
            node.mesh!,
            // MeshPrimitive.material = x alone doesn't reach a mounted node's
            // render items; assigning a mesh with the same geometry does.
            node.mesh!.clone()..primitives.single.material = activeMaterial,
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
          if (crt != null) {
            crt.parameters.setTexture('screen_texture', texture);
          } else {
            fallback.baseColorTexture = GpuTextureSource(texture);
          }
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
    if (dt > 0) {
      _time += dt;
      for (final crt in _crtMaterials) {
        crt.parameters.setFloat('time', _time);
      }
    }
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
    _crtMaterials.clear();
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

/// The frame a screen shows until it's tapped: a glowing broadcast card with
/// subtle SMPTE color accents so `crt_screen.fmat`'s scanlines, phosphor
/// triads, and VHS tracking wave read clearly. Opaque everywhere (traps.md 39).
class _PosterCard extends StatelessWidget {
  const _PosterCard({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            radius: 0.95,
            colors: [Color(0xFF16243A), Color(0xFF05070C)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 18,
              child: Row(
                children: const [
                  Expanded(child: ColoredBox(color: Color(0xFFE53935))),
                  Expanded(child: ColoredBox(color: Color(0xFFFB8C00))),
                  Expanded(child: ColoredBox(color: Color(0xFFFDD835))),
                  Expanded(child: ColoredBox(color: Color(0xFF43A047))),
                  Expanded(child: ColoredBox(color: Color(0xFF00ACC1))),
                  Expanded(child: ColoredBox(color: Color(0xFF3949AB))),
                ],
              ),
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xCC0A101D),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF4FC3F7), width: 2.5),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, color: const Color(0xFF80D8FF), size: 68),
                  const SizedBox(width: 14),
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none)),
                ]),
              ),
            ),
          ],
        ),
      );
}
