import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/data/pokemon.dart';
import 'package:flutter_3d/features/book_page.dart';

void main() {
  testWidgets('BookPage shows Loading… when result is null', (tester) async {
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BookPage(result: null),
        ),
      ),
    );

    expect(find.text('Loading…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('BookPage shows error and triggers onRetry when tap retry', (tester) async {
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookPage(
            result: PokemonLoadFailure('Network error'),
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('Couldn\'t load — tap to retry'), findsOneWidget);
    await tester.tap(find.text('Couldn\'t load — tap to retry'));
    expect(retried, isTrue);
  });

  testWidgets('BookPage shows PokemonLoaded details', (tester) async {
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final p = Pokemon(
      id: 25,
      name: 'pikachu',
      types: ['electric'],
      stats: {
        'hp': 35,
        'attack': 55,
        'defense': 40,
        'special-attack': 50,
        'special-defense': 50,
        'speed': 90,
      },
      artworkUrl: '',
      heightDm: 4,
      weightHg: 60,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookPage(result: PokemonLoaded(p)),
        ),
      ),
    );

    expect(find.text('#025 Pikachu'), findsOneWidget);
    expect(find.text('ELECTRIC'), findsOneWidget);
    expect(find.text('Height: 0.4 m'), findsOneWidget);
    expect(find.text('Weight: 6.0 kg'), findsOneWidget);
    expect(find.text('HP'), findsOneWidget);
    expect(find.text('35'), findsOneWidget);
    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('90'), findsOneWidget);
  });
}
