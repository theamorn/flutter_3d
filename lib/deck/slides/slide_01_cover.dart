import 'package:flutter/material.dart';
import 'package:flutter_deck/flutter_deck.dart';

import '../deck_theme.dart';
import '../demos/cover_shader_demo.dart';
import '../widgets/deck_demo_frame.dart';

/// Slide 01: GDE Chapter Hero with live ray-marched GLSL Sea & Sky shaders.
class Slide01Widget extends FlutterDeckSlideWidget {
  const Slide01Widget({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/slide-01',
          initial: true,
          title: '01 · Cover',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => GdeSlideCanvas(
        slideNumber: 1,
        isNavy: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left column (flex: 110): Brand header, 102px title, speaker pills
            Expanded(
              flex: 110,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const GdeBrandHeader(
                    label: 'Google Developer Group · DevFest 2026',
                    isNavy: true,
                  ),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'FLUTTER IN THE AI AGENT ERA',
                        style: GdeFonts.monoSub(isNavy: true),
                      ),
                      const SizedBox(height: 20),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: RichText(
                          text: TextSpan(
                            style: GdeFonts.sans(
                              size: 102,
                              weight: FontWeight.w400,
                              color: GdeColors.white,
                              height: 1.04,
                              letterSpacing: -2.5,
                            ),
                            children: [
                              const TextSpan(text: 'Why Build '),
                              TextSpan(
                                text: 'Once',
                                style: GdeFonts.sans(
                                  size: 102,
                                  weight: FontWeight.w800,
                                  color: GdeColors.hBlue,
                                  height: 1.04,
                                  letterSpacing: -2.5,
                                ),
                              ),
                              const TextSpan(text: '\nWhen AI Can\nBuild '),
                              TextSpan(
                                text: 'Twice?',
                                style: GdeFonts.sans(
                                  size: 102,
                                  weight: FontWeight.w800,
                                  color: GdeColors.hPink,
                                  height: 1.04,
                                  letterSpacing: -2.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const _SpeakerOverlappingPills(),
                ],
              ),
            ),

            const SizedBox(width: 64),

            // Right column (flex: 90): Live GLSL Shader Demo Frame
            Expanded(
              flex: 90,
              child: DeckDemoFrame(
                height: 860,
                borderRadius: 48,
                borderColor: GdeColors.hGreen,
                fallbackAsset: 'deck-images/cover-zen.png',
                hintLabel: 'DRAG HORIZON · TAP WAVE',
                liveBuilder: (_) => const CoverShaderDemo(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeakerOverlappingPills extends StatelessWidget {
  const _SpeakerOverlappingPills();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          decoration: BoxDecoration(
            color: GdeColors.hBlue,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: GdeColors.navy, width: 3),
          ),
          child: Text(
            'Amorn Apichattanakul',
            style: GdeFonts.sans(
              size: 28,
              weight: FontWeight.w800,
              color: GdeColors.navy,
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
            decoration: BoxDecoration(
              color: GdeColors.navyDark,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: GdeColors.hBlue, width: 2),
            ),
            child: Text(
              'Senior Innovation Engineer @KBTG',
              style: GdeFonts.mono(
                size: 20,
                weight: FontWeight.w600,
                color: GdeColors.hBlue,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
