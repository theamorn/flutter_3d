import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/data/booking.dart';
import 'package:flutter_3d/home/home_page.dart';
import 'package:flutter_3d/home/shader_backdrop.dart';
import 'package:flutter_3d/ui/booking_page.dart';

/// Stands in for the shader backdrops: widget tests can't load shaders.
Widget _plainBackdrop(HomeShader shader) =>
    ColoredBox(key: Key('backdrop-${shader.name}'), color: Colors.blue);

Future<void> _pumpHome(WidgetTester tester, {VoidCallback? onTakeTour}) =>
    tester.pumpWidget(
      MaterialApp(
        home: HomePage(onTakeTour: onTakeTour ?? () {}, backdrop: _plainBackdrop),
      ),
    );

void main() {
  testWidgets('the hero shows the hotel name over the sea backdrop', (
    tester,
  ) async {
    await _pumpHome(tester);
    expect(find.text(kHotelName), findsOneWidget);
    expect(find.byKey(const Key('backdrop-sea')), findsOneWidget);
  });

  testWidgets('Take the 3D tour calls back', (tester) async {
    var taps = 0;
    await _pumpHome(tester, onTakeTour: () => taps++);
    await tester.tap(find.text('Take the 3D tour'));
    expect(taps, 1);
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
