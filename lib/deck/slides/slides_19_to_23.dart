import 'package:flutter/material.dart';
import 'package:flutter_deck/flutter_deck.dart';
import '../deck_theme.dart';

// =============================================================================
// SLIDE 19: QUOTE SLIDE — IS FLUTTER THE RIGHT CHOICE FOR EVERYTHING?
// =============================================================================
class Slide19Widget extends FlutterDeckSlideWidget {
  const Slide19Widget({super.key})
      : super(
          configuration: const FlutterDeckSlideConfiguration(
            route: '/slide-19',
            title: '19 · Is Flutter Right for Everything?',
          ),
        );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => GdeSlideCanvas(
        slideNumber: 19,
        isNavy: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned(
              top: 10,
              left: 10,
              child: GdeGiantQuoteMark(
                fillColor: GdeColors.red,
                strokeColor: GdeColors.navy,
              ),
            ),
            const Positioned(
              bottom: 10,
              right: 10,
              child: GdeGiantQuoteMark(
                fillColor: GdeColors.hPink,
                strokeColor: GdeColors.navy,
                flipped: true,
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 120),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: GdeFonts.sans(
                        size: 84,
                        weight: FontWeight.w500,
                        color: GdeColors.navy,
                        height: 1.14,
                      ),
                      children: [
                        const TextSpan(
                          text: 'Is Flutter the right choice for ',
                        ),
                        TextSpan(
                          text: 'everything?\n',
                          style: GdeFonts.sans(
                            size: 84,
                            weight: FontWeight.w800,
                            color: GdeColors.red,
                            height: 1.14,
                          ),
                        ),
                        TextSpan(
                          text: 'No. Here is where Native wins.',
                          style: GdeFonts.sans(
                            size: 84,
                            weight: FontWeight.w800,
                            color: GdeColors.green,
                            height: 1.14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SLIDE 20: NAVY WITH YELLOW HEADLINE + # GRID (WHERE NATIVE WINS · 01)
// =============================================================================
class Slide20Widget extends FlutterDeckSlideWidget {
  const Slide20Widget({super.key})
      : super(
          configuration: const FlutterDeckSlideConfiguration(
            route: '/slide-20',
            title: '20 · Where Native Wins 01 (RAM, Size, Day-1 OS)',
          ),
        );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => GdeSlideCanvas(
        slideNumber: 20,
        isNavy: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'WHERE NATIVE WINS · 01 · SOURCES: FLUTTER DOCS · SPRINGER EMSE',
              style: GdeFonts.monoSub(isNavy: true, color: GdeColors.hYellow),
            ),
            const SizedBox(height: 14),
            Text(
              'Choose Native for Minimal RAM, Size, and Day-1 OS.',
              style: GdeFonts.headline(
                size: 70,
                isNavy: true,
                color: GdeColors.yellow,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(
                    flex: 120,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GdePillBox(
                          backgroundColor: GdeColors.navyCard,
                          borderColor: GdeColors.yellow,
                          borderWidth: 3,
                          borderRadius: 24,
                          padding: EdgeInsets.symmetric(
                            horizontal: 36,
                            vertical: 28,
                          ),
                          child: GdeBulletText(
                            boldLead: 'Saves ~15–20MB RAM',
                            rest: 'and ~4–10MB binary size',
                            fontSize: 34,
                            color: GdeColors.white,
                            boldColor: GdeColors.hYellow,
                          ),
                        ),
                        SizedBox(height: 28),
                        GdePillBox(
                          backgroundColor: GdeColors.navyCard,
                          borderColor: GdeColors.hBlue,
                          borderWidth: 3,
                          borderRadius: 24,
                          padding: EdgeInsets.symmetric(
                            horizontal: 36,
                            vertical: 28,
                          ),
                          child: GdeBulletText(
                            boldLead: 'Uses ~6–15% less',
                            rest: 'energy on budget phones',
                            fontSize: 34,
                            color: GdeColors.white,
                            boldColor: GdeColors.hBlue,
                          ),
                        ),
                        SizedBox(height: 28),
                        GdePillBox(
                          backgroundColor: GdeColors.navyCard,
                          borderColor: GdeColors.hGreen,
                          borderWidth: 3,
                          borderRadius: 24,
                          padding: EdgeInsets.symmetric(
                            horizontal: 36,
                            vertical: 28,
                          ),
                          child: GdeBulletText(
                            boldLead: 'Unlocks Day-1 OS',
                            rest: 'system controls and materials',
                            fontSize: 34,
                            color: GdeColors.white,
                            boldColor: GdeColors.hGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 64),
                  Expanded(
                    flex: 80,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 320,
                          height: 280,
                          child: CustomPaint(painter: _HashGridPainter()),
                        ),
                        const SizedBox(height: 40),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildYellowCircle(),
                            const SizedBox(width: 24),
                            _buildYellowCircle(),
                            const SizedBox(width: 24),
                            _buildYellowCircle(),
                          ],
                        ),
                      ],
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

  static Widget _buildYellowCircle() {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: GdeColors.hYellow, width: 5),
      ),
    );
  }
}

class _HashGridPainter extends CustomPainter {
  const _HashGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 320.0;
    final sy = size.height / 280.0;
    canvas.save();
    canvas.scale(sx, sy);

    final path = Path()
      ..moveTo(88, 16)
      ..lineTo(144, 16)
      ..lineTo(144, 72)
      ..lineTo(176, 72)
      ..lineTo(176, 16)
      ..lineTo(232, 16)
      ..lineTo(232, 72)
      ..lineTo(296, 72)
      ..lineTo(296, 128)
      ..lineTo(232, 128)
      ..lineTo(232, 152)
      ..lineTo(296, 152)
      ..lineTo(296, 208)
      ..lineTo(232, 208)
      ..lineTo(232, 264)
      ..lineTo(176, 264)
      ..lineTo(176, 208)
      ..lineTo(144, 208)
      ..lineTo(144, 264)
      ..lineTo(88, 264)
      ..lineTo(88, 208)
      ..lineTo(24, 208)
      ..lineTo(24, 152)
      ..lineTo(88, 152)
      ..lineTo(88, 128)
      ..lineTo(24, 128)
      ..lineTo(24, 72)
      ..lineTo(88, 72)
      ..lineTo(88, 16)
      ..close()
      ..moveTo(144, 128)
      ..lineTo(144, 152)
      ..lineTo(176, 152)
      ..lineTo(176, 128)
      ..lineTo(144, 128)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = GdeColors.yellow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeJoin = StrokeJoin.miter,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =============================================================================
// SLIDE 21: 2-AXIS HORIZONTAL VS. VERTICAL PILL MATRIX (WHERE NATIVE WINS · 02)
// =============================================================================
class Slide21Widget extends FlutterDeckSlideWidget {
  const Slide21Widget({super.key})
      : super(
          configuration: const FlutterDeckSlideConfiguration(
            route: '/slide-21',
            title: '21 · Where Native Wins 02 (Two Orthogonal Axes)',
          ),
        );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => GdeSlideCanvas(
        slideNumber: 21,
        isNavy: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'WHERE NATIVE WINS · 02 · TWO ORTHOGONAL AXES',
              style: GdeFonts.monoSub(color: GdeColors.blue),
            ),
            const SizedBox(height: 10),
            Text(
              'Flutter Scales Horizontally; Native Owns OS Surfaces.',
              style: GdeFonts.headline(size: 66),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left: Flutter Horizontal Cross-OS
                  Expanded(
                    flex: 100,
                    child: GdePillBox(
                      backgroundColor: GdeColors.hBlue,
                      borderColor: GdeColors.navy,
                      borderWidth: 3,
                      borderRadius: 28,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 36,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'FLUTTER · HORIZONTAL CROSS-OS ↔',
                                style: GdeFonts.mono(
                                  size: 22,
                                  weight: FontWeight.w700,
                                  color: GdeColors.navy,
                                ),
                              ),
                              const SizedBox(height: 10),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '6 Operating Systems',
                                  style: GdeFonts.sans(
                                    size: 42,
                                    weight: FontWeight.w800,
                                    color: GdeColors.navy,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Row(
                                children: [
                                  Expanded(child: _OsMatrixChip(label: 'iOS')),
                                  SizedBox(width: 14),
                                  Expanded(
                                    child: _OsMatrixChip(label: 'Android'),
                                  ),
                                  SizedBox(width: 14),
                                  Expanded(child: _OsMatrixChip(label: 'Web')),
                                ],
                              ),
                              const SizedBox(height: 14),
                              const Row(
                                children: [
                                  Expanded(
                                    child: _OsMatrixChip(label: 'macOS'),
                                  ),
                                  SizedBox(width: 14),
                                  Expanded(
                                    child: _OsMatrixChip(label: 'Windows'),
                                  ),
                                  SizedBox(width: 14),
                                  Expanded(
                                    child: _OsMatrixChip(label: 'Linux'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          GdePillBox(
                            backgroundColor: GdeColors.white,
                            borderColor: GdeColors.navy,
                            borderWidth: 3,
                            borderRadius: 16,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Shared App UI, Business Logic & 3D Canvas',
                                  style: GdeFonts.mono(
                                    size: 22,
                                    weight: FontWeight.w700,
                                    color: GdeColors.navy,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 36),
                  // Right: Native Vertical OS Surfaces
                  Expanded(
                    flex: 115,
                    child: GdePillBox(
                      backgroundColor: GdeColors.hYellow,
                      borderColor: GdeColors.navy,
                      borderWidth: 3,
                      borderRadius: 28,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 36,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'NATIVE · VERTICAL OS SURFACES ↕',
                                style: GdeFonts.mono(
                                  size: 22,
                                  weight: FontWeight.w700,
                                  color: GdeColors.navy,
                                ),
                              ),
                              const SizedBox(height: 10),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Deep System Surfaces',
                                  style: GdeFonts.sans(
                                    size: 42,
                                    weight: FontWeight.w800,
                                    color: GdeColors.navy,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Row(
                                children: [
                                  Expanded(
                                    child: _SurfaceMatrixChip(
                                      label: 'Apple Watch · Wear OS Tiles',
                                      bgColor: GdeColors.white,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: _SurfaceMatrixChip(
                                      label: 'VisionOS · Android XR',
                                      bgColor: GdeColors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const _SurfaceMatrixChip(
                                label: 'WidgetKit · Glance · Live Activities',
                                bgColor: GdeColors.hPink,
                              ),
                              const SizedBox(height: 12),
                              const _SurfaceMatrixChip(
                                label:
                                    'CarPlay · Android Auto · App Intents · tvOS',
                                bgColor: GdeColors.white,
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: GdeColors.navy,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Requires SwiftUI / WidgetKit & Jetpack Glance',
                                style: GdeFonts.mono(
                                  size: 22,
                                  weight: FontWeight.w700,
                                  color: GdeColors.hYellow,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: const [
                Expanded(
                  child: GdePillBox(
                    backgroundColor: GdeColors.slateBg,
                    borderRadius: 20,
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    child: Center(
                      child: GdeBulletText(
                        boldLead: 'Flutter spans',
                        rest: 'mobile, web, and desktop',
                        fontSize: 22,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 24),
                Expanded(
                  child: GdePillBox(
                    backgroundColor: GdeColors.slateBg,
                    borderRadius: 20,
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    child: Center(
                      child: GdeBulletText(
                        boldLead: 'Native owns',
                        rest: 'Watch, TV, and spatial',
                        fontSize: 22,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 24),
                Expanded(
                  child: GdePillBox(
                    backgroundColor: GdeColors.slateBg,
                    borderRadius: 20,
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    child: Center(
                      child: GdeBulletText(
                        boldLead: 'System widgets require',
                        rest: 'SwiftUI or Glance',
                        fontSize: 22,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OsMatrixChip extends StatelessWidget {
  const _OsMatrixChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return GdePillBox(
      backgroundColor: GdeColors.white,
      borderColor: GdeColors.navy,
      borderWidth: 3,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: GdeFonts.mono(
              size: 24,
              weight: FontWeight.w700,
              color: GdeColors.navy,
            ),
          ),
        ),
      ),
    );
  }
}

class _SurfaceMatrixChip extends StatelessWidget {
  const _SurfaceMatrixChip({
    required this.label,
    required this.bgColor,
  });

  final String label;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return GdePillBox(
      backgroundColor: bgColor,
      borderColor: GdeColors.navy,
      borderWidth: 3,
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: GdeFonts.mono(
            size: 20,
            weight: FontWeight.w700,
            color: GdeColors.navy,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SLIDE 22: DARK QUOTE SLIDE — WHY DO WE WANT TO OWN IT TWICE?
// =============================================================================
class Slide22Widget extends FlutterDeckSlideWidget {
  const Slide22Widget({super.key})
      : super(
          configuration: const FlutterDeckSlideConfiguration(
            route: '/slide-22',
            title: '22 · Why Do We Want to Own It Twice?',
          ),
        );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => GdeSlideCanvas(
        slideNumber: 22,
        isNavy: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned(
              top: 10,
              left: 10,
              child: GdeGiantQuoteMark(
                fillColor: GdeColors.hGreen,
                strokeColor: GdeColors.white,
              ),
            ),
            const Positioned(
              bottom: 10,
              right: 10,
              child: GdeGiantQuoteMark(
                fillColor: GdeColors.hBlue,
                strokeColor: GdeColors.white,
                flipped: true,
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 120),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: GdeFonts.sans(
                        size: 80,
                        weight: FontWeight.w500,
                        color: GdeColors.white,
                        height: 1.15,
                      ),
                      children: [
                        const TextSpan(
                          text: 'The question is no longer whether AI can ',
                        ),
                        TextSpan(
                          text: 'build it twice',
                          style: GdeFonts.sans(
                            size: 80,
                            weight: FontWeight.w500,
                            color: GdeColors.slate400,
                            height: 1.15,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const TextSpan(text: '.\n'),
                        TextSpan(
                          text: 'Why do we want to own it twice?',
                          style: GdeFonts.sans(
                            size: 80,
                            weight: FontWeight.w800,
                            color: GdeColors.hBlue,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SLIDE 23: CLOSING GDG / DEVFEST SLIDE + QR CODE
// =============================================================================
class Slide23Widget extends FlutterDeckSlideWidget {
  const Slide23Widget({super.key})
      : super(
          configuration: const FlutterDeckSlideConfiguration(
            route: '/slide-23',
            title: '23 · Build Once with AI and Deterministic Flutter',
            preloadImages: {'deck-images/qr-repo.png'},
          ),
        );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => GdeSlideCanvas(
        slideNumber: 23,
        isNavy: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 112,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const GdeBrandHeader(
                    label: 'Thank You · Open-Source Demos & Agent Skills',
                  ),
                  Text(
                    'Build Once with AI and Deterministic Flutter.',
                    style: GdeFonts.headline(size: 68),
                  ),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GdePillBox(
                        backgroundColor: GdeColors.hBlue,
                        padding: EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 20,
                        ),
                        child: GdeBulletText(
                          boldLead: 'Explore 3D demos',
                          rest: 'in flutter_3d repo',
                          fontSize: 33,
                        ),
                      ),
                      SizedBox(height: 20),
                      GdePillBox(
                        backgroundColor: GdeColors.hGreen,
                        padding: EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 20,
                        ),
                        child: GdeBulletText(
                          boldLead: 'Try native embedding',
                          rest: 'in flutter-inapp-ios',
                          fontSize: 33,
                        ),
                      ),
                      SizedBox(height: 20),
                      GdePillBox(
                        backgroundColor: GdeColors.hYellow,
                        padding: EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 20,
                        ),
                        child: GdeBulletText(
                          boldLead: 'Reuse agent skills',
                          rest: 'for Stac workflows',
                          fontSize: 33,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GdePillBox(
                        backgroundColor: GdeColors.hBlue,
                        borderColor: GdeColors.navy,
                        borderWidth: 3,
                        borderRadius: 20,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 12,
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
                        child: GdePillBox(
                          backgroundColor: GdeColors.navy,
                          borderColor: GdeColors.navy,
                          borderWidth: 3,
                          borderRadius: 18,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 10,
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
                  ),
                ],
              ),
            ),
            const SizedBox(width: 64),
            Expanded(
              flex: 88,
              child: SizedBox(
                height: 820,
                child: GdePillBox(
                  backgroundColor: GdeColors.hBlue,
                  borderColor: GdeColors.navy,
                  borderWidth: 3,
                  borderRadius: 48,
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 520,
                            maxHeight: 520,
                          ),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: GdeColors.white,
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color: GdeColors.navy,
                                  width: 4,
                                ),
                              ),
                              child: Image.asset(
                                'deck-images/qr-repo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Scan for Slides, Demos & Skills',
                          style: GdeFonts.mono(
                            size: 28,
                            weight: FontWeight.w700,
                            color: GdeColors.navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
