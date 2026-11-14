import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Exact color palette from `Flutter in the AI Agent Era (Light).html`.
abstract final class GdeColors {
  static const Color navy = Color(0xFF20344B);
  static const Color navyCard = Color(0xFF172638);
  static const Color navyCallout = Color(0xFF18283B);
  static const Color navyDark = Color(0xFF152333);
  static const Color navyDeep = Color(0xFF0F1A28);
  static const Color navyMuted = Color(0xFF334E6F);

  static const Color white = Color(0xFFFFFFFF);
  static const Color slateBg = Color(0xFFF8FAFC);
  static const Color barTrack = Color(0xFFE2E8F0);
  static const Color blueTint = Color(0xFFF1F7FE);
  static const Color pinkTint = Color(0xFFFFEEF4);
  static const Color greenTint = Color(0xFFE8F8EC);

  static const Color blue = Color(0xFF4285F4);
  static const Color green = Color(0xFF34A853);
  static const Color yellow = Color(0xFFF9AB00);
  static const Color red = Color(0xFFEA4335);

  static const Color hBlue = Color(0xFF57CAFF);
  static const Color hGreen = Color(0xFF5CDB6D);
  static const Color hYellow = Color(0xFFFFD427);
  static const Color hPink = Color(0xFFFF7DAF);

  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
}

/// Typography helpers matching Plus Jakarta Sans & Roboto Mono in the HTML deck.
abstract final class GdeFonts {
  static TextStyle sans({
    double size = 38,
    FontWeight weight = FontWeight.w500,
    Color color = GdeColors.navy,
    double height = 1.2,
    double? letterSpacing,
    TextDecoration? decoration,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      decoration: decoration,
      decorationColor: color,
    );
  }

  static TextStyle mono({
    double size = 24,
    FontWeight weight = FontWeight.w600,
    Color color = GdeColors.blue,
    double height = 1.2,
    double letterSpacing = 0.5,
  }) {
    return GoogleFonts.robotoMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle headline({
    double size = 74,
    bool isNavy = false,
    Color? color,
  }) {
    return sans(
      size: size,
      weight: FontWeight.w700,
      color: color ?? (isNavy ? GdeColors.white : GdeColors.navy),
      height: 1.06,
      letterSpacing: -1.8,
    );
  }

  static TextStyle monoSub({
    bool isNavy = false,
    Color? color,
    double size = 24,
  }) {
    return mono(
      size: size,
      weight: FontWeight.w600,
      color: color ?? (isNavy ? GdeColors.hBlue : GdeColors.blue),
      letterSpacing: 0.5,
    );
  }
}

/// Fixed 1920×1080 GDE slide canvas matching `.slide-canvas` in HTML.
class GdeSlideCanvas extends StatelessWidget {
  const GdeSlideCanvas({
    required this.slideNumber,
    required this.child,
    this.totalSlides = 23,
    this.isNavy = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 120, vertical: 96),
    super.key,
  });

  final int slideNumber;
  final int totalSlides;
  final bool isNavy;
  final EdgeInsetsGeometry padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final numLabel =
        '${slideNumber.toString().padLeft(2, '0')} / ${totalSlides.toString().padLeft(2, '0')}';

