import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/data/booking.dart';

void main() {
  final quote = BookingQuote(
    option: RoomOption.familySuiteConnected,
    checkIn: DateTime(2026, 12, 24),
    nights: 3,
    adults: 2,
    children: 2,
  );

  test('price breakdown and room selection', () {
    expect(quote.subtotalThb, 32700);
    expect(quote.serviceChargeThb, 3270);
    expect(quote.vatThb, 2518);
    expect(quote.totalThb, 38488);
    expect(quote.copyWith(option: RoomOption.familyRoom).nightlyRateThb, 5900);
  });

  test('check-out crosses year without elapsed-time drift', () {
    expect(quote.checkOut, DateTime(2026, 12, 27));
    expect(quote.copyWith(nights: 9).checkOut, DateTime(2027, 1, 2));
  });

  test('formatThb groups thousands', () {
    expect(formatThb(38488), '฿38,488');
    expect(formatThb(900), '฿900');
  });

  test('the standard quote starts tomorrow: 2 nights, 2 adults, 2 children', () {
    final q = BookingQuote.standard(
      RoomOption.familyRoom,
      now: DateTime(2026, 12, 31, 23, 30),
    );
    expect(q.option, RoomOption.familyRoom);
    expect(q.checkIn, DateTime(2027, 1, 1));
    expect((q.nights, q.adults, q.children), (2, 2, 2));
  });
}
