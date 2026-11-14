import 'package:flutter/material.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:flutter_scene/scene.dart' show releaseTransientRenderTargets;

import '../../island/scene_app.dart';
import '../deck_theme.dart';

/// Live 3D Island scene wrapper for Slide 18 inside [DeckDemoFrame].
///
/// Embeds [IslandSceneScreen] under [kIslandTheme] with stripped host window
/// padding plus a subtle stage-safe inset so HUD controls clear the rounded
/// demo border cleanly while the 3D `SceneView` renders edge-to-edge.
/// Gracefully falls back to `deck-images/dash-multi-surface-3d.png` when
/// Flutter GPU / Impeller is unavailable (e.g., headless `flutter test`).
class IslandDeckDemo extends StatefulWidget {
  const IslandDeckDemo({super.key});

  @override
  State<IslandDeckDemo> createState() => _IslandDeckDemoState();
}

class _IslandDeckDemoState extends State<IslandDeckDemo> {
  static const EdgeInsets _kStageHudInset = EdgeInsets.all(8);
  late final bool _gpuAvailable = _probeGpuContext();

  static bool _probeGpuContext() {
    try {
      gpu.gpuContext;
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    if (_gpuAvailable) {
      try {
        final bytes = releaseTransientRenderTargets();
        debugPrint(
          'island deck demo: disposed, released '
          '${(bytes / 1048576).toStringAsFixed(1)} MB of transient GPU targets',
        );
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_gpuAvailable) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'deck-images/dash-multi-surface-3d.png',
            fit: BoxFit.cover,
          ),
          Positioned(
            bottom: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: GdeColors.navy.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: GdeColors.hGreen, width: 2),
              ),
              child: Text(
                '3D ISLAND · LAUNCH WITH --enable-flutter-gpu',
                style: GdeFonts.mono(
                  size: 15,
                  weight: FontWeight.w700,
                  color: GdeColors.hGreen,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Theme(
      data: kIslandTheme,
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeBottom: true,
        removeLeft: true,
        removeRight: true,
        child: Builder(
          builder: (innerContext) {
            final mq = MediaQuery.of(innerContext);
            return MediaQuery(
              data: mq.copyWith(
                padding: _kStageHudInset,
                viewPadding: _kStageHudInset,
              ),
              child: const IslandSceneScreen(),
            );
          },
        ),
      ),
    );
  }
}
