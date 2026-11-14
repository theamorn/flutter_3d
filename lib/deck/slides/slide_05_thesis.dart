import 'package:flutter/material.dart';
import 'package:flutter_deck/flutter_deck.dart';

import '../deck_theme.dart';
import '../demos/headphones_3d/headphones_demo.dart';
import '../widgets/deck_demo_frame.dart';

/// Slide 05: Core Thesis with all thesis points stacked cleanly on the left
/// and the live interactive 3D Nimbus One headphones demo on the right.
class Slide05Widget extends FlutterDeckSlideWidget {
  const Slide05Widget({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/slide-05',
          title: '05 · Core Thesis (3D Headphones)',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => GdeSlideCanvas(
        slideNumber: 5,
        isNavy: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top header
            Text('CORE THESIS', style: GdeFonts.monoSub()),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Flutter Owns the Pixels in One Codebase.',
                style: GdeFonts.headline(size: 66),
              ),
            ),
            const SizedBox(height: 28),

            // Asymmetric 2-column content + live 3D showcase
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left column (flex: 108): Both thesis sections + GDE motif
                  Expanded(
                    flex: 108,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Section 1: 01 · GPU Pixel Ownership
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '01 · GPU Pixel Ownership',
                              style: GdeFonts.sans(
                                size: 38,
                                weight: FontWeight.w800,
                                color: GdeColors.navy,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const SizedBox(
                              width: double.infinity,
                              child: GdePillBox(
                                backgroundColor: GdeColors.blueTint,
                                borderColor: GdeColors.navy,
                                borderRadius: 22,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 16,
                                ),
                                child: GdeBulletText(
                                  boldLead: 'Renders custom pixels',
                                  rest: 'on the GPU',
                                  fontSize: 30,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const SizedBox(
                              width: double.infinity,
                              child: GdePillBox(
                                backgroundColor: GdeColors.blueTint,
                                borderColor: GdeColors.navy,
                                borderRadius: 22,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 16,
                                ),
                                child: GdeBulletText(
                                  boldLead: 'Ships core visuals',
                                  rest: 'inside one SDK',
                                  fontSize: 30,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Section 2: 02 · Zero-Drift Workflow
                        SizedBox(
                          width: double.infinity,
                          child: GdePillBox(
                            backgroundColor: GdeColors.hBlue,
                            borderColor: GdeColors.navy,
                            borderRadius: 28,
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '02 · Zero-Drift Workflow',
                                  style: GdeFonts.sans(
                                    size: 38,
                                    weight: FontWeight.w800,
                                    color: GdeColors.navy,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const SizedBox(
                                  width: double.infinity,
                                  child: GdePillBox(
                                    backgroundColor: GdeColors.white,
                                    borderColor: GdeColors.navy,
                                    borderRadius: 20,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 28,
                                      vertical: 16,
                                    ),
                                    child: GdeBulletText(
                                      boldLead: 'Prevents platform drift',
                                      rest: 'with one codebase',
                                      fontSize: 30,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Decorative compact GDE green triple-circle union + asterisk
                        const _GdeTripleCircleMotifRow(),
                      ],
                    ),
                  ),

                  const SizedBox(width: 56),

                  // Right column (flex: 92): Live 3D Nimbus Headphones
                  Expanded(
                    flex: 92,
                    child: DeckDemoFrame(
                      height: null,
                      borderColor: GdeColors.navy,
                      borderRadius: 40,
                      hintLabel: 'DRAG TO SPIN 3D HEADPHONES',
                      liveBuilder: (_) => const HeadphonesDemo(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact signature GDE motif from HTML Slide 05 (Template page_35):
/// green triple-circle union + 8-spoke navy asterisk.
class _GdeTripleCircleMotifRow extends StatelessWidget {
  const _GdeTripleCircleMotifRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 224,
          height: 92,
          child: CustomPaint(painter: _TripleCircleUnionPainter()),
        ),
        SizedBox(width: 34),
        SizedBox(
          width: 84,
          height: 84,
          child: CustomPaint(painter: _GdeAsteriskPainter()),
        ),
      ],
    );
  }
}

class _TripleCircleUnionPainter extends CustomPainter {
  const _TripleCircleUnionPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Original SVG space: 312 × 128 with 3 circles of radius 52 at
    // x = 64, 156, 248 and y = 64.
    final sx = size.width / 312;
    final sy = size.height / 128;
    canvas.save();
    canvas.scale(sx, sy);

    final c1 = Path()
      ..addOval(Rect.fromCircle(center: const Offset(64, 64), radius: 52));
    final c2 = Path()
      ..addOval(Rect.fromCircle(center: const Offset(156, 64), radius: 52));
    final c3 = Path()
      ..addOval(Rect.fromCircle(center: const Offset(248, 64), radius: 52));

    final union = Path.combine(
      PathOperation.union,
      Path.combine(PathOperation.union, c1, c2),
      c3,
    );

    canvas.drawPath(
      union,
      Paint()
        ..color = GdeColors.hGreen
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      union,
      Paint()
        ..color = GdeColors.navy
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GdeAsteriskPainter extends CustomPainter {
  const _GdeAsteriskPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 120;
    final sy = size.height / 120;
    canvas.save();
    canvas.scale(sx, sy);

    final paint = Paint()
      ..color = GdeColors.navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    canvas
      ..drawLine(const Offset(60, 6), const Offset(60, 114), paint)
      ..drawLine(const Offset(6, 60), const Offset(114, 60), paint)
      ..drawLine(const Offset(20, 20), const Offset(100, 100), paint)
      ..drawLine(const Offset(100, 20), const Offset(20, 100), paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
