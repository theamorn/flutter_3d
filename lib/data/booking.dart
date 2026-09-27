/// Demo nightly rates in Thai baht; change these to update every quote.
const int kFamilyRoomNightlyThb = 5900;
const int kFamilySuiteConnectedNightlyThb = 10900;

enum RoomOption { familyRoom, familySuiteConnected }

class BookingQuote {
  BookingQuote({
    required this.option,
    required this.checkIn,
    required this.nights,
    required this.adults,
    required this.children,
  });

  /// The quote every Book button opens with: check-in tomorrow, 2 nights,
  /// 2 adults and 2 children.
  factory BookingQuote.standard(RoomOption option, {required DateTime now}) =>
      BookingQuote(
        option: option,
        checkIn: DateTime(now.year, now.month, now.day + 1),
        nights: 2,
        adults: 2,
        children: 2,
      );

  final RoomOption option;
  final DateTime checkIn;
  final int nights, adults, children;

  int get nightlyRateThb => option == RoomOption.familyRoom
      ? kFamilyRoomNightlyThb
      : kFamilySuiteConnectedNightlyThb;
  int get subtotalThb => nightlyRateThb * nights;
  int get serviceChargeThb => (subtotalThb * 0.10).round();
  int get vatThb => ((subtotalThb + serviceChargeThb) * 0.07).round();
  int get totalThb => subtotalThb + serviceChargeThb + vatThb;
  DateTime get checkOut =>
      DateTime(checkIn.year, checkIn.month, checkIn.day + nights);

  BookingQuote copyWith({
    RoomOption? option,
    DateTime? checkIn,
    int? nights,
    int? adults,
    int? children,
  }) => BookingQuote(
    option: option ?? this.option,
    checkIn: checkIn ?? this.checkIn,
    nights: nights ?? this.nights,
    adults: adults ?? this.adults,
    children: children ?? this.children,
  );
}

String formatThb(int value) {
  final digits = value.abs().toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
  return '${value < 0 ? '-' : ''}฿$grouped';
}
