import 'package:flutter/material.dart';

import '../data/booking.dart';
import '../ui/booking_page.dart';
import 'shader_backdrop.dart';

/// The hotel's name everywhere in the app.
const String kHotelName = 'Seaside Family Hotel';

typedef BackdropBuilder = Widget Function(HomeShader shader);

/// The real backdrops; tests pass plain boxes instead.
Widget shaderBackdrop(HomeShader shader) => ShaderBackdrop(shader: shader);

class _Room {
  const _Room(this.option, this.title, this.blurb, this.nightlyThb);
  final RoomOption option;
  final String title, blurb;
  final int nightlyThb;
}

const List<_Room> _rooms = [
  _Room(
    RoomOption.familyRoom,
    'Family Room',
    'Sea-view balcony, walk-in shower, TV and sofa.',
    kFamilyRoomNightlyThb,
  ),
  _Room(
    RoomOption.familySuiteConnected,
    'Family Suite (2 connected rooms)',
    'Two family rooms joined by a connecting door, each with its own balcony.',
    kFamilySuiteConnectedNightlyThb,
  ),
];

/// Only what the 3D hotel actually models.
const List<(IconData, String)> _amenities = [
  (Icons.balcony, 'Sea-view balcony'),
  (Icons.beach_access, 'Beach below'),
  (Icons.meeting_room, 'Connecting rooms'),
  (Icons.shower, 'Walk-in shower'),
  (Icons.tv, 'TV and sofa'),
  (Icons.menu_book, 'Bookshelf'),
];

/// The Home tab: an ordinary hotel-app page. The 3D lives in the next tab.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.onTakeTour,
    this.backdrop = shaderBackdrop,
  });

  /// Selects the Home Demo tab.
  final VoidCallback onTakeTour;
  final BackdropBuilder backdrop;

  void _book(BuildContext context, RoomOption option) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => BookingPage(
            initial: BookingQuote.standard(option, now: DateTime.now()),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _hero(context, theme)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text('Rooms', style: theme.textTheme.titleLarge),
            ),
          ),
          SliverList.list(
            children: [
              for (final room in _rooms)
                _RoomCard(room: room, onBook: () => _book(context, room.option)),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text('Amenities', style: theme.textTheme.titleLarge),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (icon, label) in _amenities)
                    Chip(avatar: Icon(icon, size: 18), label: Text(label)),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(child: _banner(context, theme)),
          ),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context, ThemeData theme) => SizedBox(
    height: MediaQuery.sizeOf(context).height / 3,
    child: Stack(
      fit: StackFit.expand,
      children: [
        backdrop(HomeShader.sea),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black54],
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                kHotelName,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onTakeTour,
                icon: const Icon(Icons.threed_rotation),
                label: const Text('Take the 3D tour'),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _banner(BuildContext context, ThemeData theme) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: SizedBox(
      height: 160,
      child: Stack(
        fit: StackFit.expand,
        children: [
          backdrop(HomeShader.sky),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Book your stay',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF0B3D63),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('book-banner'),
                  onPressed: () => _book(context, RoomOption.familyRoom),
                  child: const Text('Book now'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room, required this.onBook});

  final _Room room;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(room.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(room.blurb, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${formatThb(room.nightlyThb)} / night',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                FilledButton.tonal(
                  key: Key('book-${room.option.name}'),
                  onPressed: onBook,
                  child: const Text('Book'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
