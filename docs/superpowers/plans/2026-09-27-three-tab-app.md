# Three-Tab App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the hotel app into a three-tab app: **Home** (a hotel-app home page decorated with 2D shaders), **Home Demo** (the existing 3D hotel) and **Island Demo** (the `flutter_scene` island copied from `flutter-inapp-ios/flutter_module`).

**Architecture:**
- `AppShell` holds the three tabs:
  - a bottom `NavigationBar`;
  - an `IndexedStack` whose 3D tabs are built on their first visit and kept;
  - a `TickerMode(enabled: selected)` around every tab, so only the visible tab ticks.
- The island is a one-time copy into `lib/island/`. Its assets and tests come with it; only the import paths are rewritten.
- `HomePage` is ordinary Flutter. Its two shader backdrops come from one `ShaderBackdrop` widget.

**Tech Stack:** Flutter 3.47.2 via `fvm`, flutter_scene 0.23.0 (Flutter GPU), vector_math, flutter_test. No new packages.

**Spec:** `docs/superpowers/specs/2026-09-27-three-tab-app-design.md`. Read it before your task.

## Global Constraints

- Run tools through fvm: `fvm flutter test`, `fvm flutter analyze lib test`, `fvm flutter run --enable-flutter-gpu`.
  - If another `fvm flutter run` is up, `fvm` commands wait on its lock. Use `/Users/pikmin/fvm/versions/3.47.2/bin/flutter` directly instead (learning.md).
- flutter_scene stays at 0.23.0. Add no new dependencies.
- Island source: `/Users/pikmin/Documents/flutter-inapp-ios/flutter_module` (below, `$SRC`). Read from it only; never write to it.
- The tab labels are exactly `Home`, `Home Demo`, `Island Demo`, in that order.
- The hotel name is `Seaside Family Hotel`, one constant: `kHotelName`.
- Room prices come only from `kFamilyRoomNightlyThb` and `kFamilySuiteConnectedNightlyThb`, formatted with `formatThb` (`lib/data/booking.dart`).
- Unit and widget tests must not construct `Scene`, `SceneView`, `HotelPage`, `IslandSceneScreen` or a `FragmentShader`, because those need the GPU. Pass stand-ins through the builder parameters.
- Before every commit, `fvm flutter analyze lib test` must show no new issues (one known info in `hook/build.dart`), and `fvm flutter test` must pass.
- `macos/Runner/Info.plist` has an uncommitted change that isn't ours. Never stage it.

## Review Focus

1. **Coming back to a 3D tab:** leaving and returning to a demo must reuse its one state object. No second scene, no "multiple tickers" red screen, and ticking resumes. (Task 3: "built once" test.)
2. **Fast switching:** tapping through the tabs several times still creates each scene exactly once. This is the island's old "two Scenes, two render loops" bug. (Task 3: same test, three rounds.)
3. **Booking from Home, then Back:** Home is still selected, and no 3D scene got built along the way. (Task 3: booking round-trip test.)
4. **A shader that fails to load:** a missing asset or an old GPU must leave the gradient, not an error screen. (Task 2: `ShaderBackdrop` failure test.)
5. **Small phones:** at 320×568 the Home page lays out with no overflow, all the way down to the banner. (Task 2: small-phone test.)

---

### Task 0: Commit the pending learning

`learning.md` has an uncommitted entry: the iPhone costs of the lighting toggles, measured 2026-09-27. Later tasks branch from `main`, so it lands first.

**Files:** `learning.md`

- [ ] **Step 1: Check that it's the only change you'll stage**

Run: `git status --short`
Expected: ` M learning.md` and ` M macos/Runner/Info.plist`. Leave the plist alone.

- [ ] **Step 2: Commit**

```bash
git add learning.md
git commit -m "docs(learning): what the lighting toggles cost on an iPhone 17 Pro Max"
```

### Task 1: Port the island

