# Three-tab app: Home, Home Demo, Island Demo

Date: 2026-09-27 · Flutter 3.47.2 (fvm) · flutter_scene 0.23.0

## Intent

**Asked for:** a Flutter app with three tabs:
1. **Home**: a simple page showing information from the hotel demo.
2. **Home Demo**: the current 3D hotel.
3. **Island Demo**: the island from
   `/Users/pikmin/Documents/flutter-inapp-ios/flutter_module`.

The app has to carry the talk's message: "3D in Flutter is cool, but it isn't
an AAA engine; don't do the advanced stuff."

**Decided with the user:**
- Home is an ordinary Flutter page decorated with 2D fragment shaders, not
  3D.
- Home shows hotel content, the way a real hotel app's home screen does. It
  shows no performance numbers and no findings.
- The island code is copied into this repo, not depended on as a package.

**Assumed:**
- The tab labels are exactly "Home", "Home Demo" and "Island Demo".
- The hotel's name is a placeholder, "Seaside Family Hotel", until the user
  gives one.
- The copy is one-time: later changes in `flutter_module` don't flow here.

**Success:**
- The app opens on Home.
- Both 3D demos run.
- Only the visible 3D tab renders. A hidden tab keeps its state and costs no
  frames.
- Returning to a 3D tab works: no "multiple tickers" error, and the scene is
  where it was left.
- The hotel's and the island's debug dart-defines still work.
- `fvm flutter analyze lib test` is clean and `fvm flutter test` passes.

## Why copy rather than depend on the package

`flutter_module` is an add-to-app module. Depending on it by path would:
- pull in flame, liquid_glass_renderer and flutter_shaders;
- prefix its assets with `packages/flutter_module/`, which breaks the
  island's hard-coded `assets/models/…` and `assets/materials/…` paths.

The island's code imports only `flutter`, `flutter_scene` and `vector_math`,
and its asset names don't clash with ours, so a copy needs no new packages and
no path edits.

## App shell (`lib/app/`)

- `main.dart` runs a `MaterialApp` whose home is `AppShell`.
- `AppShell` is a `Scaffold` with a bottom `NavigationBar` (Home, Home Demo,
  Island Demo). Its body is an `IndexedStack` of the three tabs.
- **Lazy 3D tabs.** A 3D tab's widget is built on its first visit, then kept.
  Until then its slot is an empty box, so the app opens without loading either
  scene.
- **Pausing.** Each tab is wrapped in `TickerMode(enabled: selected)`.
  `SceneView`'s ticker, the hotel's `onTick` and the island's own loop all stop
  while hidden. `TickerMode` nests, so the hotel's own
  `TickerMode(enabled: route is current)` and the island's lifecycle
  `TickerMode` still apply inside it. Both projects already rely on this, and
  the island's notes explain why `SceneView(autoTick:)` is a trap.
- **Debug launches.** If any hotel dart-define is set (`HOTEL_PERF`,
  `HOTEL_TOUR`, `HOTEL_PRESET`, `HOLD_LIGHTNING`, `NAIVE_PROPS`), the app
  opens on Home Demo. If any island one is set (`SCENE_AUTO_DEMO`,
  `SCENE_QUALITY`, `SCENE_TOUR`, `SCENE_TOUR_MODES`, `SCENE_RAIN`,
  `SCENE_LIGHTNING_HOLD`, `SCENE_FRAME_STATS`, `SCENE_ABLATION`), it opens on
  Island Demo. Hotel wins if both are set. The choice is a pure function of two
  booleans, so it can be unit-tested. This keeps `tool/ab_capture.sh`, the perf
  probe and the island's tour working unchanged.
- **Wiring.** Home gets a "Take the 3D tour" callback that selects Home Demo.
- **Testability.** `AppShell` takes the three tab builders as parameters, with
  the real pages as defaults, so widget tests can pass stand-ins and never
  construct a `Scene`.

## Island port (`lib/island/`)

- Copy the island's 17 Dart files from `flutter_module/lib/tabs/scene/` to
  `lib/island/`, keeping the `super_ultra/` subfolder. Rewrite
  `package:flutter_module/tabs/scene/` to `package:flutter_3d/island/`.
