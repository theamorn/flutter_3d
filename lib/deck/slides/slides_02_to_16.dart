import 'package:flutter/material.dart';
import 'package:flutter_deck/flutter_deck.dart';
import '../deck_theme.dart';

// =============================================================================
// SLIDE 02: QUOTE SLIDE — MUSTAFA ALI, SHOPIFY ENGINEERING
// =============================================================================
class Slide02Widget extends FlutterDeckSlideWidget {
  const Slide02Widget({super.key})
      : super(
          configuration: const FlutterDeckSlideConfiguration(
            route: '/slide-02',
            title: '02 · Shopify Back to Native Quote',
          ),
        );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => GdeSlideCanvas(
        slideNumber: 2,
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
                  constraints: const BoxConstraints(maxWidth: 1420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: GdeFonts.sans(
                            size: 80,
                            weight: FontWeight.w500,
                            color: GdeColors.navy,
                            height: 1.14,
                          ),
                          children: [
                            const TextSpan(
                              text:
                                  'Building the same feature in Swift and Kotlin ',
                            ),
                            TextSpan(
                              text: 'no longer carries the cost it used to.',
                              style: GdeFonts.sans(
                                size: 80,
                                weight: FontWeight.w800,
                                color: GdeColors.navy,
                                height: 1.14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 44),
                      GdePillBox(
                        backgroundColor: GdeColors.hBlue,
                        borderColor: GdeColors.navy,
                        borderWidth: 3,
                        borderRadius: 28,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 36,
                          vertical: 12,
                        ),
                        child: Text(
                          '— Mustafa Ali, Shopify Engineering',
                          style: GdeFonts.sans(
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

// =============================================================================
// SLIDE 03: 3-COLUMN SUBHEAD GRID ON NAVY — SHOPIFY'S SHIFT
// =============================================================================
class Slide03Widget extends FlutterDeckSlideWidget {
  const Slide03Widget({super.key})
      : super(
          configuration: const FlutterDeckSlideConfiguration(
            route: '/slide-03',
            title: '03 · Shopify Shift 2020 to 2026',
          ),
        );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => GdeSlideCanvas(
        slideNumber: 3,
        isNavy: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SHOPIFY’S SHIFT · 2020 → 2026',
                          style: GdeFonts.monoSub(
                            isNavy: true,
                            color: GdeColors.hPink,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child: Text(
                            'Shopify Left React Native for AI-Assisted Native.',
                            style: GdeFonts.headline(
                              isNavy: true,
                              color: GdeColors.hPink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 40),
                  Padding(
                    padding: const EdgeInsets.only(top: 16, right: 40),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildOutlinedCircle(92, GdeColors.red, 5),
                        const SizedBox(width: 22),
                        _buildOutlinedCircle(92, GdeColors.red, 5),
                        const SizedBox(width: 22),
                        _buildOutlinedCircle(92, GdeColors.red, 5),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 36),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    Expanded(
                      child: _Slide03Card(
                        tag: '01 · 2020 BET',
                        title: 'Cross-Platform',
                        boldLead: 'Adopted React Native',
                        rest: 'in 2020',
                        accentColor: GdeColors.hBlue,
                      ),
                    ),
                    SizedBox(width: 28),
                    Expanded(
                      child: _Slide03Card(
                        tag: '02 · 2026 REBUILD',
                        title: 'Swift + Kotlin',
                        boldLead: 'Rebuilt 300+ screens',
                        rest: 'in 12 weeks',
                        accentColor: GdeColors.hYellow,
                      ),
                    ),
                    SizedBox(width: 28),
                    Expanded(
                      child: _Slide03Card(
                        tag: '03 · ECOSYSTEM',
                        title: 'Sunsetting RN',
                        boldLead: 'Wound down',
                        rest: 'React Native open source',
                        accentColor: GdeColors.hPink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide03Card extends StatelessWidget {
  const _Slide03Card({
    required this.tag,
    required this.title,
    required this.boldLead,
    required this.rest,
    required this.accentColor,
  });

  final String tag;
  final String title;
  final String boldLead;
  final String rest;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return GdePillBox(
      backgroundColor: GdeColors.navyCard,
      borderColor: accentColor,
      borderWidth: 3,
      borderRadius: 32,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tag,
            style: GdeFonts.mono(
              size: 22,
              weight: FontWeight.w600,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 18),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: GdeFonts.sans(
                size: 42,
                weight: FontWeight.w800,
                color: GdeColors.white,
              ),
            ),
          ),
          const SizedBox(height: 18),
          GdeBulletText(
            boldLead: boldLead,
            rest: rest,
            fontSize: 23,
            color: GdeColors.slate300,
            boldColor: GdeColors.white,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SLIDE 04: QUOTE SLIDE + WORRIED DASH ILLUSTRATION
// =============================================================================
class Slide04Widget extends FlutterDeckSlideWidget {
  const Slide04Widget({super.key})
      : super(
          configuration: const FlutterDeckSlideConfiguration(
            route: '/slide-04',
            title: '04 · Why Use Cross-Platform at All?',
            preloadImages: {'deck-images/dash-worried.png'},
          ),
        );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => GdeSlideCanvas(
        slideNumber: 4,
        isNavy: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 105,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      width: 128,
                      height: 98,
                      child: FittedBox(
                        child: GdeGiantQuoteMark(
                          fillColor: GdeColors.hBlue,
                          strokeColor: GdeColors.navy,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Flexible(
                      child: RichText(
                        text: TextSpan(
                          style: GdeFonts.sans(
                            size: 62,
                            weight: FontWeight.w500,
                            color: GdeColors.navy,
                            height: 1.14,
                          ),
                          children: [
                            const TextSpan(text: 'If AI can write '),
                            TextSpan(
                              text: 'Swift and Kotlin',
                              style: GdeFonts.sans(
                                size: 62,
                                weight: FontWeight.w800,
                                color: GdeColors.red,
                                height: 1.14,
                              ),
                            ),
                            const TextSpan(
                              text: ' for you, why use cross-platform at all—',
                            ),
                            TextSpan(
                              text: 'including Flutter?',
                              style: GdeFonts.sans(
                                size: 62,
                                weight: FontWeight.w800,
                                color: GdeColors.blue,
                                height: 1.14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 128,
                        height: 98,
                        child: FittedBox(
                          child: GdeGiantQuoteMark(
                            fillColor: GdeColors.hYellow,
                            strokeColor: GdeColors.navy,
                            flipped: true,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 56),
            Expanded(
              flex: 95,
              child: Container(
                height: 820,
                decoration: BoxDecoration(
                  color: GdeColors.slateBg,
                  borderRadius: BorderRadius.circular(48),
                  border: Border.all(color: GdeColors.navy, width: 4),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(44),
                  child: Image.asset(
                    'deck-images/dash-worried.png',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
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
// SLIDE 06: GROUP CHART / TREE ARCHITECTURE — ENGINE & DEPENDENCIES
// =============================================================================
class Slide06Widget extends FlutterDeckSlideWidget {
  const Slide06Widget({super.key})
      : super(
          configuration: const FlutterDeckSlideConfiguration(
            route: '/slide-06',
            title: '06 · Flutter Ships Heavy Visuals in the SDK',
          ),
        );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => GdeSlideCanvas(
        slideNumber: 6,
        isNavy: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ENGINE & DEPENDENCIES', style: GdeFonts.monoSub()),
                const SizedBox(height: 10),
                Text(
                  'Flutter Ships Heavy Visuals in the SDK.',
                  style: GdeFonts.headline(),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: const [
                      Expanded(
                        child: _Slide06NodeCard(
                          badge: '01',
                          label: 'SliverList',
                          cardColor: GdeColors.hBlue,
                          circleColor: GdeColors.blue,
                        ),
                      ),
                      SizedBox(width: 28),
                      Expanded(
                        child: _Slide06NodeCard(
                          badge: '02',
                          label: 'Animations',
                          cardColor: GdeColors.hBlue,
                          circleColor: GdeColors.blue,
                        ),
                      ),
                      SizedBox(width: 28),
                      Expanded(
                        child: _Slide06NodeCard(
                          badge: '03',
                          label: 'Impeller GLSL',
                          cardColor: GdeColors.hBlue,
                          circleColor: GdeColors.blue,
                        ),
                      ),
                      SizedBox(width: 28),
                      Expanded(
                        child: _Slide06NodeCard(
                          badge: '3D',
                          label: 'Flutter GPU + Stac',
                          cardColor: GdeColors.hGreen,
                          circleColor: GdeColors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  FractionallySizedBox(
                    widthFactor: 0.86,
                    child: Container(
                      height: 32,
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(color: GdeColors.navy, width: 4),
                          right: BorderSide(color: GdeColors.navy, width: 4),
                          bottom: BorderSide(color: GdeColors.navy, width: 4),
                        ),
                      ),
                    ),
                  ),
                  Container(width: 4, height: 28, color: GdeColors.navy),
                  const SizedBox(height: 18),
                  Row(
                    children: const [
                      Expanded(
                        child: GdePillBox(
                          backgroundColor: GdeColors.hPink,
                          padding: EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 20,
                          ),
                          child: Center(
                            child: GdeBulletText(
                              boldLead: 'React Native needs',
                              rest: 'external UI packages',
                              fontSize: 22,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 24),
                      Expanded(
                        child: GdePillBox(
                          backgroundColor: GdeColors.hBlue,
                          padding: EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 20,
                          ),
                          child: Center(
                            child: GdeBulletText(
                              boldLead: 'Flutter SDK bundles',
                              rest: 'lists, animations, shaders',
                              fontSize: 22,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 24),
                      Expanded(
                        child: GdePillBox(
                          backgroundColor: GdeColors.hGreen,
                          padding: EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 20,
                          ),
                          child: Center(
                            child: GdeBulletText(
                              boldLead: 'One SDK upgrade',
                              rest: 'advances every visual',
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
          ],
        ),
      ),
    );
  }
}

class _Slide06NodeCard extends StatelessWidget {
  const _Slide06NodeCard({
    required this.badge,
    required this.label,
    required this.cardColor,
    required this.circleColor,
  });

  final String badge;
  final String label;
  final Color cardColor;
  final Color circleColor;

  @override
  Widget build(BuildContext context) {
    return GdePillBox(
      backgroundColor: cardColor,
      borderColor: GdeColors.navy,
      borderWidth: 3,
      borderRadius: 28,
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: circleColor,
              shape: BoxShape.circle,
              border: Border.all(color: GdeColors.navy, width: 3),
            ),
            alignment: Alignment.center,
            child: Text(
              badge,
              style: GdeFonts.mono(
                size: 26,
                weight: FontWeight.w700,
                color: GdeColors.white,
              ),
            ),
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: GdeFonts.mono(
                size: 26,
                weight: FontWeight.w700,
                color: GdeColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SLIDE 07: CLEAN HORIZONTAL FRAME-BUDGET BAR CHART (120 FPS = 8.3 MS)
// =============================================================================
class Slide07Widget extends FlutterDeckSlideWidget {
  const Slide07Widget({super.key})
      : super(
          configuration: const FlutterDeckSlideConfiguration(
            route: '/slide-07',
            title: '07 · Extra Native Headroom Beyond 120fps',
          ),
        );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => GdeSlideCanvas(
        slideNumber: 7,
        isNavy: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PERFORMANCE VS. EFFORT · 120 FPS = 8.3 MS',
                  style: GdeFonts.monoSub(),
                ),
                const SizedBox(height: 10),
                Text(
                  'Extra Native Headroom Beyond 120fps Is Invisible.',
                  style: GdeFonts.headline(size: 66),
                ),
              ],
            ),
            GdePillBox(
              backgroundColor: GdeColors.slateBg,
              borderColor: GdeColors.navy,
              borderWidth: 4,
              borderRadius: 36,
              padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LabeledBarHeader(
                    leftTitle: 'Flutter (1 Codebase)',
                    rightLabel: '120 FPS (8.3 ms)',
                    rightColor: GdeColors.green,
                  ),
                  const SizedBox(height: 14),
                  _RoundedBarContainer(
                    height: 64,
                    trackColor: GdeColors.barTrack,
                    borderColor: GdeColors.navy,
                    borderWidth: 4,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 86,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: GdeColors.hGreen,
                              border: Border(
                                right: BorderSide(
                                  color: GdeColors.navy,
                                  width: 4,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Expanded(flex: 14, child: SizedBox.expand()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 38),
                  _LabeledBarHeader(
                    leftTitle: 'Pure Native (2 Codebases)',
                    rightLabel: '120 FPS + Unseen Headroom',
                    rightColor: GdeColors.red,
                  ),
                  const SizedBox(height: 14),
                  _RoundedBarContainer(
                    height: 64,
                    trackColor: GdeColors.barTrack,
                    borderColor: GdeColors.navy,
                    borderWidth: 4,
                    child: Row(
                      children: const [
                        Expanded(
                          flex: 86,
                          child: ColoredBox(
                            color: GdeColors.hBlue,
                            child: SizedBox.expand(),
                          ),
                        ),
                        _VerticalDashedDivider(color: GdeColors.navy, width: 4),
                        Expanded(
                          flex: 14,
                          child: ColoredBox(
                            color: GdeColors.hYellow,
                            child: SizedBox.expand(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: const [
                Expanded(
                  child: GdePillBox(
                    backgroundColor: GdeColors.hGreen,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                    child: Center(
                      child: GdeBulletText(
                        boldLead: 'Impeller hits 120fps',
                        rest: 'within 8.3ms frames',
                        fontSize: 26,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 28),
                Expanded(
                  child: GdePillBox(
                    backgroundColor: GdeColors.hYellow,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                    child: Center(
                      child: GdeBulletText(
                        boldLead: 'Unused CPU headroom',
                        rest: 'is invisible onscreen',
                        fontSize: 26,
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

// =============================================================================
// SLIDE 08: THE SKEPTICS' CLAIM (~40% PRE-AI VS ~10%? AI-NATIVE CLAIM)
// =============================================================================
class Slide08Widget extends FlutterDeckSlideWidget {
  const Slide08Widget({super.key})
      : super(
          configuration: const FlutterDeckSlideConfiguration(
            route: '/slide-08',
            title: '08 · The Vibe-Coder Myth (~40% vs 50–70%)',
          ),
        );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => GdeSlideCanvas(
        slideNumber: 8,
        isNavy: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'THE VIBE-CODER MYTH · “AI WRITES CODE FAST”',
              style: GdeFonts.monoSub(isNavy: true, color: GdeColors.hPink),
            ),
            const SizedBox(height: 12),
            Text(
              'If AI Generates Native Fast, Why Use Flutter?',
              style: GdeFonts.headline(size: 66, isNavy: true),
            ),
            const SizedBox(height: 28),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  Expanded(
                    child: _BigStatCard(
                      tag: '01 · PRE-AI FLUTTER',
                      stat: '~40%',
                      fillPercent: 40,
                      boldLead: 'Saved ~40% effort',
                      rest: 'vs. 2 manual apps',
                      accentColor: GdeColors.hBlue,
                      dashed: false,
                      statFontSize: 120,
                    ),
                  ),
                  SizedBox(width: 40),
                  Expanded(
                    child: _BigStatCard(
                      tag: '02 · AI + 2 NATIVE CLAIM',
                      stat: '50–70%',
                      fillPercent: 65,
                      boldLead: 'Claims AI saves',
                      rest: '50–70% across 2 apps',
                      accentColor: GdeColors.hPink,
                      dashed: true,
                      statFontSize: 112,
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

// =============================================================================
// SLIDE 09: THE 2026 REALITY (FLUTTER USES AI TOO -> 1/2 PRs)
// =============================================================================
class Slide09Widget extends FlutterDeckSlideWidget {
  const Slide09Widget({super.key})
      : super(
          configuration: const FlutterDeckSlideConfiguration(
            route: '/slide-09',
            title: '09 · The Flawed Assumption (Flutter + AI)',
          ),
        );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => GdeSlideCanvas(
        slideNumber: 9,
        isNavy: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'THE FLAWED ASSUMPTION · 2026 REALITY',
              style: GdeFonts.monoSub(isNavy: true, color: GdeColors.hGreen),
            ),
            const SizedBox(height: 12),
            Text(
              'That Claim Only Works If Flutter Can’t Use AI.',
              style: GdeFonts.headline(size: 64, isNavy: true),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 88,
                    child: Opacity(
                      opacity: 0.85,
                      child: GdeDashedBox(
                        backgroundColor: GdeColors.navyCard,
                        borderColor: GdeColors.hPink,
                        borderWidth: 4,
                        borderRadius: 36,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 36,
                          vertical: 38,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'IF FLUTTER CAN’T USE AI',
                              style: GdeFonts.mono(
                                size: 22,
                                weight: FontWeight.w700,
                                color: GdeColors.hPink,
                              ),
                            ),
                            Text(
                              '50–70%',
                              style: GdeFonts.sans(
                                size: 84,
                                weight: FontWeight.w800,
                                color: GdeColors.hPink,
                                height: 1.0,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 18,
                              ),
                              decoration: BoxDecoration(
                                color: GdeColors.navyDeep,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: GdeColors.hPink,
                                  width: 2,
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'AI Native vs. Manual Flutter',
                                  style: GdeFonts.mono(
                                    size: 24,
                                    weight: FontWeight.w500,
                                    color: GdeColors.slate300,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                  Expanded(
                    flex: 112,
                    child: GdePillBox(
                      backgroundColor: GdeColors.hGreen,
                      borderColor: GdeColors.white,
                      borderWidth: 4,
                      borderRadius: 36,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 42,
                        vertical: 38,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '2026 REALITY · FLUTTER + AI',
                            style: GdeFonts.mono(
                              size: 24,
                              weight: FontWeight.w700,
                              color: GdeColors.navy,
                            ),
                          ),
                          Text(
                            '½ PRs',
                            style: GdeFonts.sans(
                              size: 128,
                              weight: FontWeight.w800,
                              color: GdeColors.navy,
                              height: 1.0,
                            ),
                          ),
                          const _RoundedBarContainer(
                            height: 28,
                            trackColor: GdeColors.white,
                            borderColor: GdeColors.navy,
                            borderWidth: 4,
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 50,
                                  child: ColoredBox(
                                    color: GdeColors.navy,
                                    child: SizedBox.expand(),
                                  ),
                                ),
                                Expanded(flex: 50, child: SizedBox.expand()),
                              ],
                            ),
                          ),
                          Text(
                            'AI Multiplier × 1 Shared Codebase',
                            style: GdeFonts.mono(
                              size: 24,
                              weight: FontWeight.w700,
                              color: GdeColors.navy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: const [
                Expanded(
                  child: GdePillBox(
                    backgroundColor: GdeColors.navyCard,
                    borderColor: GdeColors.hPink,
                    borderWidth: 3,
                    borderRadius: 20,
                    padding: EdgeInsets.all(18),
                    child: Center(
                      child: GdeBulletText(
                        boldLead: 'Skeptics assume Flutter',
                        rest: 'cannot use AI',
                        fontSize: 22,
                        color: GdeColors.white,
                        boldColor: GdeColors.hPink,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 24),
                Expanded(
                  child: GdePillBox(
                    backgroundColor: GdeColors.navyCard,
                    borderColor: GdeColors.hBlue,
                    borderWidth: 3,
                    borderRadius: 20,
                    padding: EdgeInsets.all(18),
                    child: Center(
                      child: GdeBulletText(
                        boldLead: 'AI speeds up',
                        rest: 'Dart and Flutter too',
                        fontSize: 22,
                        color: GdeColors.white,
                        boldColor: GdeColors.hBlue,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 24),
                Expanded(
                  child: GdePillBox(
                    backgroundColor: GdeColors.navyCard,
                    borderColor: GdeColors.hGreen,
                    borderWidth: 3,
                    borderRadius: 20,
                    padding: EdgeInsets.all(18),
                    child: Center(
                      child: GdeBulletText(
                        boldLead: 'Flutter with AI',
                        rest: 'halves total PRs',
                        fontSize: 22,
                        color: GdeColors.white,
                        boldColor: GdeColors.hGreen,
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

// =============================================================================
// SLIDE 10: 20% CODING VS 80% REST OF SDLC SPLIT CHART
// =============================================================================
class Slide10Widget extends FlutterDeckSlideWidget {
  const Slide10Widget({super.key})
      : super(
          configuration: const FlutterDeckSlideConfiguration(
            route: '/slide-10',
            title: '10 · 20% Coding vs 80% Rest of SDLC',
          ),
        );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => GdeSlideCanvas(
        slideNumber: 10,
        isNavy: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'FULL SDLC · SOURCES: IEEE TSE · IDC · BROOKS · DORA',
              style: GdeFonts.monoSub(),
            ),
            const SizedBox(height: 10),
            Text(
              'AI Speeds Up Coding—Not the Other 80% of SDLC.',
              style: GdeFonts.headline(size: 64),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Align Row 1 Col 1 width 1:1 with Expanded(flex: 20) below
                  // where 3 gaps of 20px = 60px total gap across 100 flex units.
                  final col1Width = (constraints.maxWidth - 60) * 0.20;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Row 1: Top Split Status Banners
                      Row(
                        children: [
                          SizedBox(
                            width: col1Width,
                            child: GdePillBox(
                              backgroundColor: GdeColors.hGreen,
                              borderColor: GdeColors.navy,
                              borderWidth: 3,
                              borderRadius: 16,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'FASTER WITH AI (BOTH)',
                                    style: GdeFonts.mono(
                                      size: 18,
                                      weight: FontWeight.w700,
                                      color: GdeColors.navy,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: GdePillBox(
                              backgroundColor: GdeColors.red,
                              borderColor: GdeColors.navy,
                              borderWidth: 3,
                              borderRadius: 16,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    '80% BEYOND CODING · NOT FASTER WITH AI (DOUBLED ON 2 NATIVE APPS)',
                                    style: GdeFonts.mono(
                                      size: 18,
                                      weight: FontWeight.w700,
                                      color: GdeColors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Row 2: Proportional Bar Pills (20 : 25 : 25 : 30)
                      Row(
                        children: const [
                          Expanded(
                            flex: 20,
                            child: _SdlcBarSegment(
                              label: '20% Coding',
                              bgColor: GdeColors.hYellow,
                              textColor: GdeColors.navy,
                            ),
                          ),
                          SizedBox(width: 20),
                          Expanded(
                            flex: 25,
                            child: _SdlcBarSegment(
                              label: '25% Auto Tests',
                              bgColor: GdeColors.hBlue,
                              textColor: GdeColors.navy,
                            ),
                          ),
                          SizedBox(width: 20),
                          Expanded(
                            flex: 25,
                            child: _SdlcBarSegment(
                              label: '25% QA & Parity',
                              bgColor: GdeColors.hPink,
                              textColor: GdeColors.navy,
                            ),
                          ),
                          SizedBox(width: 20),
                          Expanded(
                            flex: 30,
                            child: _SdlcBarSegment(
                              label: '30% Ownership',
                              bgColor: GdeColors.navy,
                              textColor: GdeColors.hGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Row 3: 4 Phase Cards (20 : 25 : 25 : 30)
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: const [
                            Expanded(
                              flex: 20,
                              child: _SdlcPhaseCard(
                                phaseLabel: 'PHASE 1',
                                percent: '~20%',
                                title: 'Coding',
                                subtitle: 'Native + AI & Flutter + AI',
                                bgColor: GdeColors.hYellow,
                                phaseColor: GdeColors.navy,
                                percentColor: GdeColors.navy,
                                titleColor: GdeColors.navy,
                                subColor: GdeColors.navy,
                              ),
                            ),
                            SizedBox(width: 20),
                            Expanded(
                              flex: 25,
                              child: _SdlcPhaseCard(
                                phaseLabel: 'PHASE 2',
                                percent: '~25%',
                                title: 'Automated Tests',
                                subtitle: '2× Test Suites on Native',
                                bgColor: GdeColors.hBlue,
                                phaseColor: GdeColors.navy,
                                percentColor: GdeColors.navy,
                                titleColor: GdeColors.navy,
                                subColor: GdeColors.navy,
                              ),
                            ),
                            SizedBox(width: 20),
                            Expanded(
                              flex: 25,
                              child: _SdlcPhaseCard(
                                phaseLabel: 'PHASE 3',
                                percent: '~25%',
                                title: 'Release QA & Parity',
                                subtitle: '2× Logic & UI Verification',
                                bgColor: GdeColors.hPink,
                                phaseColor: GdeColors.navy,
                                percentColor: GdeColors.navy,
                                titleColor: GdeColors.navy,
                                subColor: GdeColors.navy,
                              ),
                            ),
                            SizedBox(width: 20),
                            Expanded(
                              flex: 30,
                              child: _SdlcPhaseCard(
                                phaseLabel: 'PHASE 4',
                                percent: '~30%',
                                title: 'Long-Term Ownership',
                                subtitle: '2× Repos, PRs & Maintenance',
                                bgColor: GdeColors.navy,
                                phaseColor: GdeColors.hGreen,
                                percentColor: GdeColors.white,
                                titleColor: GdeColors.hGreen,
                                subColor: GdeColors.slate300,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: const [
                Expanded(
                  child: GdePillBox(
                    backgroundColor: GdeColors.slateBg,
                    borderRadius: 20,
                    padding: EdgeInsets.all(18),
                    child: Center(
                      child: GdeBulletText(
                        boldLead: 'AI only accelerates',
                        rest: '20% coding phase',
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
                    padding: EdgeInsets.all(18),
                    child: Center(
                      child: GdeBulletText(
                        boldLead: 'Flutter gets',
                        rest: 'faster coding with AI',
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
                    padding: EdgeInsets.all(18),
                    child: Center(
                      child: GdeBulletText(
                        boldLead: '80% SDLC effort',
                        rest: 'still doubles natively',
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

class _SdlcBarSegment extends StatelessWidget {
  const _SdlcBarSegment({
    required this.label,
    required this.bgColor,
    required this.textColor,
  });

  final String label;
  final Color bgColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: GdeColors.navy, width: 4),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          style: GdeFonts.mono(
            size: 21,
            weight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ),
    );
  }
}

class _SdlcPhaseCard extends StatelessWidget {
  const _SdlcPhaseCard({
    required this.phaseLabel,
    required this.percent,
    required this.title,
    required this.subtitle,
    required this.bgColor,
    required this.phaseColor,
    required this.percentColor,
    required this.titleColor,
    required this.subColor,
  });

  final String phaseLabel;
  final String percent;
  final String title;
  final String subtitle;
  final Color bgColor;
  final Color phaseColor;
  final Color percentColor;
  final Color titleColor;
  final Color subColor;

  @override
  Widget build(BuildContext context) {
    return GdePillBox(
      backgroundColor: bgColor,
      borderColor: GdeColors.navy,
      borderWidth: 3,
      borderRadius: 28,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            phaseLabel,
            style: GdeFonts.mono(
              size: 19,
              weight: FontWeight.w700,
              color: phaseColor,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              percent,
              style: GdeFonts.sans(
                size: 78,
                weight: FontWeight.w800,
                color: percentColor,
                height: 1.0,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: GdeFonts.sans(
                    size: 28,
                    weight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  subtitle,
                  style: GdeFonts.mono(
                    size: 16,
                    weight: FontWeight.w700,
                    color: subColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SLIDE 11: FLOW STYLE CHART — SHOPIFY'S REBUILD TAX
// =============================================================================
class Slide11Widget extends FlutterDeckSlideWidget {
  const Slide11Widget({super.key})
      : super(
          configuration: const FlutterDeckSlideConfiguration(
            route: '/slide-11',
            title: '11 · Shopify Rebuild Tax & Helix Flow',
          ),
        );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => GdeSlideCanvas(
        slideNumber: 11,
        isNavy: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SHOPIFY’S REBUILD TAX · 4 CUSTOM TOOLS FOR 30 ENGINEERS',
                  style: GdeFonts.monoSub(color: GdeColors.red),
                ),
                const SizedBox(height: 10),
                Text(
                  'AI Native Migrations Require Heavy Verification Harnesses.',
                  style: GdeFonts.headline(size: 66),
                ),
              ],
            ),
            GdePillBox(
              backgroundColor: GdeColors.slateBg,
              borderColor: GdeColors.navy,
              borderWidth: 3,
              borderRadius: 36,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: const [
                      Expanded(child: _HelixTagPill('01 · No One-Shot')),
                      SizedBox(width: 28),
                      Expanded(child: _HelixTagPill('02 · Match Running App')),
                      SizedBox(width: 28),
                      Expanded(child: _HelixTagPill('03 · Adversarial Audit')),
                      SizedBox(width: 28),
                      Expanded(child: _HelixTagPill('04 · Mandatory Gate')),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      const Expanded(
                        child: _HelixOvalNode(
                          label: 'Helix\nCheckpoints',
                          bgColor: GdeColors.white,
                          textColor: GdeColors.navy,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '→',
                        style: GdeFonts.sans(
                          size: 44,
                          weight: FontWeight.w800,
                          color: GdeColors.navy,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: _HelixOvalNode(
                          label: 'Visual UI\nReview',
                          bgColor: GdeColors.green,
                          textColor: GdeColors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '→',
                        style: GdeFonts.sans(
                          size: 44,
                          weight: FontWeight.w800,
                          color: GdeColors.navy,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: _HelixOvalNode(
                          label: '2 AI Critics\nReview',
                          bgColor: GdeColors.blue,
                          textColor: GdeColors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '→',
                        style: GdeFonts.sans(
                          size: 44,
                          weight: FontWeight.w800,
                          color: GdeColors.navy,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: _HelixOvalNode(
                          label: '“A Human’s\nNod”',
                          bgColor: GdeColors.hGreen,
                          textColor: GdeColors.navy,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              children: const [
                Expanded(
                  child: GdePillBox(
                    backgroundColor: GdeColors.hPink,
                    padding: EdgeInsets.all(18),
                    child: Center(
                      child: GdeBulletText(
                        boldLead: 'Weeks spent upfront',
                        rest: 'on manual screens',
                        fontSize: 22,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 24),
                Expanded(
                  child: GdePillBox(
                    backgroundColor: GdeColors.hBlue,
                    padding: EdgeInsets.all(18),
                    child: Center(
                      child: GdeBulletText(
                        boldLead: 'Built Helix, Reflex',
                        rest: '& cloud fleets',
                        fontSize: 22,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 24),
                Expanded(
                  child: GdePillBox(
                    backgroundColor: GdeColors.hYellow,
                    padding: EdgeInsets.all(18),
                    child: Center(
                      child: GdeBulletText(
                        boldLead: 'Human approval gates',
                        rest: 'every migration step',
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

class _HelixTagPill extends StatelessWidget {
  const _HelixTagPill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: GdeColors.navy,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: GdeFonts.mono(
            size: 20,
            weight: FontWeight.w700,
            color: GdeColors.white,
          ),
        ),
      ),
    );
  }
}

class _HelixOvalNode extends StatelessWidget {
  const _HelixOvalNode({
    required this.label,
    required this.bgColor,
    required this.textColor,
  });

  final String label;
  final Color bgColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 38),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: GdeColors.navy, width: 4),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GdeFonts.sans(
            size: 30,
            weight: FontWeight.w800,
            color: textColor,
            height: 1.18,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SLIDE 12: SHOPIFY REFLEX ARCHITECTURE (MINUTES VS ~4 MINS)
// =============================================================================
class Slide12Widget extends FlutterDeckSlideWidget {
  const Slide12Widget({super.key})
      : super(
          configuration: const FlutterDeckSlideConfiguration(
            route: '/slide-12',
            title: '12 · Shopify Reflex Architecture',
          ),
        );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => GdeSlideCanvas(
        slideNumber: 12,
        isNavy: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'SHOPIFY ENGINEERING · REFLEX ARCHITECTURE',
              style: GdeFonts.monoSub(isNavy: true, color: GdeColors.hPink),
            ),
            const SizedBox(height: 12),
            Text(
              'Shopify Built Reflex to Bypass Slow Simulators.',
              style: GdeFonts.headline(size: 66, isNavy: true),
            ),
            const SizedBox(height: 28),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  Expanded(
                    child: _BigStatCard(
                      tag: '01 · NATIVE SIMULATOR WAIT',
                      stat: 'Minutes',
                      fillPercent: 92,
                      boldLead: 'Emulator boots',
                      rest: 'bottleneck AI agents',
                      accentColor: GdeColors.hPink,
                      dashed: true,
                      statFontSize: 116,
                    ),
                  ),
                  SizedBox(width: 40),
                  Expanded(
                    child: _BigStatCard(
                      tag: '02 · SHOPIFY REFLEX CLI (1,700+ SPECS)',
                      stat: '~4 Mins',
                      fillPercent: 28,
                      boldLead: 'Strips out UI',
                      rest: 'to test ViewModels via CLI',
                      accentColor: GdeColors.hYellow,
                      dashed: false,
                      statFontSize: 116,
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

// =============================================================================
// SLIDE 13: REFLEX VS. FLUTTER HARNESS (2-BAR COVERAGE CHART)
// =============================================================================
class Slide13Widget extends FlutterDeckSlideWidget {
  const Slide13Widget({super.key})
      : super(
          configuration: const FlutterDeckSlideConfiguration(
            route: '/slide-13',
            title: '13 · Reflex Skips UI vs Flutter Tests Widgets',
          ),
        );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => GdeSlideCanvas(
        slideNumber: 13,
        isNavy: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A BETTER HARNESS BEATS A BETTER PROMPT',
                  style: GdeFonts.monoSub(),
                ),
                const SizedBox(height: 10),
                Text(
                  'Reflex Skips the UI; Flutter Tests Widgets Too.',
                  style: GdeFonts.headline(size: 66),
                ),
              ],
            ),
            GdePillBox(
              backgroundColor: GdeColors.slateBg,
              borderColor: GdeColors.navy,
              borderWidth: 4,
              borderRadius: 36,
              padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _LabeledBarHeader(
                    leftTitle: 'Shopify Reflex (2 Codebases)',
                    rightLabel: 'Headless State Only (0% UI)',
                    rightColor: GdeColors.red,
                  ),
                  const SizedBox(height: 14),
                  const _RoundedBarContainer(
                    height: 64,
                    trackColor: GdeColors.pinkTint,
                    borderColor: GdeColors.navy,
                    borderWidth: 4,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 48,
                          child: ColoredBox(
                            color: GdeColors.hYellow,
                            child: SizedBox.expand(),
                          ),
                        ),
                        _VerticalDashedDivider(color: GdeColors.navy, width: 4),
                        Expanded(flex: 52, child: SizedBox.expand()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 38),
                  const _LabeledBarHeader(
                    leftTitle: 'Flutter Test + MCP (1 Codebase)',
                    rightLabel: '100% Logic + Widgets (ms)',
                    rightColor: GdeColors.green,
                  ),
                  const SizedBox(height: 14),
                  const _RoundedBarContainer(
                    height: 64,
                    trackColor: GdeColors.barTrack,
                    borderColor: GdeColors.navy,
                    borderWidth: 4,
                    child: ColoredBox(
                      color: GdeColors.hGreen,
                      child: SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: const [
                Expanded(
                  child: GdePillBox(
                    backgroundColor: GdeColors.hPink,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                    child: Center(
                      child: GdeBulletText(
                        boldLead: 'Reflex skips SwiftUI',
                        rest: 'and Compose UI',
                        fontSize: 26,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 28),
                Expanded(
                  child: GdePillBox(
                    backgroundColor: GdeColors.hGreen,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                    child: Center(
                      child: GdeBulletText(
                        boldLead: 'Flutter tests logic',
                        rest: 'and widgets in ms',
                        fontSize: 26,
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

// =============================================================================
// SLIDE 14: PROBABILISTIC DRIFT VS. DETERMINISTIC FLUTTER + PRISM
// =============================================================================
class Slide14Widget extends FlutterDeckSlideWidget {
  const Slide14Widget({super.key})
      : super(
          configuration: const FlutterDeckSlideConfiguration(
            route: '/slide-14',
            title: '14 · Deterministic Codebase Eliminates Drift',
            preloadImages: {'deck-images/dash-deterministic-sync.png'},
          ),
        );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => GdeSlideCanvas(
        slideNumber: 14,
        isNavy: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 112,
              child: SizedBox(
                height: 860,
                child: GdePillBox(
                  backgroundColor: Colors.transparent,
                  borderColor: GdeColors.hGreen,
                  borderWidth: 4,
                  borderRadius: 48,
                  padding: const EdgeInsets.all(44),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'THE CORE MATH · “ARGUE ONCE, BUILD ONCE”',
                            style: GdeFonts.monoSub(
                              isNavy: true,
                              color: GdeColors.hGreen,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'One Deterministic Codebase Eliminates Cross-Platform Drift.',
                            style: GdeFonts.headline(
                              size: 56,
                              isNavy: true,
                              color: GdeColors.hGreen,
                            ),
                          ),
                        ],
                      ),
                      GdePillBox(
                        backgroundColor: GdeColors.navyDark,
                        borderColor: GdeColors.navyMuted,
                        borderWidth: 2,
                        borderRadius: 28,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 26,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '2× NATIVE (PROBABILISTIC AI)',
                                      style: GdeFonts.mono(
                                        size: 20,
                                        weight: FontWeight.w700,
                                        color: GdeColors.hPink,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      'Full iOS QA + Full Android QA',
                                      style: GdeFonts.mono(
                                        size: 20,
                                        weight: FontWeight.w700,
                                        color: GdeColors.hPink,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _RoundedBarContainer(
                              height: 44,
                              trackColor: GdeColors.navyMuted,
                              borderColor: GdeColors.white,
                              borderWidth: 3,
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 82,
                                    child: Container(
                                      color: GdeColors.navyMuted,
                                      padding: const EdgeInsets.only(left: 20),
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '~95% Match',
                                        style: GdeFonts.mono(
                                          size: 19,
                                          weight: FontWeight.w700,
                                          color: GdeColors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 18,
                                    child: Container(
                                      color: GdeColors.red,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      alignment: Alignment.center,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          '~5% Drift',
                                          style: GdeFonts.mono(
                                            size: 18,
                                            weight: FontWeight.w700,
                                            color: GdeColors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '1× FLUTTER (DETERMINISTIC)',
                                      style: GdeFonts.mono(
                                        size: 20,
                                        weight: FontWeight.w700,
                                        color: GdeColors.hGreen,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      'Zero Logic/UI Drift',
                                      style: GdeFonts.mono(
                                        size: 20,
                                        weight: FontWeight.w700,
                                        color: GdeColors.hGreen,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _RoundedBarContainer(
                              height: 44,
                              trackColor: GdeColors.hGreen,
                              borderColor: GdeColors.white,
                              borderWidth: 3,
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 85,
                                    child: Container(
                                      color: GdeColors.hGreen,
                                      padding: const EdgeInsets.only(left: 20),
                                      alignment: Alignment.centerLeft,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          '~80–90% Shared Logic & UI Tests',
                                          style: GdeFonts.mono(
                                            size: 19,
                                            weight: FontWeight.w700,
                                            color: GdeColors.navy,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 15,
                                    child: Container(
                                      color: GdeColors.hBlue,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      alignment: Alignment.center,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          'OS QA',
                                          style: GdeFonts.mono(
                                            size: 18,
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
                          ],
                        ),
                      ),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GdeBulletText(
                            boldLead: 'Two AI apps need',
                            rest: 'CI divergence checks',
                            fontSize: 32,
                            color: GdeColors.white,
                            boldColor: GdeColors.hPink,
                          ),
                          SizedBox(height: 16),
                          GdeBulletText(
                            boldLead: 'One Dart codebase',
                            rest: 'locks visual parity',
                            fontSize: 32,
                            color: GdeColors.white,
                            boldColor: GdeColors.hBlue,
                          ),
                          SizedBox(height: 16),
                          GdeBulletText(
                            boldLead: 'Teams QA integration',
                            rest: 'instead of logic',
                            fontSize: 32,
                            color: GdeColors.white,
                            boldColor: GdeColors.hGreen,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 48),
            Expanded(
              flex: 88,
              child: Container(
                height: 860,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(48),
                  border: Border.all(color: GdeColors.hBlue, width: 4),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(44),
                  child: Image.asset(
                    'deck-images/dash-deterministic-sync.png',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
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
// SLIDE 15: VERIFICATION IS THE NEW BOTTLENECK
// =============================================================================
class Slide15Widget extends FlutterDeckSlideWidget {
  const Slide15Widget({super.key})
      : super(
          configuration: const FlutterDeckSlideConfiguration(
            route: '/slide-15',
            title: '15 · Verification Is Now the Bottleneck',
            preloadImages: {'deck-images/dash-headless-loop.png'},
          ),
        );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => GdeSlideCanvas(
        slideNumber: 15,
        isNavy: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GdePillBox(
              backgroundColor: GdeColors.navyCallout,
              borderColor: GdeColors.blue,
              borderWidth: 4,
              borderRadius: 36,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 34),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'THE NEW AI BOTTLENECK · VERIFYING > CODING',
                            style: GdeFonts.monoSub(
                              isNavy: true,
                              color: GdeColors.hBlue,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            '← <200ms Hot Reload · Millisecond \$ flutter test',
                            style: GdeFonts.mono(
                              size: 22,
                              weight: FontWeight.w500,
                              color: GdeColors.hGreen,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Verification—Not Coding—Is Now the Bottleneck.',
                    style: GdeFonts.headline(size: 60, isNavy: true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 105,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '{',
                          style: GdeFonts.mono(
                            size: 220,
                            weight: FontWeight.w300,
                            color: GdeColors.blue,
                            height: 1.0,
                          ),
                        ),
                        const SizedBox(width: 24),
                        const Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GdeBulletText(
                                boldLead: 'Reviewing and testing',
                                rest: 'now bottleneck AI',
                                fontSize: 32,
                                color: GdeColors.white,
                                boldColor: GdeColors.hPink,
                              ),
                              SizedBox(height: 28),
                              GdeBulletText(
                                boldLead: 'Flutter reviews once',
                                rest: 'with millisecond tests',
                                fontSize: 32,
                                color: GdeColors.white,
                                boldColor: GdeColors.hGreen,
                              ),
                              SizedBox(height: 28),
                              GdeBulletText(
                                boldLead: 'Flutter MCP verifies',
                                rest: 'live widget trees',
                                fontSize: 32,
                                color: GdeColors.white,
                                boldColor: GdeColors.hBlue,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Text(
                          '}',
                          style: GdeFonts.mono(
                            size: 220,
                            weight: FontWeight.w300,
                            color: GdeColors.blue,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 56),
                  Expanded(
                    flex: 95,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 560),
                      child: Container(
                        height: 560,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(36),
                          border: Border.all(
                            color: GdeColors.hGreen,
                            width: 4,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: Image.asset(
                            'deck-images/dash-headless-loop.png',
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        ),
                      ),
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

// =============================================================================
// SLIDE 16: GIANT CENTERED STATISTIC (70%+) + SPLIT BAR CHART
// =============================================================================
class Slide16Widget extends FlutterDeckSlideWidget {
  const Slide16Widget({super.key})
      : super(
          configuration: const FlutterDeckSlideConfiguration(
            route: '/slide-16',
            title: '16 · Shared Engines Win (70%+ Top Games)',
          ),
        );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => GdeSlideCanvas(
        slideNumber: 16,
        isNavy: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              children: [
                Text(
                  'WHERE CROSS-PLATFORM BEAT NATIVE',
                  style: GdeFonts.monoSub(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Shared Engines Win When Visuals Define Products.',
                  style: GdeFonts.headline(size: 66),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            Text(
              '70%+',
              style: GdeFonts.sans(
                size: 196,
                weight: FontWeight.w800,
                color: GdeColors.navy,
                height: 0.9,
                letterSpacing: -8,
              ),
            ),
            SizedBox(
              width: 1360,
              child: _RoundedBarContainer(
                height: 64,
                trackColor: GdeColors.hYellow,
                borderColor: GdeColors.navy,
                borderWidth: 4,
                child: Row(
                  children: [
                    Expanded(
                      flex: 72,
                      child: Container(
                        padding: const EdgeInsets.only(left: 36, right: 16),
                        decoration: const BoxDecoration(
                          color: GdeColors.green,
                          border: Border(
                            right: BorderSide(color: GdeColors.navy, width: 4),
                          ),
                        ),
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Unity Cross-Platform Engine (70%+ Top 1,000 Mobile Games)',
                            style: GdeFonts.mono(
                              size: 25,
                              weight: FontWeight.w700,
                              color: GdeColors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 28,
                      child: Container(
                        color: GdeColors.hYellow,
                        padding: const EdgeInsets.only(right: 36, left: 12),
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Native / Others',
                            style: GdeFonts.mono(
                              size: 24,
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
            GdePillBox(
              backgroundColor: GdeColors.hBlue,
              borderColor: GdeColors.navy,
              borderWidth: 3,
              borderRadius: 36,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
              child: Row(
                children: const [
                  Expanded(
                    child: Center(
                      child: GdeBulletText(
                        boldLead: 'Unity powers 70%+',
                        rest: 'of top games',
                        fontSize: 23,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    child: Center(
                      child: GdeBulletText(
                        boldLead: 'Studios avoid maintaining',
                        rest: 'two 3D engines',
                        fontSize: 23,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    child: Center(
                      child: GdeBulletText(
                        boldLead: 'One shared engine',
                        rest: 'beats building twice',
                        fontSize: 23,
                        textAlign: TextAlign.center,
                      ),
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

// =============================================================================
// SHARED PRIVATE HELPERS FOR SLIDES 02–16
// =============================================================================

Widget _buildOutlinedCircle(double diameter, Color color, double strokeWidth) {
  return Container(
    width: diameter,
    height: diameter,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: color, width: strokeWidth),
    ),
  );
}

class _LabeledBarHeader extends StatelessWidget {
  const _LabeledBarHeader({
    required this.leftTitle,
    required this.rightLabel,
    required this.rightColor,
  });

  final String leftTitle;
  final String rightLabel;
  final Color rightColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            leftTitle,
            style: GdeFonts.sans(
              size: 36,
              weight: FontWeight.w800,
              color: GdeColors.navy,
            ),
          ),
        ),
        const SizedBox(width: 20),
        Text(
          rightLabel,
          style: GdeFonts.mono(
            size: 26,
            weight: FontWeight.w700,
            color: rightColor,
          ),
        ),
      ],
    );
  }
}

class _RoundedBarContainer extends StatelessWidget {
  const _RoundedBarContainer({
    required this.height,
    required this.trackColor,
    required this.borderColor,
    required this.borderWidth,
    required this.child,
  });

  final double height;
  final Color trackColor;
  final Color borderColor;
  final double borderWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: child,
      ),
    );
  }
}

class _BigStatCard extends StatelessWidget {
  const _BigStatCard({
    required this.tag,
    required this.stat,
    required this.fillPercent,
    required this.boldLead,
    required this.rest,
    required this.accentColor,
    required this.dashed,
    required this.statFontSize,
  });

  final String tag;
  final String stat;
  final int fillPercent;
  final String boldLead;
  final String rest;
  final Color accentColor;
  final bool dashed;
  final double statFontSize;

  @override
  Widget build(BuildContext context) {
    return GdePillBox(
      backgroundColor: GdeColors.navyCard,
      borderColor: accentColor,
      borderWidth: 4,
      borderRadius: 36,
      dashed: dashed,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 44),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              tag,
              style: GdeFonts.mono(
                size: 24,
                weight: FontWeight.w700,
                color: accentColor,
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              stat,
              style: GdeFonts.sans(
                size: statFontSize,
                weight: FontWeight.w800,
                color: accentColor,
                height: 1.0,
              ),
            ),
          ),
          _RoundedBarContainer(
            height: 28,
            trackColor: GdeColors.navyDeep,
            borderColor: accentColor,
            borderWidth: 3,
            child: Row(
              children: [
                Expanded(
                  flex: fillPercent,
                  child: ColoredBox(
                    color: accentColor,
                    child: const SizedBox.expand(),
                  ),
                ),
                Expanded(
                  flex: 100 - fillPercent,
                  child: const SizedBox.expand(),
                ),
              ],
            ),
          ),
          GdeBulletText(
            boldLead: boldLead,
            rest: rest,
            fontSize: 28,
            color: GdeColors.white,
            boldColor: accentColor,
          ),
        ],
      ),
    );
  }
}

class _VerticalDashedDivider extends StatelessWidget {
  const _VerticalDashedDivider({
    required this.color,
    required this.width,
  });

  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: double.infinity,
      child: CustomPaint(
        painter: _VerticalDashedLinePainter(color: color, strokeWidth: width),
      ),
    );
  }
}

class _VerticalDashedLinePainter extends CustomPainter {
  const _VerticalDashedLinePainter({
    required this.color,
    required this.strokeWidth,
  });

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    const dashHeight = 8.0;
    const dashSpace = 6.0;
    final x = size.width / 2;
    var y = 0.0;
    while (y < size.height) {
      final endY = (y + dashHeight).clamp(0.0, size.height);
      canvas.drawLine(Offset(x, y), Offset(x, endY), paint);
      y += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _VerticalDashedLinePainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}
