import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../deck_theme.dart';
import 'holo_card_game.dart';

/// Standalone interactive Holographic Lanyard showcase widget for macOS slides.
class HoloLanyardDemo extends StatefulWidget {
  const HoloLanyardDemo({super.key});

  @override
  State<HoloLanyardDemo> createState() => _HoloLanyardDemoState();
}

class _HoloLanyardDemoState extends State<HoloLanyardDemo> {
  String? _claimedCode;

  late final HoloCardGame _game = HoloCardGame(
    onClaim: (code) {
      if (!mounted) return;
      setState(() => _claimedCode = code);
    },
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: HoloCardGame.backdropColor,
          child: GameWidget<HoloCardGame>(game: _game),
        ),

        // Claimed status chip (floats above bottom-right Impulse control)
        Positioned(
          bottom: 86,
          right: 20,
          child: IgnorePointer(
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutBack,
              offset: _claimedCode != null ? Offset.zero : const Offset(0, 0.4),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 240),
                opacity: _claimedCode != null ? 1 : 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: GdeColors.navy.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: GdeColors.hYellow, width: 2.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(
                    '🎟️ ${_claimedCode ?? HoloCardGame.promoCode} CLAIMED · 20% OFF',
                    style: GdeFonts.mono(
                      size: 16,
                      weight: FontWeight.w700,
                      color: GdeColors.hYellow,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Subtle presenter [ Impulse ] flick button (bottom-right)
        Positioned(
          bottom: 24,
          right: 20,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _game.hostScrolled(0.5, 900),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: GdeColors.navy.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: GdeColors.hBlue, width: 2),
                ),
                child: Text(
                  '[ Impulse ]',
                  style: GdeFonts.mono(
                    size: 16,
                    weight: FontWeight.w700,
                    color: GdeColors.hBlue,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
