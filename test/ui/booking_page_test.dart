import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/data/booking.dart';
import 'package:flutter_3d/ui/booking_page.dart';

void main() {
  BookingQuote quote() => BookingQuote(
    option: RoomOption.familySuiteConnected,
    checkIn: DateTime(2026, 12, 24),
    nights: 2,
    adults: 2,
    children: 2,
  );

  testWidgets('fallback header and room or nights update the total', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: BookingPage(initial: quote())));
    expect(find.byIcon(Icons.hotel), findsOneWidget);
    expect(find.text('฿25,659'), findsOneWidget);

    await tester.tap(find.text('Family Room'));
    await tester.pumpAndSettle();
    expect(find.text('฿13,889'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('nights-plus')));
    await tester.tap(find.byKey(const Key('nights-plus')));
    await tester.pumpAndSettle();
    expect(find.text('฿20,833'), findsOneWidget);
  });

  testWidgets('guest steppers respect their limits', (tester) async {
    await tester.pumpWidget(MaterialApp(home: BookingPage(initial: quote())));
    await tester.ensureVisible(find.byKey(const Key('children-minus')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('children-minus')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('children-minus')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('children-minus')), findsOneWidget);
    final minus = tester.widget<IconButton>(
      find.byKey(const Key('children-minus')),
    );
    expect(minus.onPressed, isNull);
  });

  testWidgets('confirm returns to the previous route and announces demo mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BookingPage(initial: quote()),
                ),
              ),
              child: const Text('Enter tour'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Enter tour'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirm booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm booking'));
    await tester.pumpAndSettle();
    expect(find.text('Enter tour'), findsOneWidget);
    expect(find.text('Demo only — no booking made'), findsOneWidget);
  });
}