**Files:**
- Create: `lib/island/` (17 files, including `super_ultra/`), copied from `$SRC/lib/tabs/scene/`
- Create: `test/island/` (11 files, including `super_ultra/`), copied from `$SRC/test/tabs/scene/`
- Create: `assets/models/` (8 `.glb` and `CREDITS.txt`), copied from `$SRC/assets/models/`
- Create: `assets/materials/{ember_bed,grass,heat_haze,island_ground,island_sky,ocean_simple,ocean}.fmat`, copied from `$SRC/assets/materials/`
- Create: `docs/island/06-island-scene.md` and `docs/island/FLUTTER-3D-PLAYBOOK.md`, copied from `$SRC/../docs/hybrid-demo/`. The code's comments point at them.
- Modify: `lib/island/scene_app.dart` (drop `IslandSceneApp`, keep its theme as `kIslandTheme`)
- Modify: `assets/TEXTURE_CREDITS.md` (one line)

**Interfaces:**
- Produces:
  - `IslandSceneScreen`, a `const IslandSceneScreen({super.key})` stateful widget in `package:flutter_3d/island/scene_app.dart`.
  - `final ThemeData kIslandTheme` in the same file.

- [ ] **Step 1: Copy the tests first, and see them fail**

```bash
SRC=/Users/pikmin/Documents/flutter-inapp-ios/flutter_module
mkdir -p test/island
cp -R "$SRC/test/tabs/scene/." test/island/
grep -rl 'package:flutter_module/tabs/scene/' test/island | xargs sed -i '' 's#package:flutter_module/tabs/scene/#package:flutter_3d/island/#g'
fvm flutter test test/island
```

Expected: compile errors such as `Error when reading 'lib/island/particles.dart'`. The code isn't there yet.

- [ ] **Step 2: Copy the code, assets and notes**

```bash
SRC=/Users/pikmin/Documents/flutter-inapp-ios/flutter_module
mkdir -p lib/island assets/models docs/island
cp -R "$SRC/lib/tabs/scene/." lib/island/
cp "$SRC"/assets/models/* assets/models/
cp "$SRC"/assets/materials/*.fmat assets/materials/
cp "$SRC/../docs/hybrid-demo/06-island-scene.md" "$SRC/../docs/hybrid-demo/FLUTTER-3D-PLAYBOOK.md" docs/island/
grep -rl 'package:flutter_module/tabs/scene/' lib/island | xargs sed -i '' 's#package:flutter_module/tabs/scene/#package:flutter_3d/island/#g'
grep -rl 'docs/hybrid-demo/' lib/island | xargs sed -i '' 's#docs/hybrid-demo/#docs/island/#g'
find lib/island -name '*.dart' | wc -l                     # expected: 17
ls assets/models | wc -l                                   # expected: 9
grep -rn 'flutter_module' lib/island test/island           # expected: no output
```

No `pubspec.yaml` change is needed. The build hook compiles every `.glb` and `.fmat` under `assets/` into `flutter_scene_generated/`, which is already an asset directory. `loadScene('assets/models/…')` and `loadFmatMaterial('assets/materials/…')` resolve by source path.

- [ ] **Step 3: Replace the add-to-app wrapper with a theme constant**

In `lib/island/scene_app.dart`, replace the first line:

```dart
/// Route `/scene` — tab 5, the island. See `docs/island/06-island-scene.md`.
```

with:

```dart
/// The Island Demo tab, ported from flutter_module's `/scene` route. See
/// `docs/island/06-island-scene.md`.
```

Then delete the whole `IslandSceneApp` class, from `class IslandSceneApp extends StatelessWidget {` to its closing `}`, which is the column-0 `}` just before `class IslandSceneScreen`:

```bash
perl -0pi -e 's/class IslandSceneApp extends StatelessWidget \{.*?\n\}\n\n(?=class IslandSceneScreen)//s' lib/island/scene_app.dart
grep -c 'IslandSceneApp' lib/island/scene_app.dart         # expected: 0
```

In its place, directly above `class IslandSceneScreen extends StatefulWidget {`, add:

```dart
/// The island's look from flutter_module (the add-to-app wrapper's theme):
/// dark and green-seeded. The app shell wraps the Island Demo tab in it.
final ThemeData kIslandTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF3DA35D),
    brightness: Brightness.dark,
  ),
);

```

- [ ] **Step 4: Credit the models.** Append this line to `assets/TEXTURE_CREDITS.md`:

```markdown
- Island Demo models (`assets/models/*.glb`): see `assets/models/CREDITS.txt`.
```

- [ ] **Step 5: Run the island's tests and the analyzer**

Run: `fvm flutter test test/island && fvm flutter analyze lib test`
Expected: `All tests passed!` (11 files). The analyzer shows no new issues. If it flags something in `lib/island/`, fix only that diagnostic, keeping behaviour identical. The module uses the same `flutter_lints` set, so none is expected.

- [ ] **Step 6: Run the whole suite, then commit**

```bash
fvm flutter test
git add lib/island test/island assets/models assets/materials docs/island assets/TEXTURE_CREDITS.md
git commit -m "feat(island): port the flutter_scene island from flutter_module"
```

### Task 2: Home page with shader backdrops

**Files:**
- Create: `shaders/water.glsl` and `shaders/sky.glsl`, copied from `$SRC/shaders/` and edited in Step 3
- Modify: `pubspec.yaml` (a `shaders:` list under `flutter:`)
- Modify: `lib/data/booking.dart` (`BookingQuote.standard`)
- Modify: `lib/features/entrance_feature.dart:77-86` (use `BookingQuote.standard`)
- Create: `lib/home/shader_backdrop.dart`, `lib/home/home_page.dart`
- Test: `test/data/booking_test.dart`, `test/home/shader_backdrop_test.dart`, `test/home/home_page_test.dart`

**Interfaces:**
- Consumes: `BookingPage({required BookingQuote initial, ui.Image? preview})` from `lib/ui/booking_page.dart`, and `RoomOption`, `formatThb`, `kFamilyRoomNightlyThb`, `kFamilySuiteConnectedNightlyThb` from `lib/data/booking.dart`.
- Produces:
  - `factory BookingQuote.standard(RoomOption option, {required DateTime now})`
  - `enum HomeShader { sea, sky }`, with `String asset` and `List<Color> fallback`
  - `typedef ProgramLoader = Future<ui.FragmentProgram> Function(String asset)`
  - `ShaderBackdrop({Key? key, required HomeShader shader, ProgramLoader loader = ui.FragmentProgram.fromAsset})`, with `static const Key fallbackKey`
  - `const String kHotelName = 'Seaside Family Hotel'`
  - `typedef BackdropBuilder = Widget Function(HomeShader shader)`
  - `HomePage({Key? key, required VoidCallback onTakeTour, BackdropBuilder backdrop = shaderBackdrop})`
  - `Widget shaderBackdrop(HomeShader shader)`
  - Widget keys: `Key('book-familyRoom')`, `Key('book-familySuiteConnected')`, `Key('book-banner')`

- [ ] **Step 1: Write the failing tests**

Add to `test/data/booking_test.dart`, inside `main()`:

```dart
  test('the standard quote starts tomorrow: 2 nights, 2 adults, 2 children', () {
    final q = BookingQuote.standard(
      RoomOption.familyRoom,
      now: DateTime(2026, 12, 31, 23, 30),
    );
    expect(q.option, RoomOption.familyRoom);
    expect(q.checkIn, DateTime(2027, 1, 1));
    expect((q.nights, q.adults, q.children), (2, 2, 2));
  });
```

Create `test/home/shader_backdrop_test.dart`:

```dart
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/home/shader_backdrop.dart';

void main() {
  test('each backdrop names its shader asset', () {
    expect(HomeShader.sea.asset, 'shaders/water.glsl');
    expect(HomeShader.sky.asset, 'shaders/sky.glsl');
  });

  testWidgets('shows the gradient while the shader loads', (tester) async {
    final never = Completer<ui.FragmentProgram>();
    await tester.pumpWidget(
      ShaderBackdrop(shader: HomeShader.sea, loader: (_) => never.future),
    );
    expect(find.byKey(ShaderBackdrop.fallbackKey), findsOneWidget);
  });

  testWidgets('a shader that fails to load leaves the gradient, not an error', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShaderBackdrop(
        shader: HomeShader.sky,
        loader: (_) async => throw Exception('no shader'),
      ),
    );
    await tester.pump();
    expect(find.byKey(ShaderBackdrop.fallbackKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
```

Create `test/home/home_page_test.dart`:

```dart
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
```

- [ ] **Step 2: Run them to see them fail**

Run: `fvm flutter test test/data/booking_test.dart test/home`
Expected: compile errors. `BookingQuote.standard`, `package:flutter_3d/home/…`, `HomeShader`, `HomePage` and `kHotelName` don't exist yet.

- [ ] **Step 3: Copy the two shaders and move them to local coordinates**

```bash
SRC=/Users/pikmin/Documents/flutter-inapp-ios/flutter_module
mkdir -p shaders
cp "$SRC/shaders/water.glsl" "$SRC/shaders/sky.glsl" shaders/
```

Both shaders read `gl_FragCoord`: the whole render target's physical pixels. Our uniforms are the widget's logical size, so switch both to Flutter's widget-local coordinate.
1. Add `#include <flutter/runtime_effect.glsl>` as the new first line of each file.
2. In `shaders/sky.glsl`, change `vec2 uv = gl_FragCoord.xy / iResolution.xy;` to `vec2 uv = FlutterFragCoord().xy / iResolution.xy;`.
3. In `shaders/water.glsl`, change `vec3 color = getPixel(gl_FragCoord.xy, time);` to `vec3 color = getPixel(FlutterFragCoord().xy, time);`.

Check: `grep -n 'gl_FragCoord' shaders/*.glsl` prints nothing.

Register them in `pubspec.yaml`. Under `flutter:`, after the `assets:` list, add:

```yaml
  shaders:
    - shaders/water.glsl
    - shaders/sky.glsl
```

- [ ] **Step 4: Add the standard quote and use it at the entrance**

In `lib/data/booking.dart`, inside `class BookingQuote`, below the constructor:

```dart
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
```

In `lib/features/entrance_feature.dart`, replace

```dart
    final now = DateTime.now();
    final quote = BookingQuote(
      option: _doorOpenAtEntry
          ? RoomOption.familySuiteConnected
          : RoomOption.familyRoom,
      checkIn: DateTime(now.year, now.month, now.day + 1),
      nights: 2,
      adults: 2,
      children: 2,
    );
```

with

```dart
    final quote = BookingQuote.standard(
      _doorOpenAtEntry ? RoomOption.familySuiteConnected : RoomOption.familyRoom,
      now: DateTime.now(),
    );
```

- [ ] **Step 5: Write `lib/home/shader_backdrop.dart`**

```dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// The Home page's two animated backdrops, from flutter_module's shaders.
enum HomeShader {
  /// A ray-marched Shadertoy sea with its own sky and moving horizon.
  sea('shaders/water.glsl', [Color(0xFF7FB8E6), Color(0xFF0B3D63)]),

  /// A blue sky with drifting clouds.
  sky('shaders/sky.glsl', [Color(0xFF80CCFF), Color(0xFFCCE6FF)]);

  const HomeShader(this.asset, this.fallback);

  final String asset;

  /// Top-to-bottom gradient shown until the shader loads, or if it can't.
  final List<Color> fallback;
}

/// The sea's wave height (the shader's `SEA_HEIGHT`). flutter_module used
/// about 0.1 for a calm sea; the original Shadertoy uses 0.6.
const double kSeaHeight = 0.3;

typedef ProgramLoader = Future<ui.FragmentProgram> Function(String asset);

/// Paints [shader] across its box, animated. Its ticker obeys [TickerMode],
/// so it stops while its tab is hidden.
class ShaderBackdrop extends StatefulWidget {
  const ShaderBackdrop({
    super.key,
    required this.shader,
    this.loader = ui.FragmentProgram.fromAsset,
  });

  final HomeShader shader;
  final ProgramLoader loader;

  static const Key fallbackKey = Key('shader-backdrop-fallback');

  @override
  State<ShaderBackdrop> createState() => _ShaderBackdropState();
}

class _ShaderBackdropState extends State<ShaderBackdrop>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _seconds = ValueNotifier(0);
  late final Ticker _ticker = createTicker(
    (elapsed) => _seconds.value = elapsed.inMicroseconds / 1e6,
  );
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final program = await widget.loader(widget.shader.asset);
      if (!mounted) return;
      setState(() => _shader = program.fragmentShader());
      _ticker.start();
    } catch (e) {
      debugPrint('home: ${widget.shader.asset} did not load: $e');
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shader?.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    if (shader == null) {
      return DecoratedBox(
        key: ShaderBackdrop.fallbackKey,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: widget.shader.fallback,
          ),
        ),
      );
    }
    return CustomPaint(
      painter: _ShaderPainter(shader, widget.shader, _seconds),
      size: Size.infinite,
    );
  }
}

class _ShaderPainter extends CustomPainter {
  _ShaderPainter(this.shader, this.kind, this.seconds) : super(repaint: seconds);

  final ui.FragmentShader shader;
  final HomeShader kind;
  final ValueNotifier<double> seconds;

  @override
  void paint(Canvas canvas, Size size) {
    // Uniform order, as the .glsl declares it: iResolution (2 floats),
    // iTime, then SEA_HEIGHT for the sea.
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, seconds.value);
    if (kind == HomeShader.sea) shader.setFloat(3, kSeaHeight);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_ShaderPainter old) => old.shader != shader;
}
```

`material.dart` re-exports `ValueNotifier` and `debugPrint`, but not `ValueListenable`. That's why the painter takes a `ValueNotifier`: no extra import is needed.

- [ ] **Step 6: Write `lib/home/home_page.dart`**

```dart
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
```

- [ ] **Step 7: Run the tests**

Run: `fvm flutter test test/data/booking_test.dart test/home`
Expected: all pass.

- [ ] **Step 8: Prove the shaders compile, then run everything and commit**

Run: `fvm flutter build bundle`
Expected: it succeeds, with no `ShaderCompilerException`. That proves `#include <flutter/runtime_effect.glsl>` and `FlutterFragCoord()` compile. If the include is rejected, add `#version 460 core` as line 1 of each shader, above the include, and build again.

```bash
fvm flutter analyze lib test && fvm flutter test
git add shaders pubspec.yaml lib/data/booking.dart lib/features/entrance_feature.dart \
  lib/home test/data/booking_test.dart test/home
git commit -m "feat(home): hotel home page with sea and sky shader backdrops"
```

### Task 3: App shell, tab pausing and debug launches (after Tasks 1 and 2)

**Files:**
- Create: `lib/app/initial_tab.dart`, `lib/app/app_shell.dart`
- Modify: `lib/main.dart`
- Test: `test/app/app_shell_test.dart`

**Interfaces:**
- Consumes:
  - `HomePage({required VoidCallback onTakeTour, BackdropBuilder backdrop})` and `kHotelName` (Task 2)
  - `IslandSceneScreen` and `kIslandTheme` (Task 1)
  - `HotelPage` (`lib/ui/hotel_page.dart`, existing)
- Produces:
  - `enum AppTab { home, hotel, island }`
  - `AppTab pickInitialTab({required bool hotelDebug, required bool islandDebug})`
  - `const AppTab kInitialTab`
  - `AppShell({Key? key, AppTab initialTab = kInitialTab, HomeBuilder homeBuilder = …, WidgetBuilder hotelBuilder = …, WidgetBuilder islandBuilder = …})`
  - `typedef HomeBuilder = Widget Function(VoidCallback onTakeTour)`

- [ ] **Step 1: Write the failing tests** (`test/app/app_shell_test.dart`)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/app/app_shell.dart';
import 'package:flutter_3d/app/initial_tab.dart';
import 'package:flutter_3d/home/home_page.dart';
import 'package:flutter_3d/ui/booking_page.dart';

/// Stands in for a 3D tab: records each time its state is created, and
/// shows whether its subtree may tick.
class _Scene3d extends StatefulWidget {
  const _Scene3d(this.name, this.created);
  final String name;
  final List<String> created;
  @override
  State<_Scene3d> createState() => _Scene3dState();
}

class _Scene3dState extends State<_Scene3d> {
  @override
  void initState() {
    super.initState();
    widget.created.add(widget.name);
  }

  @override
  Widget build(BuildContext context) =>
      Text('${widget.name} ticking=${TickerMode.valuesOf(context).enabled}');
}

Widget _shell(List<String> created, {AppTab initialTab = AppTab.home}) =>
    MaterialApp(
      home: AppShell(
        initialTab: initialTab,
        homeBuilder: (onTakeTour) => HomePage(
          onTakeTour: onTakeTour,
          backdrop: (_) => const ColoredBox(color: Colors.blue),
        ),
        hotelBuilder: (_) => _Scene3d('hotel', created),
        islandBuilder: (_) => _Scene3d('island', created),
      ),
    );

void main() {
  test('a debug launch opens on its demo, and the hotel wins a tie', () {
    expect(pickInitialTab(hotelDebug: false, islandDebug: false), AppTab.home);
    expect(pickInitialTab(hotelDebug: true, islandDebug: false), AppTab.hotel);
    expect(pickInitialTab(hotelDebug: false, islandDebug: true), AppTab.island);
    expect(pickInitialTab(hotelDebug: true, islandDebug: true), AppTab.hotel);
  });

  testWidgets('opens on Home, with the three tabs and no 3D scene built', (
    tester,
  ) async {
    final created = <String>[];
    await tester.pumpWidget(_shell(created));
    expect(find.text(kHotelName), findsOneWidget);
    for (final label in ['Home', 'Home Demo', 'Island Demo']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(created, isEmpty);
  });

  testWidgets(
    'each 3D tab is built once, ticks only while selected, and keeps its state',
    (tester) async {
      final created = <String>[];
      await tester.pumpWidget(_shell(created));
      Future<void> go(String label) async {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      await go('Home Demo');
      expect(find.text('hotel ticking=true'), findsOneWidget);
      await go('Island Demo');
      expect(find.text('island ticking=true'), findsOneWidget);
      expect(
        find.text('hotel ticking=false', skipOffstage: false),
        findsOneWidget,
      );
      for (var round = 0; round < 3; round++) {
        await go('Home Demo');
        await go('Home');
        await go('Island Demo');
      }
      expect(created, ['hotel', 'island']);

      await go('Home');
      expect(
        find.text('hotel ticking=false', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('island ticking=false', skipOffstage: false),
        findsOneWidget,
      );
    },
  );

  testWidgets('Take the 3D tour opens Home Demo', (tester) async {
    final created = <String>[];
    await tester.pumpWidget(_shell(created));
    await tester.tap(find.text('Take the 3D tour'));
    await tester.pumpAndSettle();
    expect(find.text('hotel ticking=true'), findsOneWidget);
    expect(created, ['hotel']);
  });

  testWidgets('a debug launch builds only its own demo', (tester) async {
    final created = <String>[];
    await tester.pumpWidget(_shell(created, initialTab: AppTab.island));
    expect(find.text('island ticking=true'), findsOneWidget);
    expect(created, ['island']);
  });

  testWidgets('booking from Home and going back leaves Home selected', (
    tester,
  ) async {
    final created = <String>[];
    await tester.pumpWidget(_shell(created));
    final book = find.byKey(const Key('book-familyRoom'));
    await tester.scrollUntilVisible(book, 200);
    await tester.tap(book);
    await tester.pumpAndSettle();
    expect(find.byType(BookingPage), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(BookingPage), findsNothing);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      AppTab.home.index,
    );
    expect(created, isEmpty);
  });
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `fvm flutter test test/app/app_shell_test.dart`
Expected: compile errors. `package:flutter_3d/app/app_shell.dart` and `initial_tab.dart` don't exist.

- [ ] **Step 3: Write `lib/app/initial_tab.dart`**

```dart
/// The app's tabs, in bottom-bar order.
enum AppTab { home, hotel, island }

/// The tab the app opens on. A debug launch meant for one demo opens on it,
/// so the capture scripts and perf probes need no taps. The hotel wins if
/// both kinds of define are set.
AppTab pickInitialTab({required bool hotelDebug, required bool islandDebug}) =>
    hotelDebug
    ? AppTab.hotel
    : (islandDebug ? AppTab.island : AppTab.home);

/// Any hotel debug define: the perf probe, the tour, a preset, the
/// lightning hold, naive props.
const bool _hotelDebug =
    bool.hasEnvironment('HOTEL_PERF') ||
    bool.hasEnvironment('HOTEL_TOUR') ||
    bool.hasEnvironment('HOTEL_PRESET') ||
    bool.hasEnvironment('HOLD_LIGHTNING') ||
    bool.hasEnvironment('NAIVE_PROPS');

/// Any island debug define (see lib/island/scene_app.dart).
const bool _islandDebug =
    bool.hasEnvironment('SCENE_AUTO_DEMO') ||
    bool.hasEnvironment('SCENE_QUALITY') ||
    bool.hasEnvironment('SCENE_TOUR') ||
    bool.hasEnvironment('SCENE_TOUR_MODES') ||
    bool.hasEnvironment('SCENE_RAIN') ||
    bool.hasEnvironment('SCENE_LIGHTNING_HOLD') ||
    bool.hasEnvironment('SCENE_FRAME_STATS') ||
    bool.hasEnvironment('SCENE_ABLATION');

const AppTab kInitialTab = _hotelDebug
    ? AppTab.hotel
    : (_islandDebug ? AppTab.island : AppTab.home);
```

`kInitialTab` repeats `pickInitialTab`'s rule because a `const` can't call a function. The unit test pins the rule, and this constant has to match it.

- [ ] **Step 4: Write `lib/app/app_shell.dart`**

```dart
import 'package:flutter/material.dart';

import '../home/home_page.dart';
import '../island/scene_app.dart';
import '../ui/hotel_page.dart';
import 'initial_tab.dart';

typedef HomeBuilder = Widget Function(VoidCallback onTakeTour);

Widget _realHome(VoidCallback onTakeTour) => HomePage(onTakeTour: onTakeTour);
Widget _realHotel(BuildContext _) => const HotelPage();
Widget _realIsland(BuildContext _) =>
    Theme(data: kIslandTheme, child: const IslandSceneScreen());

/// Home, Home Demo and Island Demo. A 3D tab is built on its first visit and
/// kept. Every tab sits under `TickerMode(enabled: selected)`, so a hidden
/// scene stops rendering and keeps its state. This is the pause both demos
/// already rely on; `SceneView(autoTick:)` is a trap (docs/island/06-island-scene.md).
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.initialTab = kInitialTab,
    this.homeBuilder = _realHome,
    this.hotelBuilder = _realHotel,
    this.islandBuilder = _realIsland,
  });

  final AppTab initialTab;
  final HomeBuilder homeBuilder;
  final WidgetBuilder hotelBuilder, islandBuilder;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late AppTab _tab = widget.initialTab;
  late final Set<AppTab> _visited = {widget.initialTab};

  void _select(AppTab tab) => setState(() {
    _tab = tab;
    _visited.add(tab);
  });

  Widget _slot(AppTab tab, WidgetBuilder build) => TickerMode(
    enabled: tab == _tab,
    child: _visited.contains(tab) ? Builder(builder: build) : const SizedBox.shrink(),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab.index,
        children: [
          _slot(AppTab.home, (_) => widget.homeBuilder(() => _select(AppTab.hotel))),
          _slot(AppTab.hotel, widget.hotelBuilder),
          _slot(AppTab.island, widget.islandBuilder),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (i) => _select(AppTab.values[i]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.hotel_outlined),
            selectedIcon: Icon(Icons.hotel),
            label: 'Home Demo',
          ),
          NavigationDestination(
            icon: Icon(Icons.beach_access_outlined),
            selectedIcon: Icon(Icons.beach_access),
            label: 'Island Demo',
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Point `lib/main.dart` at the shell.** Replace the whole file with:

```dart
import 'package:flutter/material.dart';
import 'app/app_shell.dart';

void main() => runApp(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AppShell(),
    ));
```

- [ ] **Step 6: Run the tests**

Run: `fvm flutter test test/app/app_shell_test.dart`
Expected: all pass.

- [ ] **Step 7: Run everything, then commit**

```bash
fvm flutter analyze lib test && fvm flutter test
git add lib/app lib/main.dart test/app
git commit -m "feat(app): Home, Home Demo and Island Demo tabs; hidden 3D tabs pause"
```

### Task 4: Verify on the iPhone, then record what's new (after Task 3)

**Files:**
- Modify: `lib/home/shader_backdrop.dart` (only `kSeaHeight`, if Step 2 calls for it)
- Modify: `learning.md`

Use the iPhone `00008150-001A30DC2687801C` (Bank's iPhone Duo). If it isn't listed, run `fvm flutter devices --device-timeout 30`; wireless discovery is slow. Before starting, check that nobody else is running the app on it (`ps aux | grep "flutter run"`). Keep the phone unlocked, and don't touch it during timed runs.

- [ ] **Step 1: Every tab works, and coming back works (debug run, by hand)**

Run: `fvm flutter run -d 00008150-001A30DC2687801C --enable-flutter-gpu`

Check, and write down what you see:
- It opens on Home. The hero's sea animates, and the banner's clouds drift.
- **Take the 3D tour** opens Home Demo, and the hotel loads.
- Open Island Demo. The island loads, with its dark-green overlay.
- Switch Home Demo → Island Demo → Home → Island Demo → Home Demo. Each demo is where you left it (camera position, time of day, island quality mode). The island never shows the red "multiple tickers" screen.
- **Book** on a room card opens the booking page, and Back returns to Home.
- The hotel's **Book now** at the entrance still opens the booking page with its preview image.

Stop the run with `q`.

- [ ] **Step 2: Tune the sea, if needed.** If the hero sea looks stormy or flat, change only `kSeaHeight` in `lib/home/shader_backdrop.dart`, hot reload, and pick the calmest value that still shows waves. Commit it on its own:

```bash
git add lib/home/shader_backdrop.dart
git commit -m "tune(home): calmer hero sea"
```

- [ ] **Step 3: A hidden island costs nothing (profile run)**

```bash
fvm flutter run --profile -d 00008150-001A30DC2687801C --enable-flutter-gpu \
  --dart-define=SCENE_FRAME_STATS=true
```

It opens on Island Demo, because a `SCENE_*` define is set. The island logs UI and raster time every 5 s from app-wide `FrameTiming`.
1. Wait for two log lines on the island.
2. Switch to Home and scroll the hero off-screen.
3. Wait for two more log lines.

Expected: on Home, UI and raster fall to about 1–2 ms, far below the island's numbers. If they stay near the island's, the hidden island is still rendering: stop and debug before going on. Paste the lines into your report. Stop the run with `q`.

- [ ] **Step 4: The hotel's perf probe still opens on its demo**

```bash
fvm flutter run --profile -d 00008150-001A30DC2687801C --enable-flutter-gpu \
  --dart-define=HOTEL_PERF=true
```

Expected:
- It opens on Home Demo.
- It prints `hotel perf: preset ultra, view …`, then 12 stop lines, then `hotel perf: done`.
- `room A window, 15:00` is within about 5 ms UI of learning.md's number (≈ 52 ms). The tab bar and hidden tabs add nothing.

Stop with `q` once `done` is printed.

- [ ] **Step 5: Learnings.** Append entries to `learning.md`, in its existing format, for anything non-obvious you hit. At minimum, record whether `FlutterFragCoord()` needed `#version 460 core`, and what the Step 3 numbers were.

- [ ] **Step 6: Run everything, then commit**

```bash
fvm flutter analyze lib test && fvm flutter test
git add learning.md
git commit -m "docs(learning): three-tab app on the iPhone"
```

---

## How to split this across agents

| Wave | Tasks | Starts when |
|---|---|---|
| 0 | Task 0 | now |
| A | Task 1 and Task 2, in parallel (no shared files) | Task 0 is on `main` |
| B | Task 3 | Tasks 1 and 2 are merged |
| C | Task 4 (needs the phone and a person at it) | Task 3 is merged |

Task 1 owns `lib/island/`, `test/island/`, `assets/models/`, the island `.fmat` files, `docs/island/` and `assets/TEXTURE_CREDITS.md`. Task 2 owns `shaders/`, `pubspec.yaml`, `lib/home/`, `test/home/`, `lib/data/booking.dart`, `test/data/booking_test.dart` and `lib/features/entrance_feature.dart`.