    return SizedBox(
      width: 1920,
      height: 1080,
      child: ColoredBox(
        color: isNavy ? GdeColors.navy : GdeColors.white,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(padding: padding, child: child),
            Positioned(
              top: 38,
              right: 52,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                decoration: BoxDecoration(
                  color: isNavy ? GdeColors.navy : GdeColors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isNavy ? GdeColors.hBlue : GdeColors.navy,
                    width: 3,
                  ),
                ),
                child: Text(
                  numLabel,
                  style: GdeFonts.mono(
                    size: 20,
                    weight: FontWeight.w700,
                    color: isNavy ? GdeColors.hBlue : GdeColors.navy,
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

/// Standard `.gde-pill-*` bordered rounded container.
class GdePillBox extends StatelessWidget {
  const GdePillBox({
    required this.child,
    this.backgroundColor = GdeColors.hBlue,
    this.borderColor = GdeColors.navy,
    this.borderWidth = 3,
    this.borderRadius = 28,
    this.padding = const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
    this.dashed = false,
    super.key,
  });

  final Widget child;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    if (dashed) {
      return GdeDashedBox(
        backgroundColor: backgroundColor,
        borderColor: borderColor,
        borderWidth: borderWidth,
        borderRadius: borderRadius,
        padding: padding,
        child: child,
      );
    }
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: child,
    );
  }
}

/// Dashed rounded rectangle matching CSS `border: 4px dashed ...`.
class GdeDashedBox extends StatelessWidget {
  const GdeDashedBox({
    required this.child,
    required this.borderColor,
    this.backgroundColor = Colors.transparent,
    this.borderWidth = 4,
    this.borderRadius = 36,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final Widget child;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedRRectPainter(
        color: borderColor,
        strokeWidth: borderWidth,
        radius: borderRadius,
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: child,
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
  });

  final Color color;
  final double strokeWidth;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rrect = RRect.fromRectAndRadius(
      Offset(strokeWidth / 2, strokeWidth / 2) &
          Size(size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    const dashLen = 14.0;
    const gapLen = 10.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dashLen, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashLen + gapLen;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.radius != radius;
}

/// Single-line `• **Bold lead** rest of bullet` matching `.bullet-list li`.
class GdeBulletText extends StatelessWidget {
  const GdeBulletText({
    required this.boldLead,
    required this.rest,
    this.fontSize = 32,
    this.color = GdeColors.navy,
    this.boldColor,
    this.textAlign = TextAlign.start,
    super.key,
  });

  final String boldLead;
  final String rest;
  final double fontSize;
  final Color color;
  final Color? boldColor;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: textAlign == TextAlign.center
          ? Alignment.center
          : Alignment.centerLeft,
      child: RichText(
        textAlign: textAlign,
        maxLines: 1,
        text: TextSpan(
          style: GdeFonts.sans(
            size: fontSize,
            weight: FontWeight.w500,
            color: color,
            height: 1.25,
          ),
          children: [
            const TextSpan(text: '• '),
            TextSpan(
              text: boldLead,
              style: GdeFonts.sans(
                size: fontSize,
                weight: FontWeight.w800,
                color: boldColor ?? color,
                height: 1.25,
              ),
            ),
            if (rest.isNotEmpty) TextSpan(text: ' $rest'),
          ],
        ),
      ),
    );
  }
}

/// GDE `< >` 4-color bracket logo + label (Slides 01 & 23).
class GdeBrandHeader extends StatelessWidget {
  const GdeBrandHeader({
    required this.label,
    this.isNavy = false,
    super.key,
  });

  final String label;
  final bool isNavy;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 64,
            height: 44,
            child: CustomPaint(painter: _GdeBracketsPainter()),
          ),
          const SizedBox(width: 16),
          Text(
            label,
            style: GdeFonts.sans(
              size: 28,
              weight: FontWeight.w600,
              color: isNavy ? GdeColors.white : GdeColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

class _GdeBracketsPainter extends CustomPainter {
  const _GdeBracketsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 64;
    final sy = size.height / 44;
    canvas.save();
    canvas.scale(sx, sy);

    Paint stroke(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pRed = Path()
      ..moveTo(22, 6)
      ..lineTo(8, 18)
      ..lineTo(22, 30);
    canvas.drawPath(pRed, stroke(GdeColors.red));

    canvas.drawLine(
      const Offset(8, 22),
      const Offset(22, 34),
      stroke(GdeColors.blue),
    );

    final pGreen = Path()
      ..moveTo(42, 6)
      ..lineTo(56, 18)
      ..lineTo(42, 30);
    canvas.drawPath(pGreen, stroke(GdeColors.green));

    canvas.drawLine(
      const Offset(56, 22),
      const Offset(42, 34),
      stroke(GdeColors.yellow),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Giant GDE Quote Mark SVG port (Slides 02, 04, 19, 22).
class GdeGiantQuoteMark extends StatelessWidget {
  const GdeGiantQuoteMark({
    required this.fillColor,
    required this.strokeColor,
    this.flipped = false,
    super.key,
  });

  final Color fillColor;
  final Color strokeColor;
  final bool flipped;

  @override
  Widget build(BuildContext context) {
    Widget mark = SizedBox(
      width: 180,
      height: 140,
      child: CustomPaint(
        painter: _QuoteMarkPainter(
          fillColor: fillColor,
          strokeColor: strokeColor,
        ),
      ),
    );
    if (flipped) {
      mark = Transform.rotate(angle: math.pi, child: mark);
    }
    return mark;
  }
}

class _QuoteMarkPainter extends CustomPainter {
  const _QuoteMarkPainter({
    required this.fillColor,
    required this.strokeColor,
  });

  final Color fillColor;
  final Color strokeColor;

  Path _lobe(double dx) {
    final p = Path()
      ..moveTo(42 + dx, 12)
      ..lineTo(14 + dx, 64)
      ..cubicTo(8 + dx, 76, 6 + dx, 88, 10 + dx, 102)
      ..cubicTo(16 + dx, 120, 34 + dx, 130, 52 + dx, 126)
      ..cubicTo(70 + dx, 122, 82 + dx, 104, 78 + dx, 86)
      ..cubicTo(74 + dx, 68, 58 + dx, 58, 42 + dx, 60)
      ..lineTo(64 + dx, 22)
      ..close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addPath(_lobe(0), Offset.zero)
      ..addPath(_lobe(88), Offset.zero);
    canvas.drawPath(
      path,
      Paint()
        ..color = fillColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _QuoteMarkPainter old) =>
      old.fillColor != fillColor || old.strokeColor != strokeColor;
}
