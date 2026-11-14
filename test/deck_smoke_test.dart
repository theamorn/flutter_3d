import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_3d/main_deck.dart';
import 'package:flutter_deck/flutter_deck.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets(
    'AgentEraFlutterDeckApp renders all 23 slides at 1920x1080 with zero layout overflows',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1920, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(const AgentEraFlutterDeckApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('01 / 23'), findsOneWidget);

      // Verify keyboard ArrowRight advances Slide 1 -> Slide 2
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('02 / 23'), findsOneWidget);

      // Step through every remaining slide (3..23) and assert zero render errors
      for (var slide = 3; slide <= 23; slide++) {
        final deckContext = tester.element(find.byType(Scaffold).first);
        deckContext.flutterDeck.next();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final label = '${slide.toString().padLeft(2, '0')} / 23';
        expect(
          find.text(label),
          findsOneWidget,
          reason: 'Expected slide badge $label on slide $slide',
        );
      }
    },
  );
}