- In `scene_app.dart`, delete `IslandSceneApp`, the add-to-app `MaterialApp`
  wrapper with its route handling. The tab uses `IslandSceneScreen` directly.
  Its lifecycle observer stays: it also pauses the island when the app is
  backgrounded.
- **Assets.** Copy the 8 `.glb` models and `CREDITS.txt` to `assets/models/`,
  and the 7 `.fmat` materials to `assets/materials/`. The build hook already
  compiles everything under `assets/`. `assets/models/` needs no `pubspec`
  entry, because models load through `flutter_scene_generated/`, as the
  island's own `pubspec` shows.
- **Tests.** Copy `flutter_module/test/tabs/scene/` (4 tests plus
  `super_ultra/`, 7 tests) to `test/island/`, with the same import rewrite.
- **Credits.** Add a line to `assets/TEXTURE_CREDITS.md` pointing at
  `assets/models/CREDITS.txt`.

## Home page (`lib/home/`)

An ordinary scrolling page:

- **Hero:** about a third of the screen tall, an animated sea under a cloud
  sky. `shaders/water.glsl` (a ray-marched Shadertoy sea with its own sky) and
  `shaders/sky.glsl` come from `flutter_module`, loaded with
  `FragmentProgram.fromAsset` and registered under `flutter: shaders:`.
  - Uniforms, as in the module's `app_screen.dart`: sky takes `iResolution`
    and `iTime`; water takes `iResolution`, `iTime` and `SEA_HEIGHT`.
  - Layout: sky across the whole hero, water over its lower half.
  - Over it: the hotel name and a "Take the 3D tour" button.
  - Until a shader loads, or if it fails, the hero shows a blue gradient.
  - The animation stops while the tab is hidden, because its ticker sits under
    the shell's `TickerMode`.
  - The sea is heavy per pixel. Keeping the hero small is part of the talk's
    point, not an accident.
- **Room cards:**
  - "Family Room" at `kFamilyRoomNightlyThb` per night.
  - "Family Suite (2 connected rooms)" at `kFamilySuiteConnectedNightlyThb` per
    night.
  - Prices are formatted with `formatThb` from `lib/data/booking.dart`, so
    they can't drift from the booking page.
  - Each card has a **Book** button that pushes the existing `BookingPage`
    with that room. The quote defaults match the entrance's: check-in
    tomorrow, 2 nights, 2 adults and 2 children, no preview image.
- **Amenities:** only what the 3D hotel models: sea-view balcony, beach below,
  connecting rooms, walk-in shower, TV and sofa, bookshelf.
- **Testability:** `HomePage` takes the hero widget as a parameter (default:
  the shader hero), so widget tests don't load shaders.

## Testing

- **Unit:** the initial-tab choice for each combination of hotel and island
  dart-defines.
- **Widget (stand-in tabs, no GPU):**
  - the app starts on Home;
  - tapping a destination shows that tab;
  - each tab's `TickerMode` is enabled only while it is selected;
  - a 3D tab isn't built before its first visit, and is kept after leaving it;
  - "Take the 3D tour" selects Home Demo;
  - Home shows both room prices via `formatThb` from the constants;
  - Book pushes `BookingPage` with the right room.
- **Island:** the 11 copied tests pass here unchanged, apart from imports.
- **Device (iPhone, profile):**
  - Open each tab. Switch Home Demo → Island Demo → Home Demo, and confirm the
    hidden scene's frames stop (the island's `SCENE_FRAME_STATS` log goes
    quiet while it is hidden).
  - The island comes back without the red "multiple tickers" screen.
  - The Home hero animates.
  - Run the perf probe again (`HOTEL_PERF=true`) to prove it still opens on
    Home Demo.

## Out of scope

- The island's Fullscreen button hides the island's own overlay, not the tab
  bar.
- Any performance numbers or findings on Home.
- The flutter_module's Game, Glass and Promo tabs, and its telemetry channel.
- Keeping the island in sync with `flutter_module` after the copy.
