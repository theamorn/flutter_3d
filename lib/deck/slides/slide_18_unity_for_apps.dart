import 'package:flutter/material.dart';
import 'package:flutter_deck/flutter_deck.dart';

import '../deck_theme.dart';
import '../demos/island_deck_demo.dart';
import '../widgets/deck_demo_frame.dart';

/// Slide 18 — “Unity for Apps” + Live 3D Island Demo.
///
/// Ports Slide 18 from `Flutter in the AI Agent Era (Light).html` (1.08fr :
/// 0.92fr navy split with top/bottom scalloped green arches and a live
/// `flutter_gpu` + `flutter_scene` 3D Island canvas on the right).
class Slide18Widget extends FlutterDeckSlideWidget {
  const Slide18Widget({super.key})
      : super(
          configuration: const FlutterDeckSlideConfiguration(
            route: '/slide-18',
            title: '18 · Unity for Apps (3D Island Demo)',
          ),
        );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => GdeSlideCanvas(
        slideNumber: 18,
        isNavy: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 108,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const _ScallopedGreenArches(inverted: false),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '“UNITY FOR APPS” · LIVE DEMOS NEXT',
                        style: GdeFonts.monoSub(color: GdeColors.hGreen),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Flutter Embeds Multiple 3D Canvases Inside Native.',
                        style: GdeFonts.headline(size: 66, isNavy: true),
                      ),
                    ],
                  ),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GdeBulletText(
                        boldLead: 'Flutter GPU renders',
                        rest: 'real-time 3D scenes',
                        fontSize: 35,
                        color: GdeColors.white,
                        boldColor: GdeColors.hBlue,
                      ),
                      SizedBox(height: 22),
                      GdeBulletText(
                        boldLead: 'FlutterEngineGroup adds',
                        rest: 'views at 180kB each',
                        fontSize: 35,
                        color: GdeColors.white,
                        boldColor: GdeColors.hGreen,
                      ),
                      SizedBox(height: 22),
                      GdeBulletText(
                        boldLead: 'Stac streams live',
                        rest: 'server-driven 3D UI',
                        fontSize: 35,
                        color: GdeColors.white,
                        boldColor: GdeColors.hYellow,
                      ),
                    ],
                  ),
                  const _ScallopedGreenArches(inverted: true),
                ],
              ),
            ),
            const SizedBox(width: 56),
            Expanded(
              flex: 92,
              child: DeckDemoFrame(
                height: 840,
                borderColor: GdeColors.hGreen,
                borderRadius: 48,
                fallbackAsset: 'deck-images/dash-multi-surface-3d.png',
                hintLabel: null,
                liveBuilder: (_) => const IslandDeckDemo(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Five scalloped green arches matching Slide 18's top/bottom `<svg>` waves:
/// `viewBox="0 0 680 64"` with `stroke="#34a853"` and `stroke-width="5"`.
class _ScallopedGreenArches extends StatelessWidget {
  const _ScallopedGreenArches({required this.inverted});

  final bool inverted;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 680,
        height: 64,
        child: CustomPaint(
          painter: _ScallopedArchesPainter(inverted: inverted),
        ),
      ),
    );
  }
}

class _ScallopedArchesPainter extends CustomPainter {
  const _ScallopedArchesPainter({required this.inverted});

  final bool inverted;

  static const List<double> _archEnds = <double>[138, 272, 406, 540, 674];

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 680;
    final sy = size.height / 64;
    canvas.save();
    canvas.scale(sx, sy);

    final y = inverted ? 4.0 : 60.0;
    final path = Path()..moveTo(4, y);
    for (final endX in _archEnds) {
      path.arcToPoint(
        Offset(endX, y),
        radius: const Radius.elliptical(66, 60),
        largeArc: false,
        clockwise: !inverted,
      );
    }

    final paint = Paint()
      ..color = GdeColors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ScallopedArchesPainter oldDelegate) =>
      oldDelegate.inverted != inverted;
}
