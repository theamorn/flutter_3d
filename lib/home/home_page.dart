import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/booking.dart';
import '../ui/booking_page.dart';
import 'shader_backdrop.dart';

/// The hotel's name everywhere in the app.
const String kHotelName = 'Seaside Family Hotel';

/// Builds a backdrop. [sea] is the sea's heading and wave height, from
/// dragging and tapping the hero; the banner's sky gets a still one.
typedef BackdropBuilder = Widget Function(
  HomeShader shader,
  ValueListenable<SeaInput> sea,
);

/// The real backdrops; tests pass plain boxes instead.
Widget shaderBackdrop(HomeShader shader, ValueListenable<SeaInput> sea) =>
    ShaderBackdrop(shader: shader, sea: sea);

/// Radians the sea turns per logical pixel dragged: a full-width swipe on a
/// phone turns it about 90 degrees.
const double _lookPerPixel = 0.004;

/// The hero opens on the second of [kSeaLevels], the sea's look before taps
/// could change it.
const int _startLevel = 1;

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
          backdrop(HomeShader.sky, kStillSea),
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
/// sideways turns the camera and tapping it swells the waves, which is what
/// shows it's live and not a video.
class _Hero extends StatefulWidget {
  const _Hero({required this.backdrop, required this.onTakeTour});

  final BackdropBuilder backdrop;
  final VoidCallback onTakeTour;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with SingleTickerProviderStateMixin {
  int _level = _startLevel;
  final ValueNotifier<SeaInput> _sea = ValueNotifier((
    look: 0.0,
    height: kSeaLevels[_startLevel],
  ));
  final Tween<double> _height = Tween(
    begin: kSeaLevels[_startLevel],
    end: kSeaLevels[_startLevel],
  );
  // From the mixin, so the swell pauses while the Home tab is hidden.
  late final AnimationController _swell = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..addListener(_swellStep);
  bool _touched = false;

  @override
  void dispose() {
    _swell.dispose();
    _sea.dispose();
    super.dispose();
  }

  void _swellStep() {
    final t = Curves.easeInOut.transform(_swell.value);
    _sea.value = (look: _sea.value.look, height: _height.transform(t));
  }

  // Ease from wherever the waves are, so a quick second tap doesn't jump.
  void _nextLevel() {
    setState(() {
      _level = (_level + 1) % kSeaLevels.length;
      _touched = true;
    });
    _height
      ..begin = _sea.value.height
      ..end = kSeaLevels[_level];
    _swell.forward(from: 0);
  }

  // Sideways only, so a vertical drag on the hero still scrolls the page.
  void _drag(DragUpdateDetails d) {
    final sea = _sea.value;
    _sea.value = (
      look: sea.look - d.delta.dx * _lookPerPixel,
      height: sea.height,
    );
    if (!_touched) setState(() => _touched = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _nextLevel,
      onHorizontalDragUpdate: _drag,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height / 3,
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.backdrop(HomeShader.sea, _sea),
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
              left: 16,
              right: 16,
              child: Align(
                alignment: Alignment.topRight,
                child: _WavePill(level: _level, hint: !_touched),
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

/// The hero's top-right pill: a wave meter that stays, and until the first
/// tap or drag, a hint at what the hero does.
class _WavePill extends StatelessWidget {
  const _WavePill({required this.level, required this.hint});

  /// Index into [kSeaLevels].
  final int level;
  final bool hint;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Colors.black38,
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.waves, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          _WaveMeter(level: level),
          // Flexible, so on a narrow phone the hint wraps instead of overflowing.
          Flexible(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              child: hint
                  ? const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Text(
                        'Tap for bigger waves · drag to look around',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Five bars rising like the waves: the current level and those below it lit.
class _WaveMeter extends StatelessWidget {
  const _WaveMeter({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Waves ${level + 1} of ${kSeaLevels.length}',
    child: Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < kSeaLevels.length; i++)
          Container(
            width: 3,
            height: 6 + 2.0 * i,
            margin: EdgeInsets.only(left: i == 0 ? 0 : 2),
            decoration: BoxDecoration(
              color: i <= level ? Colors.white : Colors.white30,
              borderRadius: const BorderRadius.all(Radius.circular(1.5)),
            ),
          ),
      ],
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
