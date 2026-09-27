import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/data/booking.dart';
import 'package:flutter_3d/home/home_page.dart';
import 'package:flutter_3d/home/shader_backdrop.dart';
import 'package:flutter_3d/ui/booking_page.dart';

/// Stands in for the shader backdrops: widget tests can't load shaders. It
/// prints the look and the wave height it was handed, so a test can see a
/// drag or a tap reach it.
Widget _plainBackdrop(HomeShader shader, ValueListenable<SeaInput> sea) =>
    ColoredBox(
      key: Key('backdrop-${shader.name}'),
      color: Colors.blue,
      child: ValueListenableBuilder<SeaInput>(
        valueListenable: sea,
        builder: (_, input, _) => Column(
          children: [
            Text('${shader.name} look=${input.look.toStringAsFixed(2)}'),
            Text('${shader.name} height=${input.height.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );

const String _hint = 'Tap for bigger waves · drag to look around';

Future<void> _pumpHome(WidgetTester tester, {VoidCallback? onTakeTour}) =>
    tester.pumpWidget(
      MaterialApp(
        home: HomePage(onTakeTour: onTakeTour ?? () {}, backdrop: _plainBackdrop),
      ),
    );

/// A spot on the sea clear of the title, the tour button and the hint pill.
Offset _seaSpot(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(const Key('backdrop-sea'))) +
    const Offset(20, 60);

void main() {
  testWidgets('the hero shows the hotel name over the sea backdrop', (
    tester,
  ) async {
    await _pumpHome(tester);
    expect(find.text(kHotelName), findsOneWidget);
    expect(find.byKey(const Key('backdrop-sea')), findsOneWidget);
  });

  testWidgets('the hero starts on wave level 2 of 5, with the hint', (
    tester,
  ) async {
    await _pumpHome(tester);
    expect(find.bySemanticsLabel('Waves 2 of 5'), findsOneWidget);
    expect(find.text('sea height=0.30'), findsOneWidget);
    expect(find.text(_hint), findsOneWidget);
  });

  testWidgets(
    'each tap on the hero swells the sea a level, then wraps to calm',
    (tester) async {
      await _pumpHome(tester);
      for (final (level, height) in [
        (3, '0.50'),
        (4, '0.75'),
        (5, '1.00'),
        (1, '0.10'),
      ]) {
        await tester.tapAt(_seaSpot(tester));
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Waves $level of 5'), findsOneWidget);
        expect(find.text('sea height=$height'), findsOneWidget);
      }
      expect(find.text('sea look=0.00'), findsOneWidget);
    },
  );

  testWidgets('the waves ease to their new height rather than jump', (
    tester,
  ) async {
    await _pumpHome(tester);
    await tester.tapAt(_seaSpot(tester));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('sea height=0.30'), findsNothing);
    expect(find.text('sea height=0.50'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('sea height=0.50'), findsOneWidget);
  });

  testWidgets('the swell waits while the Home tab is hidden', (tester) async {
    Widget app({required bool ticking}) => MaterialApp(
      home: TickerMode(
        enabled: ticking,
        child: HomePage(onTakeTour: () {}, backdrop: _plainBackdrop),
      ),
    );
    await tester.pumpWidget(app(ticking: false));
    await tester.tapAt(_seaSpot(tester));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('sea height=0.30'), findsOneWidget);

    await tester.pumpWidget(app(ticking: true));
    await tester.pumpAndSettle();
    expect(find.text('sea height=0.50'), findsOneWidget);
  });

  testWidgets('tapping the hero hides the hint but keeps the wave meter', (
    tester,
  ) async {
    await _pumpHome(tester);
    await tester.tapAt(_seaSpot(tester));
    await tester.pumpAndSettle();
    expect(find.text(_hint), findsNothing);
    expect(find.bySemanticsLabel('Waves 3 of 5'), findsOneWidget);
  });

  testWidgets('dragging the hero sideways turns the sea, keeps its waves and '
      'hides the hint', (tester) async {
    await _pumpHome(tester);
    expect(find.text('sea look=0.00'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('backdrop-sea')),
      const Offset(-200, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('sea look=0.00'), findsNothing);
    expect(find.text('sea height=0.30'), findsOneWidget);
    expect(find.bySemanticsLabel('Waves 2 of 5'), findsOneWidget);
    expect(find.text(_hint), findsNothing);
  });

  testWidgets('dragging the hero up still scrolls the page, not the sea', (
    tester,
  ) async {
    await _pumpHome(tester);
    final heroTop = tester.getTopLeft(find.byKey(const Key('backdrop-sea'))).dy;

    await tester.drag(
      find.byKey(const Key('backdrop-sea')),
      const Offset(0, -150),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(const Key('backdrop-sea'))).dy,
      lessThan(heroTop),
    );
    expect(find.text('sea look=0.00'), findsOneWidget);
    expect(find.text('sea height=0.30'), findsOneWidget);
  });

  testWidgets('Take the 3D tour calls back and leaves the waves alone', (
    tester,
  ) async {
    var taps = 0;
    await _pumpHome(tester, onTakeTour: () => taps++);
    await tester.tap(find.text('Take the 3D tour'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(find.bySemanticsLabel('Waves 2 of 5'), findsOneWidget);
    expect(find.text('sea height=0.30'), findsOneWidget);
  });

  testWidgets('room prices come from the booking constants', (tester) async {
    await _pumpHome(tester);
    for (final nightly in [
      kFamilyRoomNightlyThb,
      kFamilySuiteConnectedNightlyThb,
    ]) {
      final price = find.text('${formatThb(nightly)} / night');
      await tester.scrollUntilVisible(price, 200);
      expect(price, findsOneWidget);
    }
  });

  for (final option in RoomOption.values) {
    testWidgets('Book on ${option.name} opens the booking page on that room', (
      tester,
    ) async {
      await _pumpHome(tester);
      final book = find.byKey(Key('book-${option.name}'));
      await tester.scrollUntilVisible(book, 200);
      await tester.tap(book);
      await tester.pumpAndSettle();
      final page = tester.widget<BookingPage>(find.byType(BookingPage));
      expect(page.initial.option, option);
      expect(page.preview, isNull);
    });
  }

  testWidgets('the banner books the Family Room over the sky backdrop', (
    tester,
  ) async {
    await _pumpHome(tester);
    final banner = find.byKey(const Key('book-banner'));
    await tester.scrollUntilVisible(banner, 200);
    expect(find.byKey(const Key('backdrop-sky')), findsOneWidget);
    await tester.tap(banner);
    await tester.pumpAndSettle();
    expect(
      tester.widget<BookingPage>(find.byType(BookingPage)).initial.option,
      RoomOption.familyRoom,
    );
  });

  testWidgets('fits a small phone without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pumpHome(tester);
    await tester.scrollUntilVisible(find.byKey(const Key('book-banner')), 200);
    expect(tester.takeException(), isNull);
  });
}
