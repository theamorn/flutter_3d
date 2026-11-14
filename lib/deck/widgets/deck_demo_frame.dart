import 'package:flutter/material.dart';

import '../deck_theme.dart';

/// Shared stage-safe container for live GPU / shader / Flame demos on slides.
///
/// Features:
/// - Rounded GDE border (`4px` solid) + clip so shaders/3D fit cleanly.
/// - Top-right `● LIVE` / `🖼 STATIC` 1-click toggle pill for stage safety.
/// - Optional bottom-left floating caption pill (e.g., interaction hint).
class DeckDemoFrame extends StatefulWidget {
  const DeckDemoFrame({
    required this.liveBuilder,
    this.fallbackAsset,
    this.borderColor = GdeColors.hGreen,
    this.borderRadius = 44,
    this.backgroundColor = GdeColors.navyDark,
    this.height = 840,
    this.hintLabel,
    this.bottomLeftOverlay,
    this.startLive = true,
    super.key,
  });

  final WidgetBuilder liveBuilder;
  final String? fallbackAsset;
  final Color borderColor;
  final double borderRadius;
  final Color backgroundColor;
  final double? height;
  final String? hintLabel;
  final Widget? bottomLeftOverlay;
  final bool startLive;

  @override
  State<DeckDemoFrame> createState() => _DeckDemoFrameState();
}

class _DeckDemoFrameState extends State<DeckDemoFrame> {
  late bool _isLive = widget.startLive;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);
    final innerRadius = BorderRadius.circular(
      (widget.borderRadius - 4).clamp(0, 999),
    );

    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: radius,
        border: Border.all(color: widget.borderColor, width: 4),
      ),
      child: ClipRRect(
        borderRadius: innerRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_isLive)
              TickerMode(
                enabled: true,
                child: Builder(builder: widget.liveBuilder),
              )
            else if (widget.fallbackAsset != null)
              Image.asset(widget.fallbackAsset!, fit: BoxFit.cover)
            else
              ColoredBox(color: widget.backgroundColor),

            // Optional interaction hint pill (top-left)
            if (_isLive && widget.hintLabel != null)
              Positioned(
                top: 20,
                left: 20,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: GdeColors.navy.withValues(alpha: 0.84),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: widget.borderColor, width: 2),
                    ),
                    child: Text(
                      widget.hintLabel!,
                      style: GdeFonts.mono(
                        size: 16,
                        weight: FontWeight.w700,
                        color: GdeColors.white,
                      ),
                    ),
                  ),
                ),
              ),

            // Stage-safe Live <-> Static toggle pill (top-right)
            if (widget.fallbackAsset != null)
              Positioned(
                top: 20,
                right: 20,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _isLive = !_isLive),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _isLive
                            ? GdeColors.navy.withValues(alpha: 0.88)
                            : GdeColors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: _isLive ? GdeColors.hGreen : GdeColors.navy,
                          width: 2.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isLive
                                  ? GdeColors.hGreen
                                  : GdeColors.slate400,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isLive ? 'LIVE GPU' : 'STATIC',
                            style: GdeFonts.mono(
                              size: 15,
                              weight: FontWeight.w700,
                              color: _isLive
                                  ? GdeColors.hGreen
                                  : GdeColors.navy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            if (widget.bottomLeftOverlay != null)
              Positioned(
                bottom: 24,
                left: 24,
                child: widget.bottomLeftOverlay!,
              ),
          ],
        ),
      ),
    );
  }
}
