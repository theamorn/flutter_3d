import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../data/booking.dart';

class BookingPage extends StatefulWidget {
  const BookingPage({super.key, required this.initial, this.preview});

  final BookingQuote initial;

  /// Ownership passes to this page; the captured GPU image is disposed on pop.
  final ui.Image? preview;

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  late BookingQuote quote = widget.initial;

  @override
  void dispose() {
    widget.preview?.dispose();
    super.dispose();
  }

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day);
    final last = DateTime(first.year, first.month, first.day + 365);
    final picked = await showDatePicker(
      context: context,
      initialDate: quote.checkIn.isBefore(first)
          ? first
          : (quote.checkIn.isAfter(last) ? last : quote.checkIn),
      firstDate: first,
      lastDate: last,
    );
    if (picked != null && mounted) {
      setState(() => quote = quote.copyWith(checkIn: picked));
    }
  }

  Widget _stepper(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> changed,
  ) => Row(
    children: [
      Expanded(child: Text(label)),
      IconButton(
        key: Key('${label.toLowerCase()}-minus'),
        tooltip: 'Decrease $label',
        onPressed: value > min
            ? () => setState(() => changed(value - 1))
            : null,
        icon: const Icon(Icons.remove_circle_outline),
      ),
      SizedBox(width: 28, child: Text('$value', textAlign: TextAlign.center)),
      IconButton(
        key: Key('${label.toLowerCase()}-plus'),
        tooltip: 'Increase $label',
        onPressed: value < max
            ? () => setState(() => changed(value + 1))
            : null,
        icon: const Icon(Icons.add_circle_outline),
      ),
    ],
  );

  Widget _priceRow(String label, int price, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: bold ? const TextStyle(fontWeight: FontWeight.bold) : null,
          ),
        ),
        Text(
          formatThb(price),
          style: bold
              ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)
              : null,
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book your stay')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            SizedBox(
              height: 210,
              child: widget.preview == null
                  ? const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xff155e75),
                            Color(0xff74c9d4),
                            Color(0xffead6aa),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Icon(Icons.hotel, size: 72, color: Colors.white),
                      ),
                    )
                  : RawImage(image: widget.preview, fit: BoxFit.cover),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Choose your room',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<RoomOption>(
                    segments: const [
                      ButtonSegment(
                        value: RoomOption.familyRoom,
                        label: Text('Family Room'),
                      ),
                      ButtonSegment(
                        value: RoomOption.familySuiteConnected,
                        label: Text('Family Suite\n(2 connected rooms)'),
                      ),
                    ],
                    selected: {quote.option},
                    onSelectionChanged: (selection) => setState(
                      () => quote = quote.copyWith(option: selection.single),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Check-in'),
                    subtitle: Text(_date(quote.checkIn)),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: _pickDate,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Check-out'),
                    subtitle: Text(_date(quote.checkOut)),
                  ),
                  const Divider(),
                  _stepper(
                    'Nights',
                    quote.nights,
                    1,
                    30,
                    (v) => quote = quote.copyWith(nights: v),
                  ),
                  _stepper(
                    'Adults',
                    quote.adults,
                    1,
                    4,
                    (v) => quote = quote.copyWith(adults: v),
                  ),
                  _stepper(
                    'Children',
                    quote.children,
                    0,
                    4,
                    (v) => quote = quote.copyWith(children: v),
                  ),
                  const Divider(height: 32),
                  _priceRow(
                    '${formatThb(quote.nightlyRateThb)} × ${quote.nights} nights',
                    quote.subtotalThb,
                  ),
                  _priceRow('Service charge (10%)', quote.serviceChargeThb),
                  _priceRow('VAT (7%)', quote.vatThb),
                  const Divider(),
                  _priceRow('Total', quote.totalThb, bold: true),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Demo only — no booking made'),
                        ),
                      );
                      Navigator.of(context).pop();
                    },
                    child: const Text('Confirm booking'),
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
