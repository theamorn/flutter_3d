import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart' hide Material;

import '../../deck_theme.dart';
import 'product_scene.dart';

/// Interactive live 3D Nimbus One headphones showcase for Slide 05.
///
/// Renders procedural curved-metal headphones via `flutter_scene` + Flutter GPU
/// over the signature `#5856D6` → `#AF52DE` gradient, with drag-to-orbit
/// inertia, live yaw readout, auto-spin toggle, and 1-click pose reset.
class HeadphonesDemo extends StatefulWidget {
  const HeadphonesDemo({super.key});

  static const LinearGradient gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5856D6), Color(0xFFAF52DE)],
  );

  @override
  State<HeadphonesDemo> createState() => _HeadphonesDemoState();
}

class _HeadphonesDemoState extends State<HeadphonesDemo> {
  final ProductScene _product = ProductScene();
  late final ValueNotifier<int> _yawDeg = ValueNotifier<int>(
    _product.yawDegrees,
  );

  bool _dragging = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _product.load().then(
      (_) {
        if (!mounted) return;
        _yawDeg.value = _product.yawDegrees;
        setState(() {});
      },
      onError: (Object error) {
        debugPrint('headphones demo: load failed: $error');
        if (mounted) setState(() => _error = error);
      },
    );
  }

  @override
  void dispose() {
    _yawDeg.dispose();
    _product.dispose();
    super.dispose();
  }

  void _onTick(Duration _, double dt) {
    _product.tick(dt);
    final deg = _product.yawDegrees;
    if (_yawDeg.value != deg) {
      _yawDeg.value = deg;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: HeadphonesDemo.gradient),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (_error != null) {
            return const _HeadphonesFallback();
          }
          if (!_product.loaded) {
            return const _HeadphonesLoading();
          }

          final height = constraints.maxHeight;
          return Stack(
            fit: StackFit.expand,
            children: [
              MouseRegion(
                cursor: _dragging
                    ? SystemMouseCursors.grabbing
                    : SystemMouseCursors.grab,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) {
                    setState(() => _dragging = true);
                    _product.dragStart();
                  },
                  onPanUpdate: (details) {
                    _product.dragUpdate(details.delta, height);
                    _yawDeg.value = _product.yawDegrees;
                  },
                  onPanEnd: (details) {
                    setState(() => _dragging = false);
                    _product.dragEnd(details.velocity.pixelsPerSecond, height);
                  },
                  onPanCancel: () {
                    setState(() => _dragging = false);
                    _product.dragEnd(Offset.zero, height);
                  },
                  child: SceneView(
                    _product.scene,
                    onTick: _onTick,
                    warmUp: true,
                  ),
                ),
              ),

              // Subtle bottom-right telemetry & turntable controls
              Positioned(
                bottom: 20,
                right: 20,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: GdeColors.navy.withValues(alpha: 0.84),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: GdeColors.hBlue, width: 2),
                      ),
                      child: ValueListenableBuilder<int>(
                        valueListenable: _yawDeg,
                        builder: (context, deg, _) {
                          final sign = deg >= 0 ? '+' : '';
                          return Text(
                            'YAW $sign$deg°',
                            style: GdeFonts.mono(
                              size: 15,
                              weight: FontWeight.w700,
                              color: GdeColors.hBlue,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    _ControlPill(
                      label: _product.autoSpin ? '⟳ Spin ON' : '⏸ Spin OFF',
                      borderColor: _product.autoSpin
                          ? GdeColors.hGreen
                          : GdeColors.slate300,
                      textColor: _product.autoSpin
                          ? GdeColors.hGreen
                          : GdeColors.white,
                      onTap: () {
                        setState(() => _product.toggleAutoSpin());
                      },
                    ),
                    const SizedBox(width: 10),
                    _ControlPill(
                      label: '↺ Reset',
                      borderColor: GdeColors.white,
                      textColor: GdeColors.white,
                      onTap: () {
                        _product.resetPose();
                        _yawDeg.value = _product.yawDegrees;
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ControlPill extends StatelessWidget {
  const _ControlPill({
    required this.label,
    required this.borderColor,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final Color borderColor;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          decoration: BoxDecoration(
            color: GdeColors.navy.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Text(
            label,
            style: GdeFonts.mono(
              size: 15,
              weight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeadphonesLoading extends StatelessWidget {
  const _HeadphonesLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'BUILDING 3D NIMBUS ONE · FLUTTER GPU',
            style: GdeFonts.mono(
              size: 16,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeadphonesFallback extends StatelessWidget {
  const _HeadphonesFallback();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.headphones_rounded, size: 96, color: Colors.white),
          const SizedBox(height: 14),
          Text(
            'NIMBUS ONE · 3D GPU PREVIEW',
            style: GdeFonts.mono(
              size: 16,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
