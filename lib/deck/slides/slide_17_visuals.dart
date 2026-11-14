import 'package:flutter/material.dart';
import 'package:flutter_deck/flutter_deck.dart';

import '../deck_theme.dart';
import '../demos/holo_lanyard/holo_card_game.dart';
import '../demos/holo_lanyard/holo_lanyard_demo.dart';
import '../widgets/deck_demo_frame.dart';

/// Slide 17 — Visualization as the Product + Live Holographic Lanyard Demo.
class Slide17Widget extends FlutterDeckSlideWidget {
  const Slide17Widget({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/slide-17',
          title: '17 · Shared GPU Canvas (Holo Lanyard)',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => GdeSlideCanvas(
        slideNumber: 17,
        isNavy: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left column (1.08fr)
            Expanded(
              flex: 108,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'VISUALIZATION AS THE PRODUCT',
                        style: GdeFonts.monoSub(),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Brand Experiences Demand One Shared GPU Canvas.',
                        style: GdeFonts.headline(size: 66),
                      ),
                    ],
                  ),

                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _BulletPill(
                        backgroundColor: GdeColors.pinkTint,
                        boldLead: 'RealityKit and Filament',
                        rest: 'feel visibly different',
                      ),
                      SizedBox(height: 22),
                      _BulletPill(
                        backgroundColor: GdeColors.blueTint,
                        boldLead: 'Shaders and physics',
                        rest: 'must match exactly',
                      ),
                      SizedBox(height: 22),
                      _BulletPill(
                        backgroundColor: GdeColors.greenTint,
                        boldLead: 'Shared C++ engines',
                        rest: 'recreate cross-platform tradeoffs',
                      ),
                    ],
                  ),

                  GdePillBox(
                    backgroundColor: GdeColors.blue,
                    borderColor: GdeColors.navy,
                    borderWidth: 3,
                    borderRadius: 20,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 12,
                    ),
                    child: Text(
                      '{ GLSL + 3D }',
                      style: GdeFonts.mono(
                        size: 36,
                        weight: FontWeight.w800,
                        color: GdeColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 56),

            // Right column (0.92fr) — Live Holographic Lanyard Showcase
            Expanded(
              flex: 92,
              child: DeckDemoFrame(
                height: 840,
                borderColor: GdeColors.navy,
                borderRadius: 40,
                backgroundColor: HoloCardGame.backdropColor,
                fallbackAsset: 'deck-images/ios-vs-android-animation.png',
                hintLabel: 'DRAG & FLING LANYARD · TAP TO FLIP',
                bottomLeftOverlay: IgnorePointer(
                  child: GdePillBox(
                    backgroundColor: GdeColors.hPink,
                    borderColor: GdeColors.navy,
                    borderWidth: 3,
                    borderRadius: 28,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 12,
                    ),
                    child: Text(
                      'Swift/RealityKit ≠ Kotlin/Filament',
                      style: GdeFonts.mono(
                        size: 22,
                        weight: FontWeight.w700,
                        color: GdeColors.navy,
                      ),
                    ),
                  ),
                ),
                liveBuilder: (context) => const HoloLanyardDemo(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BulletPill extends StatelessWidget {
  const _BulletPill({
    required this.backgroundColor,
    required this.boldLead,
    required this.rest,
  });

  final Color backgroundColor;
  final String boldLead;
  final String rest;

  @override
  Widget build(BuildContext context) {
    return GdePillBox(
      backgroundColor: backgroundColor,
      borderColor: GdeColors.navy,
      borderWidth: 3,
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 22),
      child: GdeBulletText(
        boldLead: boldLead,
        rest: rest,
        fontSize: 32,
      ),
    );
  }
}
