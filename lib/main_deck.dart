import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_deck/flutter_deck.dart';

import 'deck/deck_theme.dart';
import 'deck/slides/slide_01_cover.dart';
import 'deck/slides/slide_05_thesis.dart';
import 'deck/slides/slide_17_visuals.dart';
import 'deck/slides/slide_18_unity_for_apps.dart';
import 'deck/slides/slides_02_to_16.dart';
import 'deck/slides/slides_19_to_23.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AgentEraFlutterDeckApp());
}

class AgentEraFlutterDeckApp extends StatelessWidget {
  const AgentEraFlutterDeckApp({super.key});

  static const List<Widget> allSlides = [
    Slide01Widget(),
    Slide02Widget(),
    Slide03Widget(),
    Slide04Widget(),
    Slide05Widget(),
    Slide06Widget(),
    Slide07Widget(),
    Slide08Widget(),
    Slide09Widget(),
    Slide10Widget(),
    Slide11Widget(),
    Slide12Widget(),
    Slide13Widget(),
    Slide14Widget(),
    Slide15Widget(),
    Slide16Widget(),
    Slide17Widget(),
    Slide18Widget(),
    Slide19Widget(),
    Slide20Widget(),
    Slide21Widget(),
    Slide22Widget(),
    Slide23Widget(),
  ];

  @override
  Widget build(BuildContext context) {
    final deckTheme = FlutterDeckThemeData.fromTheme(
      ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: GdeColors.blue,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: GdeColors.white,
        useMaterial3: true,
      ),
    ).copyWith(
      slideTheme: const FlutterDeckSlideThemeData(
        color: GdeColors.navy,
        backgroundColor: GdeColors.white,
      ),
    );

    return FlutterDeckApp(
      themeMode: ThemeMode.light,
      lightTheme: deckTheme,
      darkTheme: deckTheme,
      speakerInfo: const FlutterDeckSpeakerInfo(
        name: 'Amorn Apichattanakul',
        description: 'Senior Innovation Engineer @KBTG',
        socialHandle: 'GDG DevFest 2026',
        imagePath: 'deck-images/dash.png',
      ),
      configuration: FlutterDeckConfiguration(
        slideSize: FlutterDeckSlideSize.fromAspectRatio(
          aspectRatio: const FlutterDeckAspectRatio.ratio16x9(),
          resolution: const FlutterDeckResolution.fhd(),
        ),
        header: const FlutterDeckHeaderConfiguration(showHeader: false),
        footer: const FlutterDeckFooterConfiguration(showFooter: false),
        showProgress: false,
        transition: const FlutterDeckTransition.none(),
        controls: const FlutterDeckControlsConfiguration(
          presenterToolbarVisible: true,
          gestures: FlutterDeckGesturesConfiguration.disabled(),
          shortcuts: FlutterDeckShortcutsConfiguration(
            enabled: true,
            nextSlide: {
              SingleActivator(LogicalKeyboardKey.arrowRight),
              SingleActivator(LogicalKeyboardKey.pageDown),
              SingleActivator(LogicalKeyboardKey.space),
            },
            previousSlide: {
              SingleActivator(LogicalKeyboardKey.arrowLeft),
              SingleActivator(LogicalKeyboardKey.pageUp),
            },
            toggleMarker: {SingleActivator(LogicalKeyboardKey.keyM)},
            toggleNavigationDrawer: {
              SingleActivator(LogicalKeyboardKey.period),
            },
          ),
        ),
      ),
      slides: allSlides,
    );
  }
}
