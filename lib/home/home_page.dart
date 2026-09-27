import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/booking.dart';
import '../ui/booking_page.dart';
import 'shader_backdrop.dart';

/// The hotel's name everywhere in the app.
const String kHotelName = 'Seaside Family Hotel';

/// Builds a backdrop. [look] is the sea's extra heading in radians, from
/// dragging the hero; the banner's sky gets a still one.
typedef BackdropBuilder =
    Widget Function(HomeShader shader, ValueListenable<double> look);

/// The real backdrops; tests pass plain boxes instead.
Widget shaderBackdrop(HomeShader shader, ValueListenable<double> look) =>
    ShaderBackdrop(shader: shader, look: look);

/// Radians the sea turns per logical pixel dragged: a full-width swipe on a
/// phone turns it about 90 degrees.
const double _lookPerPixel = 0.004;

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
          SliverToBoxAdapter(
            child: _Hero(backdrop: backdrop, onTakeTour: onTakeTour),
          ),
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

  Widget _banner(BuildContext context, ThemeData theme) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: SizedBox(
      height: 160,
      child: Stack(
        fit: StackFit.expand,
        children: [
          backdrop(HomeShader.sky, const AlwaysStoppedAnimation(0)),
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

/// The sea over a third of the screen, with the hotel's name. Dragging it
/// sideways turns the camera, which is what shows it's live and not a video.
class _Hero extends StatefulWidget {
  const _Hero({required this.backdrop, required this.onTakeTour});

  final BackdropBuilder backdrop;
  final VoidCallback onTakeTour;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  final ValueNotifier<double> _look = ValueNotifier(0);
  bool _dragged = false;

  @override
  void dispose() {
    _look.dispose();
    super.dispose();
  }

  // Sideways only, so a vertical drag on the hero still scrolls the page.
  void _drag(DragUpdateDetails d) {
    _look.value -= d.delta.dx * _lookPerPixel;
    if (!_dragged) setState(() => _dragged = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: _drag,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height / 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.backdrop(HomeShader.sea, _look),
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
              top: MediaQuery.paddingOf(context).top + 12,
              right: 16,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _dragged ? const SizedBox.shrink() : const _DragHint(),
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
                    onPressed: widget.onTakeTour,
                    icon: const Icon(Icons.threed_rotation),
                    label: const Text('Take the 3D tour'),
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

class _DragHint extends StatelessWidget {
  const _DragHint();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.black38,
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.swipe, size: 18, color: Colors.white),
          SizedBox(width: 6),
          Text('Drag to look around', style: TextStyle(color: Colors.white)),
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
