import 'package:flutter/material.dart';
import 'package:flutter_3d/home/shader_backdrop.dart';

import '../deck_theme.dart';

/// Named labels corresponding to [kSeaLevels] (`[0.1, 0.3, 0.5, 0.75, 1.0]`).
const List<String> _kSeaLevelLabels = [
  'Calm',
  'Gentle',
  'Swell',
  'Rough',
  'Storm',
];

/// Interactive GLSL fragment shader demo for Slide 01 (Cover).
///
/// - Dragging horizontally pans the ray-marched ocean horizon (`look`).
/// - Tapping the canvas (or the wave chip) steps wave height (`Calm` → `Storm`).
/// - Bottom-right overlay chips switch `🌊 Sea Shader` ↔ `☁️ Sky Shader`.
class CoverShaderDemo extends StatefulWidget {
  const CoverShaderDemo({super.key});

  @override
  State<CoverShaderDemo> createState() => _CoverShaderDemoState();
}

class _CoverShaderDemoState extends State<CoverShaderDemo> {
  HomeShader _shader = HomeShader.sea;
  int _waveIndex = 2; // Starts at 0.5 ('Swell') for lively rolling waves
  double _look = 0.0;
  bool _dragging = false;

  late final ValueNotifier<SeaInput> _sea = ValueNotifier<SeaInput>((
    look: _look,
    height: kSeaLevels[_waveIndex],
  ));

  @override
  void dispose() {
    _sea.dispose();
    super.dispose();
  }

  void _syncSea() {
    _sea.value = (look: _look, height: kSeaLevels[_waveIndex]);
  }

  void _stepWave() {
    setState(() {
      _waveIndex = (_waveIndex + 1) % kSeaLevels.length;
      _syncSea();
    });
  }

  void _toggleShader() {
    setState(() {
      _shader = _shader == HomeShader.sea ? HomeShader.sky : HomeShader.sea;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSea = _shader == HomeShader.sea;

    return Stack(
      fit: StackFit.expand,
      children: [
        MouseRegion(
          cursor: isSea
              ? (_dragging
                    ? SystemMouseCursors.grabbing
                    : SystemMouseCursors.grab)
              : SystemMouseCursors.basic,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: isSea ? _stepWave : null,
            onHorizontalDragStart: isSea
                ? (_) => setState(() => _dragging = true)
                : null,
            onHorizontalDragUpdate: isSea
                ? (details) {
                    _look -= details.delta.dx * 0.0045;
                    _syncSea();
                  }
                : null,
            onHorizontalDragEnd: isSea
                ? (_) => setState(() => _dragging = false)
                : null,
            onHorizontalDragCancel: isSea
                ? () => setState(() => _dragging = false)
                : null,
            child: ShaderBackdrop(
              key: ValueKey(_shader),
              shader: _shader,
              sea: _sea,
            ),
          ),
        ),

        // Bottom-right interactive shader & wave controls
        Positioned(
          bottom: 22,
          right: 22,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSea) ...[
                _OverlayChip(
                  onTap: _stepWave,
                  borderColor: GdeColors.hBlue,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _WaveBars(activeIndex: _waveIndex),
                      const SizedBox(width: 10),
                      Text(
                        _kSeaLevelLabels[_waveIndex],
                        style: GdeFonts.mono(
                          size: 16,
                          weight: FontWeight.w700,
                          color: GdeColors.hBlue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],
              _OverlayChip(
                onTap: _toggleShader,
                borderColor: GdeColors.hGreen,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isSea ? '🌊 Sea Shader' : '☁️ Sky Shader',
                      style: GdeFonts.mono(
                        size: 16,
                        weight: FontWeight.w700,
                        color: GdeColors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.swap_horiz_rounded,
                      size: 18,
                      color: GdeColors.hGreen,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverlayChip extends StatelessWidget {
  const _OverlayChip({
    required this.onTap,
    required this.borderColor,
    required this.child,
  });

  final VoidCallback onTap;
  final Color borderColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: GdeColors.navy.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor, width: 2.5),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _WaveBars extends StatelessWidget {
  const _WaveBars({required this.activeIndex});

  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < kSeaLevels.length; i++)
          Container(
            width: 4,
            height: 6.0 + i * 3.0,
            margin: EdgeInsets.only(right: i < kSeaLevels.length - 1 ? 3 : 0),
            decoration: BoxDecoration(
              color: i <= activeIndex ? GdeColors.hBlue : GdeColors.navyMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }
}
