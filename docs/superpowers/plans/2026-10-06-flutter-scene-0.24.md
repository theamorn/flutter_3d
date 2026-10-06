# flutter_scene 0.24.0 Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the app (Home, Home Demo hotel, Island Demo) from flutter_scene 0.23.0 to 0.24.0, make every frame-rate readout honest under 0.24's GPU pacing, retire the workarounds 0.24 fixes, and add the 0.24 features with the best demo payoff.

**Architecture:**
- **Task 1** is one atomic upgrade commit. Nothing compiles cleanly against 0.24 without it.
- **Wave B** follows: three independent tasks (look checks, measurement, materials).
- **Two lanes** then run in parallel: Island (Tasks 5–8, run in order) and Hotel (Tasks 9–10, run in order).
- **Task 11** updates the docs last.

Pure maths goes in pure files with unit tests. Anything that builds a `Scene`, a `Geometry` or a `SceneView` is checked on the iOS simulator.

**Tech Stack:** Flutter 3.47.2 via fvm, flutter_scene 0.24.0 (Flutter GPU, Impeller), vector_math, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-06-flutter-scene-0.24-design.md`. Read it before your task. Its tables say which workarounds stay and why.

## Global Constraints

- **Branch:** all work goes on `flutter-scene-0.24`, created from `main` in Task 1. Lane tasks may use worktrees off that branch.
- **Run tools through fvm:** `fvm flutter test`, `fvm flutter analyze lib test`, `fvm flutter run --enable-flutter-gpu`.
  - While a `fvm flutter run` is up, other `fvm` commands wait on its lock. Use `~/fvm/versions/3.47.2/bin/flutter` directly instead (learning.md).
- **Versions:** flutter_scene is exactly `^0.24.0`. Add no other new dependencies.
- **Analysis and tests:** before every commit, `fvm flutter analyze lib test` must report no issues beyond the ones present right after Task 1, and `fvm flutter test` must pass.
- **The GPU boundary:** unit and widget tests must not construct `Scene`, `SceneView`, `Geometry`, `HotelPage`, `HotelScene` or `IslandSceneScreen`; all of them need the GPU (learning.md). `compileFmat` (an implementation import, see `test/features/reflection_features_test.dart`) is pure Dart and may be used.
- **Shader precision:** every `.fmat` fragment body starts with `precision highp float;` (spec, "silent changes" 1). Any new `.fmat` must too.
- **Material builds:** after any `.fmat` change, rebuild and grep the build output for `keeping the previous shaders`. It must not appear (06 finding 10).
- **Never run `flutter run -t <file>`** (06 "Iterating without a device").
- **No toggles of `SceneView(autoTick:)`.** Pause with `TickerMode` only.
- **Material swaps:** to swap a mounted node's material, assign `node.mesh = node.mesh!.clone()..primitives.single.material = m` (learning Task 24). `primitive.material = m` alone is still ignored in 0.24.
- **Frame-rate readouts:** every new readout reports scene fps from `scene.renderStats.frameCount`, never from `FrameTiming` counts alone.
- **Device runs:** the user does device measurement. Agents never claim a frame-rate result from the simulator or the emulator.
- **Learnings:** add an entry to `learning.md` for any non-obvious finding, in its format, before committing the task that found it.

## Review Focus

1. **A tab coming back after being hidden.**
   - Expected: the scene renders at once, with no "multiple tickers" error, and the releasing callback ran once per hide, not per frame.
   - Test: Task 8, `app_shell_test` "hidden tab releases once".
2. **The fps readout right after a long pause** (tab hidden for 10 s, then shown).
   - Expected: it must not show a near-zero rate for longer than the 2 s window.
   - Test: Task 3, `scene_frame_meter_test` "gap ages out".
3. **A paced frame stream:** Flutter at 120 Hz, the scene at 40.
   - Expected: the HUD says 40 scene fps, not 120.
   - Test: Task 3, `scene_frame_meter_test` "paced frames are not scene frames".
4. **Switching Normal → Super Ultra → Normal with fire shadows on.**
   - Expected: Normal ends with the campfire's `castsShadow` false.
   - Test: Task 5, `campfire_shadows_test`.
5. **More footprints than the pool holds** (a long walk).
   - Expected: the oldest is reused, there are never more than 12 decals, and none spawns while standing still.
   - Test: Task 7, `footprints_test`.

---

## Waves

| Wave | Task | Owns | Depends on |
|---|---|---|---|
| A | 1. Branch, upgrade, compile migration | `pubspec.*`, `.claude/skills/`, mechanical edits in `lib/**`, line 1 of every `.fmat` body, `lib/ui/hotel_page.dart` error text | none |
| B | 2. Look checks after the upgrade | `island_scene.dart` look block, `books_feature.dart` page widgets | 1 |
| B | 3. Honest numbers (scene fps, draws, pacing choice) | `lib/ui/scene_frame_meter.dart`, `hud.dart`, `perf_probe.dart`, `scene_app.dart` readouts, `super_ultra_effects.dart` pacing enum, `render_features.dart` pacing feature | 1 |
| B | 4. Retire material workarounds | `rain_glass.fmat`, `heat_haze.fmat`, `page_curl.fmat`, new `test/materials/` | 1 |
| Island lane | 5 → 6 → 7 → 8 | island files | 3 |
| Hotel lane | 9 → 10 | hotel files | 2, 3 |
| D | 11. Docs | docs only | all |

Tasks 2 and 3 both edit `lib/island/island_scene.dart`, in different blocks (the look settings and the effects menu). Whoever merges second rebases.

---

### Task 1: Branch, upgrade to 0.24.0, compile migration

**Files:**
- Modify: `pubspec.yaml`, `pubspec.lock`
- Modify: `.claude/skills/flutter_scene-*` (regenerated by the package)
- Modify: every `lib/**.dart` that uses `castsShadows` (40 sites, listed by the grep in Step 5), plus `test/features/placeholder_rooms_test.dart:426`
- Modify: `lib/ui/hotel_page.dart` (show a start failure)
- Modify: all 10 `assets/materials/*.fmat` (one line each)
- Create: `test/materials/fmat_precision_test.dart`

**Interfaces:**
- Produces: a tree that builds against flutter_scene 0.24.0. `ShadowCastingMode` is used everywhere `castsShadows` was.

- [x] **Step 1: Branch**

```bash
git checkout main && git pull --ff-only || true
git checkout -b flutter-scene-0.24
```

- [x] **Step 2: Bump the dependency**

In `pubspec.yaml`, change `flutter_scene: ^0.23.0` to `flutter_scene: ^0.24.0`. Then:

```bash
fvm flutter pub upgrade flutter_scene
grep -A3 "^  flutter_scene:" pubspec.lock   # expected: version: "0.24.0"
```

- [x] **Step 3: Re-run the package's setup and skills**

```bash
fvm dart run flutter_scene:init --no-skills
git diff pubspec.yaml hook/build.dart
fvm dart run flutter_scene:skills
```

- **Expected pubspec diff:** 0.24 lists a generated-asset directory per platform. Keep `assets/materials/` and `assets/textures/` in the `assets:` list, and keep the `shaders:` list unchanged.
- If `init` rewrote anything else, restore it.
- `hook/build.dart` should keep `buildScenes` and `buildMaterials`.

- [x] **Step 4: Clear the build-hook cache once**

```bash
rm -rf .dart_tool/hooks_runner
```

0.24 claims outputs now rebuild when flutter_scene changes. Clearing once makes the first build trustworthy anyway. Task 7 checks the claim when it adds a new `.fmat`.

- [x] **Step 5: Write the failing precision test**

Create `test/materials/fmat_precision_test.dart`:

```dart
import 'dart:io';

// The engine's own .fmat compiler (pure Dart, no GPU), imported the way
// test/features/reflection_features_test.dart does.
// ignore: implementation_imports
import 'package:flutter_scene/src/fmat/fmat.dart';
import 'package:flutter_test/flutter_test.dart';

/// flutter_scene 0.24 compiles material fragments at mediump; on Mali, Adreno
/// and the web that is half precision. Our materials compute positions,
/// phases and hashes, so every body opts back into float32
/// (shaders/PRECISION.md in the package).
void main() {
  final files = Directory('assets/materials')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.fmat'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('there are materials to check', () => expect(files, isNotEmpty));

  for (final file in files) {
    test('${file.path} opts its body into highp and still compiles', () {
      final source = file.readAsStringSync();
      // The material's own source, not the compiled GLSL: engine includes may
      // carry their own precision lines and would pass this vacuously.
      final body = source.substring(source.indexOf(RegExp(r'^(fragment|sky) \{', multiLine: true)));
      expect(body, contains('precision highp float;'));
      final compiled = compileFmat(source, fileName: file.path);
      expect(compiled.glsl, contains('precision highp float;'));
    });
  }
}
```

Run: `fvm flutter test test/materials/fmat_precision_test.dart`

Expected: FAIL. Every material's `contains('precision highp float;')` fails.

If instead a material fails with an `FmatException` from 0.24's parser, fix it first: the exception names the key and the line. Record it in `learning.md`.

- [x] **Step 6: Add the precision line to every material**

In each of the 10 files (`ember_bed, grass, heat_haze, island_ground, island_sky, mirror, ocean_simple, ocean, page_curl, rain_glass`), make the first line inside the `fragment {` block:

```glsl
  // flutter_scene 0.24 defaults material fragments to mediump (half precision
  // on Mali/Adreno/web). This body computes positions, phases and hashes.
  precision highp float;
```

`island_sky.fmat` has a `sky {` block instead of `fragment {`. Put the line first inside `sky {`. A global-scope precision statement is what PRECISION.md recommends ("open the body with `precision highp float;` after its includes").

Run: `fvm flutter test test/materials/fmat_precision_test.dart`

Expected: PASS, 11 tests.

- [x] **Step 7: Migrate `castsShadows` (deprecated in 0.24)**

```bash
grep -rn "castsShadows" lib test
```

Apply these rewrites, keeping each site's meaning:

| Old | New |
|---|---|
| `..castsShadows = false` / `.castsShadows = false` | `..shadowCastingMode = ShadowCastingMode.off` / `.shadowCastingMode = ShadowCastingMode.off` |
| `..castsShadows = true` / `.castsShadows = true` | `..shadowCastingMode = ShadowCastingMode.on` |
| `..castsShadows = spec.castsShadows` (`placeholder_rooms.dart:936`) | `..shadowCastingMode = spec.castsShadows ? ShadowCastingMode.on : ShadowCastingMode.off` |
| `expect(n.castsShadows, !glass, ...)` (`placeholder_rooms_test.dart:426`) | `expect(n.shadowCastingMode, glass ? ShadowCastingMode.off : ShadowCastingMode.on, ...)` |

Leave `RoomNode.castsShadows`, our own field in `placeholder_rooms.dart:307`, as it is.

`ShadowCastingMode` is exported by `package:flutter_scene/scene.dart`. Where a file imports `scene.dart` with `show`, add `ShadowCastingMode` to the list.

06 trap 3 still holds: the mode is per node and not inherited, so keep setting it on every node of a loaded model.

- [x] **Step 8: Surface a failed hotel start**

`Scene.initializeStaticResources()` now throws where it used to log (0.24 BREAKING). The island already catches it (`scene_app.dart` `_boot`). The hotel's `FutureBuilder` in `lib/ui/hotel_page.dart` doesn't.

As the first line of its `builder:`, before the `Stack`, insert:

```dart
        builder: (context, snap) => snap.hasError
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('3D scene failed to start:\n${snap.error}',
                      style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                ),
              )
            : Stack(fit: StackFit.expand, children: [
```

Close the conditional after the `Stack`'s closing bracket, so the existing `Stack(...)` becomes the else branch unchanged.

- [x] **Step 9: Analyze and test**

```bash
fvm flutter analyze lib test
fvm flutter test
```

Expected: no `deprecated_member_use` for `castsShadows` and no errors. Note any remaining 0.24 deprecation infos in your commit message; they become the baseline that "no new issues" refers to. All tests pass.

- [x] **Step 10: Build and render on the simulator**

```bash
xcrun simctl list devices booted   # pick the booted iPhone's UDID
fvm flutter run -d <udid> --enable-flutter-gpu --dart-define=SCENE_QUALITY=superUltra 2>&1 | tee /tmp/fs024_build.log
grep -c "keeping the previous shaders" /tmp/fs024_build.log   # expected: 0
```

Expected: the app opens. Switch to Island Demo, and Super Ultra renders sky, water, grass and fire. Switch to Home Demo, and the hotel renders. Quit with `q`.

- [x] **Step 11: Commit**

```bash
git add pubspec.yaml pubspec.lock .claude/skills lib test assets/materials
git commit -m "chore(deps): flutter_scene 0.24.0; highp material bodies; shadowCastingMode"
```

---

### Task 2: Look checks after the upgrade

0.24 changes bloom, the IBL multiscatter term, `WidgetComponent` colour handling and depth, without errors (spec, "silent changes" 3–7). The user compares before and after; this task fixes only the two cases the spec has already decided, and records the rest.

**Files:**
- Modify: `lib/features/books_feature.dart:383-412` (both page `WidgetComponent`s)
- Modify: `lib/island/island_scene.dart` (`_applyEnvironmentSettings`, around lines 880–1000)
- Modify: `learning.md`

**Interfaces:**
- Consumes: Task 1's tree.
- Produces: `docs/superpowers/notes/2026-10-06-coplanar-overlaps.md`, the overlap list Task 10 consumes.

- [x] **Step 1: The Pokédex pages are paper, not screens**

In both `WidgetComponent(` calls in `books_feature.dart`, add the named argument:

```dart
      // Paper, not a screen: take exposure, tone mapping and fog like the
      // book around it. 0.24 made WidgetComponent display-referred by default.
      displayReferred: false,
```

- [x] **Step 2: Check the pages at 15:00 and 22:00 on the simulator** (done on macOS, not simulator; pages did NOT dim at 22:00 with false, see learning.md, needs user judgement)

Use the VM-service `evaluate` technique from learning.md (Task 10 and Task 13 entries).
1. Open the Pokédex book.
2. Screenshot at `timeOfDay` 15.0 and at 22.0.
3. Then remove `displayReferred: false`, hot-restart, and screenshot again.

Expected: with `false`, the pages dim with the room at 22:00. Without it, they stay bright. Keep `false`. If the pages also look dark at 15:00, the old "captured widgets arrive dark" problem (#382) is back; note it in `learning.md`.

- [x] **Step 3: Check the lightning bolt against firefly suppression** (done on macOS; no visible thinning, so the two fireflySuppression lines were NOT added)

```bash
fvm flutter run -d <udid> --enable-flutter-gpu --dart-define=SCENE_QUALITY=superUltra \
  --dart-define=SCENE_RAIN=true --dart-define=SCENE_LIGHTNING_HOLD=2
```

After each `island lightning: strike` log line, screenshot with `xcrun simctl io <udid> screenshot /tmp/bolt_on.png`.

Then add this at the end of `_applySuperUltraLook()`, after its `EnvironmentSettings` assignment:

```dart
    // 0.24 dims isolated extreme pixels before bloom; the 1–2 px bolt is one.
    scene.postProcess.bloom.fireflySuppression = false;
```

Add this after the Normal/Ultra `EnvironmentSettings` assignments in `_applyEnvironmentSettings()`, so leaving Super Ultra restores the default:

```dart
    scene.postProcess.bloom.fireflySuppression = true;
```

Hot-restart and screenshot a strike again (`/tmp/bolt_off.png`).

Keep the change **only if** the bolt's glow is visibly thinner in `bolt_on.png`. Otherwise revert both lines. Record which way it went, and why, in `learning.md`.

- [x] **Step 4: Record the coplanar overlaps**

0.24 debug builds print `findCoplanarOverlaps` once a scene settles.
1. Run the hotel (`--dart-define=HOTEL_TOUR=true` if available, else open Home Demo and walk both rooms).
2. Run the island in each mode.
3. Grep the logs for the overlap lines, then write them to `docs/superpowers/notes/2026-10-06-coplanar-overlaps.md`. Use one row per pair: node A, node B, area, and the hint, verbatim.

If none print, write "none reported" and the commands you ran.

- [x] **Step 5: Analyze, test, commit**

```bash
fvm flutter analyze lib test && fvm flutter test
git add lib/features/books_feature.dart lib/island/island_scene.dart learning.md docs/superpowers/notes
git commit -m "fix(look): book pages scene-referred again; record 0.24 coplanar overlaps"
```

---

### Task 3: Honest numbers: scene fps, real draws, a pacing choice

Under 0.24, `Scene.maxGpuFramesInFlight` (default 1) re-presents the last image when the GPU is behind. Flutter frames keep coming, so `FrameTiming` counts overstate the scene's rate. `scene.renderStats.frameCount` counts frames the scene actually rendered (`render_stats.dart`; a paced frame returns before `beginFrame`).

**Files:**
- Create: `lib/ui/scene_frame_meter.dart`
- Create: `test/ui/scene_frame_meter_test.dart`
- Modify: `lib/ui/hud.dart` (whole `_HudState._onTimings` and the text)
- Modify: `lib/hotel/perf_probe.dart:46-89,130-143` (drop `countView`, use `renderStats`)
- Modify: `lib/island/scene_app.dart` (`_Readout`, `_logFrameStats`, ablation summary, `_EffectsPanelState._updateReadout`)
- Modify: `lib/island/super_ultra/super_ultra_effects.dart` (new `SuperUltraGpuPacing` enum)
- Modify: `lib/island/island_scene.dart` (pacing state in the effects-menu block)
- Modify: `lib/features/render_features.dart`, `lib/hotel/feature_catalog.dart` (new `GpuPacing2Feature`)
- Modify: `test/hotel/presets_test.dart` (manual-feature exceptions)
- Modify: `test/island/super_ultra/super_ultra_effects_test.dart`

**Interfaces:**
- Produces:
  - `class SceneFrameMeter { SceneFrameMeter({int windowMicros = 2000000}); void add(int timestampMicros, {required int sceneFrames, required int pacedFrames}); double get sceneFps; double get pacedPerSecond; void clear(); }` in `package:flutter_3d/ui/scene_frame_meter.dart`.
  - `({int draws, int instances, int offscreenViews})? onScreenDraws(RenderFrameStats? frame)` in `package:flutter_3d/ui/hud.dart`.
  - `enum SuperUltraGpuPacing { one, two }` with `.frames` (int).
  - `IslandScene.gpuPacing` / `setGpuPacing(SuperUltraGpuPacing)`.
  - Hotel feature id `gpu_pacing_2`.

- [x] **Step 1: Write the failing meter tests**

Create `test/ui/scene_frame_meter_test.dart`:

```dart
import 'package:flutter_3d/ui/scene_frame_meter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Feeds [seconds] of samples at [hz] Flutter frames per second, the scene
/// rendering [sceneHz] of them; returns the time after the last sample.
int feed(SceneFrameMeter m, {required int startMicros, required double seconds,
    required double hz, required double sceneHz, required List<int> counters}) {
  final n = (seconds * hz).round();
  var t = startMicros;
  for (var i = 1; i <= n; i++) {
    t = startMicros + (i * 1e6 / hz).round();
    final scene = (counters[0] + i * sceneHz / hz).floor();
    final paced = (counters[1] + i * (hz - sceneHz) / hz).floor();
    m.add(t, sceneFrames: scene, pacedFrames: paced);
  }
  counters[0] += (seconds * sceneHz).round();
  counters[1] += (seconds * (hz - sceneHz)).round();
  return t;
}

void main() {
  test('no samples reads zero', () {
    final m = SceneFrameMeter();
    expect(m.sceneFps, 0);
    expect(m.pacedPerSecond, 0);
  });

  test('every Flutter frame rendered: scene fps is the frame rate', () {
    final m = SceneFrameMeter();
    feed(m, startMicros: 0, seconds: 3, hz: 60, sceneHz: 60, counters: [0, 0]);
    expect(m.sceneFps, closeTo(60, 1));
    expect(m.pacedPerSecond, closeTo(0, 1));
  });

  test('paced frames are not scene frames', () {
    final m = SceneFrameMeter();
    feed(m, startMicros: 0, seconds: 3, hz: 120, sceneHz: 40, counters: [0, 0]);
    expect(m.sceneFps, closeTo(40, 1.5));
    expect(m.pacedPerSecond, closeTo(80, 1.5));
  });

  test('the window slides: only the last 2 s count', () {
    final m = SceneFrameMeter();
    final c = [0, 0];
    final t = feed(m, startMicros: 0, seconds: 5, hz: 60, sceneHz: 60, counters: c);
    feed(m, startMicros: t, seconds: 3, hz: 60, sceneHz: 30, counters: c);
    expect(m.sceneFps, closeTo(30, 1.5));
  });

  test('gap ages out: a 10 s pause stops counting after the window', () {
    final m = SceneFrameMeter();
    final c = [0, 0];
    final t = feed(m, startMicros: 0, seconds: 3, hz: 60, sceneHz: 60, counters: c);
    feed(m, startMicros: t + 10000000, seconds: 2.5, hz: 60, sceneHz: 60, counters: c);
    expect(m.sceneFps, closeTo(60, 2));
  });

  test('clear forgets everything', () {
    final m = SceneFrameMeter();
    feed(m, startMicros: 0, seconds: 1, hz: 60, sceneHz: 60, counters: [0, 0]);
    m.clear();
    expect(m.sceneFps, 0);
  });
}
```

Run: `fvm flutter test test/ui/scene_frame_meter_test.dart`

Expected: FAIL with `Error when reading 'lib/ui/scene_frame_meter.dart'`.

- [x] **Step 2: Implement the meter**

Create `lib/ui/scene_frame_meter.dart`:

```dart
/// Frames a flutter_scene `Scene` actually rendered, kept apart from
/// Flutter's frames.
///
/// Since flutter_scene 0.24.0, a GPU-bound scene re-presents its previous
/// image (`Scene.maxGpuFramesInFlight`) instead of blocking the UI thread, so
/// `FrameTiming` counts can run far ahead of what the scene drew. Feed this
/// the scene's cumulative counters (`scene.renderStats.frameCount`,
/// `scene.pacedFrameCount`) with a wall-clock timestamp, as often as you like.
library;

class SceneFrameMeter {
  SceneFrameMeter({this.windowMicros = 2000000});

  /// How far back the rates look.
  final int windowMicros;

  final List<(int, int, int)> _samples = <(int, int, int)>[];

  /// Records the scene's cumulative counters at [timestampMicros].
  void add(int timestampMicros, {required int sceneFrames, required int pacedFrames}) {
    _samples.add((timestampMicros, sceneFrames, pacedFrames));
    final cutoff = timestampMicros - windowMicros;
    // Keep one sample at or before the cutoff as the base, so the span
    // covers the whole window.
    while (_samples.length > 2 && _samples[1].$1 <= cutoff) {
      _samples.removeAt(0);
    }
    // After a pause longer than the window, the base is stale: drop it.
    if (_samples.length == 2 && _samples.first.$1 < cutoff - windowMicros) {
      _samples.removeAt(0);
    }
  }

  double get _seconds =>
      _samples.length < 2 ? 0 : (_samples.last.$1 - _samples.first.$1) / 1e6;

  /// Frames the scene rendered per second over the window.
  double get sceneFps =>
      _seconds <= 0 ? 0 : (_samples.last.$2 - _samples.first.$2) / _seconds;

  /// Frames the GPU pacing held (re-presented) per second over the window.
  double get pacedPerSecond =>
      _seconds <= 0 ? 0 : (_samples.last.$3 - _samples.first.$3) / _seconds;

  void clear() => _samples.clear();
}
```

Run: `fvm flutter test test/ui/scene_frame_meter_test.dart`

Expected: PASS, 6 tests. If "gap ages out" fails, the stale-base rule is wrong. Fix the meter, not the test.

- [x] **Step 3: HUD: scene fps and real draws**

In `lib/ui/hud.dart`, add the import `import 'scene_frame_meter.dart';`. Add this top-level function after `countScene`:

```dart
/// The on-screen view's draws in the last rendered frame, and how many
/// offscreen views (planar captures, probes) rendered with it.
({int draws, int instances, int offscreenViews})? onScreenDraws(RenderFrameStats? frame) {
  if (frame == null) return null;
  var draws = -1, instances = 0, offscreen = 0;
  for (final v in frame.views) {
    if (v.offscreen) {
      offscreen++;
    } else if (draws < 0) {
      draws = v.counters.draws;
      instances = v.counters.instances;
    }
  }
  if (draws < 0) return null;
  return (draws: draws, instances: instances, offscreenViews: offscreen);
}
```

In `_HudState`, add a field `final SceneFrameMeter _meter = SceneFrameMeter();`. In `_onTimings`, before `setState`, add:

```dart
    _meter.add(DateTime.now().microsecondsSinceEpoch,
        sceneFrames: widget.scene.renderStats.frameCount,
        pacedFrames: widget.scene.pacedFrameCount);
    final d = onScreenDraws(widget.scene.renderStats.latest);
```

Replace the text with:

```dart
    setState(() => _text = '${_meter.sceneFps.round()} fps scene · '
        '${(_window.length / 2).round()} flutter\n'
        'UI  ${avg(ui).toStringAsFixed(1)} / p90 ${p90(ui).toStringAsFixed(1)} ms\n'
        'GPU ${avg(raster).toStringAsFixed(1)} / p90 ${p90(raster).toStringAsFixed(1)} ms\n'
        '${d == null ? '–' : '${d.draws}'} draws · ${(c.triangles / 1000).toStringAsFixed(1)}k tris'
        '${d == null || d.offscreenViews == 0 ? '' : ' · ${d.offscreenViews} captures'}');
```

`RenderFrameStats` is exported from `package:flutter_scene/scene.dart` (`export 'src/render/render_stats.dart'`).

- [x] **Step 4: Check what the stats really hold, once** (done; found frameCount includes paced frames and latest is empty when paced, see learning.md; planar-capture offscreen views not observed)

Temporarily add `debugPrint(widget.scene.renderStats.latest?.toJson().toString());` at the end of `_HudState._onTimings`. Run Home Demo on the simulator, stand at the room A window, and read one printed frame. Confirm three things:
- exactly one view has `offscreen: false`;
- planar captures show up as offscreen views;
- `draws` is of the same order as the old `countView` draws (tens, not thousands).

Remove the temporary print. If the on-screen view isn't the one with `offscreen: false`, adjust `onScreenDraws` and note it in `learning.md`.

- [x] **Step 5: Hotel perf probe**

In `lib/hotel/perf_probe.dart`:
1. Import `../ui/hud.dart` (for `onScreenDraws`) and `../ui/scene_frame_meter.dart`.
2. In `sample`, replace `final counts = countView(ctx.scene.root, ctx.camera, size);` with the following, placed right after `frames.clear();`:

```dart
    final scene = ctx.scene;
    final startMicros = DateTime.now().microsecondsSinceEpoch;
    final startFrames = scene.renderStats.frameCount, startPaced = scene.pacedFrameCount;
```

3. After the 4 s delay, add:

```dart
    final seconds = (DateTime.now().microsecondsSinceEpoch - startMicros) / 1e6;
    final sceneFps = (scene.renderStats.frameCount - startFrames) / seconds;
    final pacedFps = (scene.pacedFrameCount - startPaced) / seconds;
    final d = onScreenDraws(scene.renderStats.latest);
```

4. Change the log line's tail to:

```dart
        'raster ${f(raster.mean)}/${f(raster.p90)} ms | scene ${sceneFps.toStringAsFixed(1)} fps '
        'paced ${pacedFps.toStringAsFixed(1)}/s | draws ${d?.draws ?? -1} inst ${d?.instances ?? -1} '
        'captures ${d?.offscreenViews ?? -1} | frames ${frames.length}');
```

5. Delete `ViewCounts` and `countView` (lines 46–89), then confirm nothing else used them: `grep -rn "countView\|ViewCounts" lib test` should print nothing. Update the doc comment that says "flutter_scene has no frame-stats API".

- [x] **Step 6: Island readouts**

In `lib/island/scene_app.dart`:
1. Import `package:flutter_3d/ui/hud.dart` (show `onScreenDraws`) and `package:flutter_3d/ui/scene_frame_meter.dart`.
2. In `_IslandSceneScreenState`, add `final SceneFrameMeter _sceneMeter = SceneFrameMeter();`.
3. At the end of `_onTick`, add:

```dart
    _sceneMeter.add(DateTime.now().microsecondsSinceEpoch,
        sceneFrames: _island.scene.renderStats.frameCount,
        pacedFrames: _island.scene.pacedFrameCount);
```

4. `_Readout`:
   - replace the `meshes` field and its argument with `draws` (int, -1 when unknown) and `sceneFps` (double);
   - pass `onScreenDraws(_island.scene.renderStats.latest)?.draws ?? -1` and `_sceneMeter.sceneFps`;
   - replace `Text('$meshes meshes'),` with:

```dart
              Text('${draws < 0 ? '–' : draws} draws · ${sceneFps.round()} fps'),
```

   `IslandScene.meshCount` stays; it is still used by tests and the auto demo. Remove it only if `grep -rn meshCount lib test` shows no other user.
5. `_logFrameStats`: append `'| scene ${_sceneMeter.sceneFps.toStringAsFixed(1)} fps paced ${_sceneMeter.pacedPerSecond.toStringAsFixed(1)}/s '` before the mode name.
6. `_runAblation`: where it fills `fps[step]`, record scene fps instead. Read `renderStats.frameCount` before and after the 5 s measure, divided by the measured seconds. Keep the `fps` column name, but print it as `scene fps`.
7. `_EffectsPanelState`: give it its own `SceneFrameMeter`, fed in `_onTimings` from `widget.island.scene`. In `_updateReadout`, append `' · ${_meter.sceneFps.toStringAsFixed(0)} scene fps'` and keep the old value labelled `flutter fps`.

- [x] **Step 7: The pacing choice, island side (failing test first)**

In `test/island/super_ultra/super_ultra_effects_test.dart`, add:

```dart
  test('GPU pacing picks are 1 and 2 frames in flight, 1 by default', () {
    expect(SuperUltraGpuPacing.values.map((p) => p.frames), [1, 2]);
    expect(SuperUltraGpuPacing.initial, SuperUltraGpuPacing.one);
  });
```

Run: `fvm flutter test test/island/super_ultra/super_ultra_effects_test.dart`

Expected: FAIL, `SuperUltraGpuPacing` undefined.

Add this to `lib/island/super_ultra/super_ultra_effects.dart`, after `SuperUltraRenderScale`:

```dart
/// How many frames of GPU work may be queued before the scene re-presents its
/// last image instead of drawing a new one (`Scene.maxGpuFramesInFlight`,
/// flutter_scene 0.24). One pick; the engine's 1 by default.
enum SuperUltraGpuPacing {
  one('1 frame', 'UI thread never waits on the GPU; about a tenth of GPU '
      'throughput held back', 1),
  two('2 frames', 'Full GPU throughput; the UI thread can still wait about '
      'half as long as before 0.24', 2);

  const SuperUltraGpuPacing(this.label, this.cost, this.frames);

  static const SuperUltraGpuPacing initial = SuperUltraGpuPacing.one;

  final String label;
  final String cost;
  final int frames;
}
```

In `island_scene.dart`'s effects-menu block:
- add `SuperUltraGpuPacing _gpuPacing = SuperUltraGpuPacing.initial;`, the getter `gpuPacing`, and a `setGpuPacing` that follows `setRenderScale`'s pattern;
- count it in `effectsMenuChanges`;
- reset it in `resetEffects`;
- in `_applySuperUltraLook()`, next to `scene.renderScale = _renderScale.scale;`, add `scene.maxGpuFramesInFlight = _gpuPacing.frames;`;
- in the Normal/Ultra branch of `_applyEnvironmentSettings()`, add `scene.maxGpuFramesInFlight = 1;`.

In `_EffectsPanelState.build`, after the render-scale picker, add:

```dart
          _EffectsPicker<SuperUltraGpuPacing>(
            title: 'GPU pacing',
            options: SuperUltraGpuPacing.values,
            selected: island.gpuPacing,
            label: (p) => p.label,
            cost: (p) => p.cost,
            onSelected: (p) => _change(() => island.setGpuPacing(p)),
          ),
```

Run the effects test again. Expected: PASS.

- [x] **Step 8: The pacing choice, hotel side**

In `lib/features/render_features.dart`, add:

```dart
/// Lets two frames of GPU work queue before the scene re-presents its last
/// image (flutter_scene 0.24 `Scene.maxGpuFramesInFlight`; the engine's
/// default is 1). A measuring choice: full GPU throughput, at the cost of the
/// UI thread waiting on the GPU again, about half as long as before 0.24.
class GpuPacing2Feature extends HotelFeature {
  @override
  String get id => 'gpu_pacing_2';
  @override
  String get label => 'GPU pacing: 2 frames in flight';
  @override
  CostTier get tier => CostTier.free;
  @override
  bool get defaultOn => false;

  @override
  Future<void> mount(HotelContext ctx) async => ctx.scene.maxGpuFramesInFlight = 2;

  @override
  void unmount(HotelContext ctx) => ctx.scene.maxGpuFramesInFlight = 1;
}
```

Append `GpuPacing2Feature()` after `RenderScale75Feature()` in `buildCatalog()`. In `test/hotel/presets_test.dart`, add `'gpu_pacing_2'` to the ultra exception set in "ultra enables every toggleable feature except…", and add "and the GPU pacing pick" to that test's name.

- [x] **Step 9: Analyze, test, run, commit** (analyze+tests+commit done; on-screen HUD/readout/picker checks NOT observed: simulator screenshots all black, only log lines seen)

```bash
fvm flutter analyze lib test && fvm flutter test
```

On the simulator, check:
- the hotel HUD shows `NN fps scene · NN flutter` and `NN draws`;
- the island readout shows draws and fps;
- the island effects panel shows the GPU pacing picker, and flipping it changes nothing visible.

```bash
git add lib/ui lib/hotel/perf_probe.dart lib/island lib/features/render_features.dart lib/hotel/feature_catalog.dart test
git commit -m "feat(perf): scene fps and real draw counts under 0.24 GPU pacing; pacing pick"
```

---

### Task 4: Retire material workarounds 0.24 fixes

**Files:**
- Modify: `assets/materials/rain_glass.fmat`, `assets/materials/heat_haze.fmat`, `assets/materials/page_curl.fmat`
- Create: `test/materials/retired_workarounds_test.dart`

**Interfaces:**
- Consumes: nothing beyond Task 1.
- Produces: the same parameter names as today. `time` and `wetness` (rain glass), `time` and `haze` (heat haze), and `progress`, `page_width` and `page_tex` (page curl) are unchanged, so no Dart caller changes.

- [x] **Step 1: Write the failing tests**

Create `test/materials/retired_workarounds_test.dart`:

```dart
import 'dart:io';

// ignore: implementation_imports
import 'package:flutter_scene/src/fmat/fmat.dart';
// ignore: implementation_imports
import 'package:flutter_scene/src/fmat/fmat_ast.dart' show FmatShadingModel;
import 'package:flutter_test/flutter_test.dart';

FmatCompilation compile(String path) =>
    compileFmat(File(path).readAsStringSync(), fileName: path);

void main() {
  test('rain glass is unlit with a bounded scene-color reach', () {
    final c = compile('assets/materials/rain_glass.fmat');
    expect(c.material.shadingModel, FmatShadingModel.unlit);
    expect(c.material.engineInputs, ['scene_color']);
    expect(c.material.sceneColorReach, isNotNull);
  });

  test('heat haze is unlit with a bounded scene-color reach', () {
    final c = compile('assets/materials/heat_haze.fmat');
    expect(c.material.shadingModel, FmatShadingModel.unlit);
    expect(c.material.sceneColorReach, isNotNull);
  });

  test('heat haze and page curl place vertices through the model transform', () {
    for (final p in ['assets/materials/heat_haze.fmat', 'assets/materials/page_curl.fmat']) {
      expect(File(p).readAsStringSync(), contains('vertex.model_transform'), reason: p);
      expect(compile(p).glsl, isNotEmpty, reason: p);
    }
  });

  test('page curl no longer rebuilds a basis from the tangent', () {
    expect(File('assets/materials/page_curl.fmat').readAsStringSync(),
        isNot(contains('world_tangent')));
  });
}
```

`compileFmat` returns `FmatCompilation` (`lib/src/fmat/fmat.dart:46` in 0.24). Its `material` is the parsed `FmatMaterial`, with `shadingModel`, `engineInputs` and `sceneColorReach` (`fmat_ast.dart`).

Run: `fvm flutter test test/materials/retired_workarounds_test.dart`

Expected: FAIL. Rain glass and heat haze are `lit`, and neither uses `vertex.model_transform`.

- [x] **Step 2: Rain glass → unlit**

In `rain_glass.fmat`, replace the header comment lines about "engine_inputs need a lit model…", and the `shading_model: lit,` line, with:

```
  // Unlit: since flutter_scene 0.24 an unlit material may read scene_color.
  shading_model: unlit,
```

After `engine_inputs: [scene_color],`, add:

```
  // The drops refract at most 0.03 of the screen; in metres on a 1.2 m pane
  // that is well under 0.1. Bounded reach lets both rooms' panes share one
  // scene-colour capture when they don't overlap on screen.
  scene_color_reach: 0.1,
```

In `Surface`, replace:

```glsl
    material.base_color = vec4(0.0, 0.0, 0.0, have_scene);
    material.emissive = behind * mix(1.0, 0.85, m);
    material.specular = 0.0;
    material.roughness = 0.05;
```

with:

```glsl
    material.base_color = vec4(behind * mix(1.0, 0.85, m), have_scene);
```

Keep the `have_scene` guard. Reflection captures still have no snapshot, and nothing in 0.24 says that changed.

- [x] **Step 3: Heat haze → unlit, placed by the model transform**

In `heat_haze.fmat`:
- Header comment: drop "The node must carry translation only (no rotation or scale)."
- Change `shading_model: lit,` to `shading_model: unlit,`.
- After `engine_inputs: [scene_color],`, add `scene_color_reach: 0.2,`.

Replace the whole `Vertex` function with:

```glsl
  void Vertex(inout VertexInputs vertex) {
    // The node's origin and scale come from its transform (0.24
    // vertex.model_transform), so the haze may sit under a rotated or scaled
    // parent; it still turns to face the camera around world Y.
    vec3 centre = (vertex.model_transform * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
    float scale_x = length(vertex.model_transform[0].xyz);
    float scale_y = length(vertex.model_transform[1].xyz);
    vec3 to_camera = vertex.camera_position - centre;
    to_camera.y = 0.0;
    float length_xz = length(to_camera);
    vec3 facing = length_xz > 0.0001 ? to_camera / length_xz : vec3(0.0, 0.0, 1.0);
    vec3 right = vec3(facing.z, 0.0, -facing.x);
    vertex.world_position = centre + right * vertex.position.x * scale_x +
                            vec3(0.0, vertex.position.y * scale_y, 0.0);
    vertex.world_normal = facing;
  }
```

In `Surface`, replace the last five lines (`base_color` through `emissive`) with:

```glsl
    material.base_color = vec4(GetSceneColor(offset), mask * material_params.haze.y);
```

- [x] **Step 4: Page curl → curl in object space**

In `page_curl.fmat`'s `Vertex`, replace everything from `vec3 delta = p - vertex.position;` to the end of the function with:

```glsl
    // 0.24: place the curled object-space point ourselves.
    vertex.world_position = (vertex.model_transform * vec4(p, 1.0)).xyz;
```

- [x] **Step 5: Run the tests**

Run: `fvm flutter test test/materials/`

Expected: PASS, including Task 1's precision test.

- [ ] **Step 6: Look at all three on the simulator** (NOT DONE: simulator screenshots are all black; builds ran clean, needs a human look)

Rebuild. The `.fmat` sources changed, so the hook recompiles them; grep the output for `keeping the previous shaders`, which must be absent.
- **Rain glass:** in Home Demo, switch rain on and look out of a window from inside both rooms. Drops slide down and refract, and the glass doesn't go black.
- **Heat haze:** run with `SCENE_QUALITY=superUltra` and frame the campfire. The shimmer is still there and faces the camera as it orbits.
- **Page curl:** open the Pokédex and turn a page. It curls the same way as before, and the text reads left to right.

- [x] **Step 7: Commit**

```bash
git add assets/materials test/materials learning.md
git commit -m "refactor(materials): unlit scene-color readers with bounded reach; model_transform in vertex stages"
```

---

## Island lane (Tasks 5 → 8, in order, one agent)

### Task 5: The campfire casts shadows at night

**Files:**
- Modify: `lib/island/super_ultra/super_ultra_effects.dart` (new `SuperUltraEffect.fireShadows`)
- Modify: `lib/island/island_scene.dart` (`_buildCampfireLighting`, `_applyEnvironmentSettings`)
- Create: `lib/island/campfire_shadows.dart`
- Create: `test/island/campfire_shadows_test.dart`

**Interfaces:**
- Produces: `bool campfireCastsShadow({required bool ultraOrAbove, required bool effectOn})`, plus constants `kCampfireLightRadius = 0.25`, `kCampfireShadowResolution = 512` and `kCampfireShadowNear = 0.1`, in `package:flutter_3d/island/campfire_shadows.dart`.

- [x] **Step 1: Failing test**

Create `test/island/campfire_shadows_test.dart`:

```dart
import 'package:flutter_3d/island/campfire_shadows.dart';
import 'package:flutter_3d/island/super_ultra/super_ultra_effects.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Normal never casts; Ultra and above cast unless switched off', () {
    expect(campfireCastsShadow(ultraOrAbove: false, effectOn: true), isFalse);
    expect(campfireCastsShadow(ultraOrAbove: true, effectOn: true), isTrue);
    expect(campfireCastsShadow(ultraOrAbove: true, effectOn: false), isFalse);
  });

  test('fire shadows is a lighting effect in the menu', () {
    expect(SuperUltraEffect.fireShadows.group, SuperUltraEffectGroup.lighting);
  });
}
```

Run: `fvm flutter test test/island/campfire_shadows_test.dart`

Expected: FAIL, the file and the enum value are missing.

- [x] **Step 2: Implement**

Create `lib/island/campfire_shadows.dart`:

```dart
/// The campfire's point-light shadow (flutter_scene 0.24 point shadows: six
/// cube faces in the shared shadow atlas). Only Ultra and Super Ultra pay
/// for it; Super Ultra's effects menu can switch it off to price it.
library;

/// Physical size of the fire, so glints on the props widen to the flames and
/// the shadow edge softens.
const double kCampfireLightRadius = 0.25;

/// Per cube face. The fire lights a 14 m circle; 512 keeps its shadows soft
/// and cheap.
const int kCampfireShadowResolution = 512;

/// The fire sits 0.45 m up in a ring of stones; start the shadow frustum
/// just outside the flame.
const double kCampfireShadowNear = 0.1;

bool campfireCastsShadow({required bool ultraOrAbove, required bool effectOn}) =>
    ultraOrAbove && effectOn;
```

In `super_ultra_effects.dart`, add before `bloom(`:

```dart
  fireShadows(
    'Campfire shadows',
    'Point-light shadows: the casters draw again into six cube faces',
    SuperUltraEffectGroup.lighting,
  ),
```

In `island_scene.dart` `_buildCampfireLighting()`, add these arguments to the `PointLight(...)`:

```dart
      radius: kCampfireLightRadius,
      shadowMapResolution: kCampfireShadowResolution,
      shadowNear: kCampfireShadowNear,
```

At the start of `_applyEnvironmentSettings()`, before the `if (isSuperUltra)`, add:

```dart
    campfireLight.castsShadow = campfireCastsShadow(
      ultraOrAbove: isUltraMode,
      effectOn: isEffectOn(SuperUltraEffect.fireShadows),
    );
```

`_refreshEffects()` only re-applies in Super Ultra. That's correct, because the menu only exists there. The ablation picks the new effect up automatically: it loops over `SuperUltraEffect.values`.

- [x] **Step 3: Test, look, commit** (macOS only, not simulator; palms, 01:30 on/off pair and Ultra mode not observed; fire shadow subtle, draws 200 to 278 with it on)

```bash
fvm flutter test test/island && fvm flutter analyze lib test
fvm flutter run -d <udid> --enable-flutter-gpu --dart-define=SCENE_QUALITY=superUltra --dart-define=SCENE_TOUR=true
```

Screenshot the 21:30 and 01:30 tour stops: the characters and palms throw shadows away from the fire. Then flip "Campfire shadows" off in the effects menu, and the shadows go.

If no shadow appears, check `scene.shadowCasterOverflowCount` through `evaluate`; it must be 0.

```bash
git add lib/island test/island
git commit -m "feat(island): campfire point-light shadows in Ultra and Super Ultra"
```

### Task 6: X-ray: wireframe wipe and surface channels for the presenter

**Files:**
- Create: `lib/island/xray.dart`
- Create: `test/island/xray_test.dart`
- Modify: `lib/island/island_scene.dart` (apply the X-ray state in `tick`)
- Modify: `lib/island/scene_app.dart` (a `🔍` pill next to `_EffectsButton`)

**Interfaces:**
- Produces:
  - `enum XrayMode { off, wireframe, normals, baseColor }` with `XrayMode get next`.
  - `double xraySplit(double seconds)`: the wipe position, 0.15..0.85, period 4 s.
  - `IslandScene.xray` (getter) and `IslandScene.setXray(XrayMode)`.

- [x] **Step 1: Failing test**

Create `test/island/xray_test.dart`:

```dart
import 'package:flutter_3d/island/xray.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('modes cycle off → wireframe → normals → base colour → off', () {
    var m = XrayMode.off;
    final seen = <XrayMode>[];
    for (var i = 0; i < 4; i++) {
      m = m.next;
      seen.add(m);
    }
    expect(seen, [XrayMode.wireframe, XrayMode.normals, XrayMode.baseColor, XrayMode.off]);
  });

  test('the wipe sweeps 0.15..0.85 and back every 4 s', () {
    expect(xraySplit(0), closeTo(0.15, 1e-9));
    expect(xraySplit(2), closeTo(0.85, 1e-9));
    expect(xraySplit(4), closeTo(0.15, 1e-9));
    for (var t = 0.0; t < 8; t += 0.1) {
      expect(xraySplit(t), inInclusiveRange(0.15, 0.85));
    }
  });
}
```

Run: `fvm flutter test test/island/xray_test.dart`

Expected: FAIL, the file is missing.

- [x] **Step 2: Implement the pure part**

Create `lib/island/xray.dart`:

```dart
/// The presenter's X-ray button: flutter_scene 0.24 surface debug views.
/// A wipe runs across the island with the lit image on one side and the
/// chosen channel (or a wireframe over the lit image) on the other, the
/// clearest live proof that this is a real scene graph.
library;

import 'dart:math' as math;

enum XrayMode {
  off('🔍 X-ray'),
  wireframe('🔍 Wireframe'),
  normals('🔍 Normals'),
  baseColor('🔍 Base colour');

  const XrayMode(this.label);

  final String label;

  XrayMode get next => XrayMode.values[(index + 1) % XrayMode.values.length];
}

/// Wipe position for `Scene.debug.split`: eases 0.15 → 0.85 → 0.15 every 4 s.
double xraySplit(double seconds) =>
    0.5 - 0.35 * math.cos(seconds * 2 * math.pi / 4.0);
```

Run the test. Expected: PASS.

- [x] **Step 3: Drive `scene.debug` from the island**

In `island_scene.dart`:
- add `XrayMode _xray = XrayMode.off;`, `double _xrayClock = 0;`, the getter `XrayMode get xray => _xray;`, and:

```dart
  /// Switches the X-ray view. Ultra and Super Ultra only (the button hides in
  /// Normal); leaving those modes switches it off.
  void setXray(XrayMode mode) {
    _xray = mode;
    _xrayClock = 0;
    final d = scene.debug;
    d.overlays.clear();
    d.splitOverlays.clear();
    d.view = switch (mode) {
      XrayMode.normals => const DebugView(channel: SurfaceDebugChannel.worldNormal),
      XrayMode.baseColor => const DebugView(channel: SurfaceDebugChannel.baseColor),
      _ => DebugView.none,
    };
    if (mode == XrayMode.wireframe) d.overlays.add(DebugOverlay.wireframe);
    d.split = mode == XrayMode.off ? null : xraySplit(0);
  }
```

- in `tick(double deltaSeconds, {ui.Size? viewportSize})` (`island_scene.dart` ~2402), add:

```dart
    if (_xray != XrayMode.off) {
      _xrayClock += deltaSeconds;
      scene.debug.split = xraySplit(_xrayClock);
    }
```

- in `setQuality`, when the new quality is `IslandQuality.normal`, call `setXray(XrayMode.off)`.

Check the side convention on the simulator. If the debug channel shows on the *right* of the split while the spec wants a wipe, it doesn't matter which side, as long as the lit image is on one side. Note in `learning.md` which side 0.24 uses.

- [x] **Step 4: The button**

In `scene_app.dart`, after the `if (_island.isSuperUltra) _EffectsButton(...)` entry, add:

```dart
                                  if (_island.isUltraMode)
                                    _XrayButton(
                                      mode: _island.xray,
                                      onTap: () => setState(() =>
                                          _island.setXray(_island.xray.next)),
                                    ),
```

Add a `_XrayButton` widget modelled exactly on `_EffectsButton`: the same `DecoratedBox`, padding and `_PillTab`, with `label: mode.label`, `active: mode != XrayMode.off`, and `activeColor: const Color(0xFF00838F)`.

- [x] **Step 5: Test, look, commit** (macOS only; 4-tap cycle driven with real pointer events; Ultra non-Super and Normal button-hiding not observed; base-colour wipe shows sea black, uninvestigated)

```bash
fvm flutter test test/island && fvm flutter analyze lib test
```

On the simulator, in Super Ultra, tap 🔍 four times. Expected: a wireframe wipe sweeps across the island, then a normals wipe, then a base-colour wipe, then off. Each must leave the scene exactly as it was.

```bash
git add lib/island test/island learning.md
git commit -m "feat(island): X-ray button: wireframe and surface-channel wipe"
```

### Task 7: Decals: a scorch ring and footprints

**Files:**
- Create: `assets/materials/decal_ground.fmat`
- Create: `lib/island/super_ultra/footprints.dart`
- Create: `lib/island/super_ultra/super_ultra_decals.dart`
- Create: `test/island/super_ultra/footprints_test.dart`
- Modify: `lib/island/super_ultra/super_ultra_rig.dart` (build and mount the decals with the rig)
- Modify: `lib/island/island_scene.dart` (feed the player's position each tick in Super Ultra)

**Interfaces:**
- Produces:
  - `class FootprintTrail { FootprintTrail({int capacity = 12, double stride = 0.55, double lifetime = 8.0}); List<Footprint> get prints; void update(double dt, double x, double z, double headingRadians); }`.
  - `class Footprint { double x, z, heading, age; bool left; double get fade; }`.
  - `class SuperUltraDecals { static Future<SuperUltraDecals> build({required double campfireX, required double campfireZ}); final Node root; void tick(double dt, double playerX, double playerZ, double heading); }`.

- [x] **Step 1: Failing test for the trail maths**

Create `test/island/super_ultra/footprints_test.dart`:

```dart
import 'package:flutter_3d/island/super_ultra/footprints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('standing still lays nothing', () {
    final t = FootprintTrail();
    for (var i = 0; i < 100; i++) {
      t.update(1 / 60, 0, 0, 0);
    }
    expect(t.prints, isEmpty);
  });

  test('one print per stride, alternating feet', () {
    final t = FootprintTrail(stride: 0.5);
    for (var i = 1; i <= 60; i++) {
      t.update(1 / 60, i * 0.05, 0, 0); // 3 m in a straight line
    }
    expect(t.prints.length, 6);
    for (var i = 1; i < t.prints.length; i++) {
      expect(t.prints[i].left, isNot(t.prints[i - 1].left));
    }
  });

  test('never more than capacity; the oldest goes first', () {
    final t = FootprintTrail(capacity: 12, stride: 0.5);
    for (var i = 1; i <= 600; i++) {
      t.update(1 / 60, i * 0.05, 0, 0); // 30 m
    }
    expect(t.prints.length, 12);
    expect(t.prints.first.x, lessThan(t.prints.last.x));
  });

  test('prints fade out over their lifetime and are dropped', () {
    final t = FootprintTrail(lifetime: 2);
    t.update(1 / 60, 0.0, 0, 0);
    t.update(1 / 60, 1.0, 0, 0);
    expect(t.prints, isNotEmpty);
    expect(t.prints.first.fade, closeTo(1, 0.05));
    for (var i = 0; i < 180; i++) {
      t.update(1 / 60, 1.0, 0, 0);
    }
    expect(t.prints, isEmpty);
  });
}
```

Run: `fvm flutter test test/island/super_ultra/footprints_test.dart`

Expected: FAIL, the file is missing.

- [x] **Step 2: Implement the trail**

Create `lib/island/super_ultra/footprints.dart`:

```dart
/// Where the player's footprints go: one per stride, alternating feet a hand's
/// width either side of the path, at most [FootprintTrail.capacity] at once
/// (each is a flutter_scene 0.24 DecalNode, so the pool bounds the draws).
library;

import 'dart:math' as math;

class Footprint {
  Footprint(this.x, this.z, this.heading, {required this.left, required this.lifetime});

  final double x, z, heading;
  final bool left;
  final double lifetime;
  double age = 0;

  /// 1 when fresh, easing to 0 at the end of its life.
  double get fade => (1 - age / lifetime).clamp(0.0, 1.0);
}

class FootprintTrail {
  FootprintTrail({this.capacity = 12, this.stride = 0.55, this.lifetime = 8.0});

  final int capacity;
  final double stride;
  final double lifetime;

  /// Half the gap between the two feet, in metres.
  static const double footOffset = 0.09;

  final List<Footprint> _prints = <Footprint>[];
  double? _lastX, _lastZ;
  bool _left = true;

  /// Oldest first.
  List<Footprint> get prints => List.unmodifiable(_prints);

  void update(double dt, double x, double z, double headingRadians) {
    for (final p in _prints) {
      p.age += dt;
    }
    _prints.removeWhere((p) => p.age >= p.lifetime);

    final lx = _lastX, lz = _lastZ;
    if (lx == null || lz == null) {
      _lastX = x;
      _lastZ = z;
      return;
    }
    final dx = x - lx, dz = z - lz;
    if (dx * dx + dz * dz < stride * stride) return;

    // Heading 0 faces +Z; the foot sits to its side.
    final side = _left ? -1.0 : 1.0;
    final px = x + math.cos(headingRadians) * footOffset * side;
    final pz = z - math.sin(headingRadians) * footOffset * side;
    _prints.add(Footprint(px, pz, headingRadians, left: _left, lifetime: lifetime));
    if (_prints.length > capacity) _prints.removeAt(0);
    _left = !_left;
    _lastX = x;
    _lastZ = z;
  }
}
```

Run the test. Expected: PASS. If "one print per stride" gives 5 or 7, the first sample only seeds `_last`. Fix the code, not the expectation.

- [x] **Step 3: The decal material**

Create `assets/materials/decal_ground.fmat`. It follows flutter_scene 0.24's decal contract (`lib/src/decal.dart` docs and the `_decal` fixture in its `test/fmat_runtime_compile_test.dart`). `DecalNode` writes `decal_inverse` and `decal_fade`.

```
// Ground decals for Super Ultra: the campfire's scorch ring (kind 0) and the
// player's footprints (kind 1). Projected by a DecalNode box onto whatever
// opaque surface is inside it (the heightfield, stones), so they follow the
// ground instead of floating on it.
material {
  name: "DecalGround",
  shading_model: unlit,
  blending: alpha,
  culling: front,
  depth_test: always,
  engine_inputs: [scene_depth],
  scene_color_reach: 0.0,
  parameters: [
    { type: mat4, name: decal_inverse },
    { type: float, name: decal_fade, default: 1.0 },
    { type: float, name: kind, default: 0.0 },
    // rgb = linear colour of the mark; a = strength.
    { type: vec4, name: tint, default: [0.03, 0.025, 0.02, 0.85] },
  ],
}

fragment {
  precision highp float;

  float Hash12(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
  }

  void Surface(inout MaterialInputs material) {
    vec3 local = (material_params.decal_inverse *
                  vec4(GetSceneWorldPosition(vec2(0.0)), 1.0)).xyz;
    vec3 outside = step(vec3(0.5), abs(local));
    if (max(outside.x, max(outside.y, outside.z)) > 0.0) {
      discard;
    }
    vec2 uv = local.xz * 2.0; // -1..1 across the box
    float coverage;
    if (material_params.kind < 0.5) {
      // Scorch: dark centre, ragged edge.
      float r = length(uv);
      float ragged = 0.82 + 0.12 * Hash12(floor((uv + 1.0) * 18.0));
      coverage = 1.0 - smoothstep(ragged - 0.25, ragged, r);
    } else {
      // Footprint: a sole (ellipse) and a heel, along local z.
      vec2 sole = (uv - vec2(0.0, 0.25)) / vec2(0.42, 0.55);
      vec2 heel = (uv + vec2(0.0, 0.55)) / vec2(0.32, 0.3);
      float d = min(dot(sole, sole), dot(heel, heel));
      coverage = 1.0 - smoothstep(0.75, 1.0, d);
    }
    coverage *= material_params.tint.a * material_params.decal_fade;
    material.base_color = vec4(material_params.tint.rgb, coverage);
  }
}
```

In `test/materials/retired_workarounds_test.dart`, add:

```dart
  test('decal_ground compiles with the decal contract', () {
    final c = compile('assets/materials/decal_ground.fmat');
    expect(c.material.engineInputs, ['scene_depth']);
    expect(c.sidecar.toString(), contains('decal_inverse'));
  });
```

Run: `fvm flutter test test/materials`. Expected: PASS.

If the parser rejects a key (`depth_test`, `culling: front`), match the fixture in the 0.24 package's `test/fmat_runtime_compile_test.dart` exactly, and note the difference in `learning.md`.

- [x] **Step 4: Wire the decals**

Create `lib/island/super_ultra/super_ultra_decals.dart`:

```dart
import 'package:flutter_scene/scene.dart';

import 'footprints.dart';

/// Super Ultra's ground decals: one scorch ring under the campfire and a
/// pooled trail of footprints behind the player. Each DecalNode needs its own
/// material instance (the projection lives in its parameters).
class SuperUltraDecals {
  SuperUltraDecals._(this.root, this._prints);

  final Node root;
  final List<DecalNode> _prints;
  final FootprintTrail trail = FootprintTrail();

  static const String _material = 'assets/materials/decal_ground.fmat';

  static Future<SuperUltraDecals> build({
    required double campfireX,
    required double campfireZ,
  }) async {
    final root = Node(name: 'super_ultra_decals');
    final scorch = DecalNode(material: await loadFmatMaterial(_material), name: 'scorch')
      ..project(point: Vector3(campfireX, 0, campfireZ), normal: Vector3(0, 1, 0), size: 2.4);
    root.add(scorch);
    final prints = <DecalNode>[];
    for (var i = 0; i < 12; i++) {
      final m = await loadFmatMaterial(_material);
      m.parameters.setFloat('kind', 1.0);
      m.parameters.setVec4('tint', Vector4(0.05, 0.04, 0.03, 0.55));
      final d = DecalNode(material: m, name: 'footprint_$i')..visible = false;
      prints.add(d);
      root.add(d);
    }
    return SuperUltraDecals._(root, prints);
  }

  void tick(double dt, double playerX, double playerZ, double heading) {
    trail.update(dt, playerX, playerZ, heading);
    final shown = trail.prints;
    for (var i = 0; i < _prints.length; i++) {
      final node = _prints[i];
      if (i >= shown.length) {
        node.visible = false;
        continue;
      }
      final p = shown[i];
      node
        ..visible = true
        // `rotation` turns the box about the normal (0.24 DecalNode.project).
        ..project(point: Vector3(p.x, 0, p.z), normal: Vector3(0, 1, 0), size: 0.32,
            rotation: p.heading)
        ..fade = p.fade; // written to the material's decal_fade
    }
  }
}
```

The 0.24 names used here are all in the package source:
- `loadFmatMaterial` returns a `PreprocessedMaterial` (`fmat/material_registry.dart:416`);
- `parameters.setFloat` and `setVec4` (`material/material_parameters.dart`);
- `DecalNode.project({point, normal, size, depth, rotation})` and the `fade` setter (`decal.dart:78`, `:95`).

On the simulator, check that each print's long axis runs along the walk. If the prints sit sideways, pass `rotation: p.heading + math.pi / 2` and note the box's axis convention in `learning.md`.

- In `super_ultra_rig.dart`, build `SuperUltraDecals` with the other Super Ultra content, using `IslandDimensions.campfireX` and `campfireZ`. Expose it as `late final SuperUltraDecals decals;`, and add `decals.root` under the rig's `root`, so it mounts and unmounts with Super Ultra.
- In `island_scene.dart` `tick(double deltaSeconds, ...)`, after `walker.advance(deltaSeconds);`, add:

```dart
    if (isSuperUltra && _superRig.isMounted) {
      _superRig.decals.tick(deltaSeconds, walker.position.x, walker.position.z, walker.yaw);
    }
```

- [x] **Step 5: Check the hook rebuilt the new material, then look**

```bash
fvm flutter run -d <udid> --enable-flutter-gpu --dart-define=SCENE_QUALITY=superUltra --dart-define=SCENE_AUTO_DEMO=true 2>&1 | tee /tmp/decals.log
grep -n "No generated\|keeping the previous shaders" /tmp/decals.log   # expected: nothing
```

If `No generated … decal_ground` appears, 0.24's "rebuild when a source is added" fix didn't hold. Delete `.dart_tool/hooks_runner`, rebuild, and record it in `learning.md` (it settles 06 finding 6 either way).

Expected look:
- a dark ragged ring under the campfire, following the ground and the stones;
- as the auto demo walks the character, prints appear behind it, alternate feet, and fade out.

- [x] **Step 6: Commit**

```bash
fvm flutter analyze lib test && fvm flutter test
git add assets/materials/decal_ground.fmat lib/island test learning.md
git commit -m "feat(island): Super Ultra ground decals: campfire scorch and footprints"
```

### Task 8: Island quality choices and hidden-tab memory

**Files:**
- Modify: `lib/island/super_ultra/super_ultra_effects.dart` (`SuperUltraRenderScale.auto`, new `SuperUltraFrameCap`, new `SuperUltraSceneCopies`)
- Modify: `lib/island/island_scene.dart` (apply them in `_applySuperUltraLook`; reset to defaults in Normal/Ultra)
- Modify: `lib/island/scene_app.dart` (`SceneView(maxFrameRate:)`, three pickers, the readout shows `adaptiveRenderScale` under Auto)
- Modify: `lib/app/app_shell.dart` (`onTabHidden`)
- Modify: `test/island/super_ultra/super_ultra_effects_test.dart`, `test/app/app_shell_test.dart`

**Interfaces:**
- Produces:
  - `SuperUltraRenderScale.auto`, whose `scale` is 1.0 and which adds `bool get adaptive`.
  - `enum SuperUltraFrameCap { uncapped(null), fps60(60) }` with `double? fps`.
  - `enum SuperUltraSceneCopies { separate(null), shared(1) }` with `int? batches`.
  - `AppShell({..., void Function(AppTab hidden) onTabHidden = releaseHiddenTab})`.

- [x] **Step 1: Failing tests**

In `super_ultra_effects_test.dart`, add:

```dart
  test('Auto render scale is adaptive and starts from full resolution', () {
    expect(SuperUltraRenderScale.auto.adaptive, isTrue);
    expect(SuperUltraRenderScale.auto.scale, 1.0);
    expect(SuperUltraRenderScale.values.where((s) => s.adaptive), [SuperUltraRenderScale.auto]);
    expect(SuperUltraRenderScale.initial, SuperUltraRenderScale.percent85);
  });

  test('frame cap and scene copies default to the engine behaviour', () {
    expect(SuperUltraFrameCap.initial.fps, isNull);
    expect(SuperUltraSceneCopies.initial.batches, isNull);
  });
```

In `test/app/app_shell_test.dart`, add a test modelled on its existing tab-switch tests. Pass `onTabHidden: hidden.add` with `final hidden = <AppTab>[];`. Select Island, then Home, then Island, then Home, and pump between. Expect `hidden == [AppTab.island, AppTab.island]` when the shell started on Home. Use the test file's stand-in builders, never the real scenes.

Run both. Expected: FAIL.

- [x] **Step 2: Implement the enums**

In `SuperUltraRenderScale`, add the value

```dart
  auto('Auto', 'Starts at 100% and lowers the scale (to 60%) whenever frames '
      'miss 60 fps', 1.0, adaptive: true);
```

and change the constructor and fields to:

```dart
  const SuperUltraRenderScale(this.label, this.cost, this.scale, {this.adaptive = false});
  final bool adaptive;
```

Add to the same file:

```dart
/// Caps how often the scene renders (`SceneView.maxFrameRate`, 0.24): an even
/// cadence instead of a ragged one when the device can't hold the panel rate.
enum SuperUltraFrameCap {
  uncapped('Uncapped', 'Renders every frame it can', null),
  fps60('60 fps', 'Every other refresh on a 120 Hz panel; steadier, cooler', 60);

  const SuperUltraFrameCap(this.label, this.cost, this.fps);
  static const SuperUltraFrameCap initial = SuperUltraFrameCap.uncapped;
  final String label;
  final String cost;
  final double? fps;
}

/// How many scene-colour copies a frame may take for the sea and the heat
/// haze (`Scene.sceneColorCaptureBatches`, 0.24). Shared is one copy, but the
/// haze then sees the scene from before the sea was drawn.
enum SuperUltraSceneCopies {
  separate('Separate', 'One copy per overlapping reader (engine default)', null),
  shared('Shared', 'One copy for all; the sea may vanish behind the haze', 1);

  const SuperUltraSceneCopies(this.label, this.cost, this.batches);
  static const SuperUltraSceneCopies initial = SuperUltraSceneCopies.separate;
  final String label;
  final String cost;
  final int? batches;
}
```

- [x] **Step 3: Apply them**

In `island_scene.dart`, add `_frameCap` and `_sceneCopies` state, getters and setters in the same pattern as `_renderScale`. Count them in `effectsMenuChanges` and reset them in `resetEffects`. In `_applySuperUltraLook()`, replace `scene.renderScale = _renderScale.scale;` with:

```dart
    scene.renderScale = _renderScale.scale;
    scene.renderQuality
      ..adaptive = _renderScale.adaptive
      ..targetFrameRate = 60
      ..minRenderScale = 0.6
      ..maxRenderScale = 1.0;
    scene.sceneColorCaptureBatches = _sceneCopies.batches;
```

In the Normal/Ultra branch of `_applyEnvironmentSettings()`, add `scene.renderQuality.adaptive = false;` and `scene.sceneColorCaptureBatches = null;`.

In `scene_app.dart`:
- pass `maxFrameRate: _island.isSuperUltra ? _island.frameCap.fps : null,` to the `SceneView`;
- add `_EffectsPicker`s for `SuperUltraFrameCap` and `SuperUltraSceneCopies` after the GPU pacing picker;
- in `_updateReadout`, when `island.renderScale.adaptive`, append `' · ${(island.scene.adaptiveRenderScale * 100).round()}%'`.

- [x] **Step 4: Release a hidden tab's render targets**

In `lib/app/app_shell.dart`, add the import `import 'package:flutter_scene/scene.dart' show releaseTransientRenderTargets;` and this function:

```dart
/// A hidden 3D tab keeps its scene, but its pooled render targets (scene
/// colour, depth, shadow atlas, post chain) are dropped; they reallocate on
/// the next frame that needs them (flutter_scene 0.24).
void releaseHiddenTab(AppTab hidden) {
  if (hidden == AppTab.home) return;
  final bytes = releaseTransientRenderTargets();
  debugPrint('app shell: ${hidden.name} hidden, released ${(bytes / 1048576).toStringAsFixed(1)} MB');
}
```

Add the constructor parameter `this.onTabHidden = releaseHiddenTab,` and the field `final void Function(AppTab hidden) onTabHidden;`. In `_select`, call `widget.onTabHidden(_tab)` before the `setState` when `tab != _tab`.

`releaseTransientRenderTargets` releases the pools for every scene, including the visible one. Those reallocate on the next frame that needs them, so the cost is one reallocation on the newly shown tab. Note that in `learning.md` if the switch visibly hitches.

- [x] **Step 5: Test, look, commit**

```bash
fvm flutter test && fvm flutter analyze lib test
```

On the simulator:
- In Super Ultra, set Auto: the readout shows a percentage. Set the 60 fps cap: the scene fps never goes above 60. Set Shared copies, and look for the sea vanishing in the haze over the fire. Record in `learning.md` whether it does.
- Switch Island → Home: `app shell: island hidden, released … MB` prints once.
- Switch back: the island renders at once, with no red error screen.

```bash
git add lib test learning.md
git commit -m "feat(island): Auto render scale, 60 fps cap, shared scene copies; release hidden tabs' targets"
```

---

## Hotel lane (Tasks 9 → 10, in order, one agent)

### Task 9: Hotel lights and startup

**Files:**
- Modify: `lib/features/lamps_feature.dart` (bath light ~138, bedside lamps ~199)
- Modify: `lib/features/spot_lights_feature.dart` (constants, `SpotLight(...)` ~53, overflow log)
- Create: `lib/features/bath_shadow_feature.dart`
- Modify: `lib/hotel/feature_catalog.dart`, `lib/hotel/presets.dart`
- Modify: `lib/hotel/hotel_scene.dart` (`Scene.preload`), `lib/ui/hotel_page.dart` (`warmUp: true`)
- Modify: `test/features/lamps_feature_test.dart`, `test/features/spot_lights_test.dart`, `test/hotel/presets_test.dart`

**Interfaces:**
- Consumes: Task 3's `gpu_pacing_2` exception in `presets_test`.
- Produces:
  - constants `kBulbRadius = 0.06` (lamps) and `kReadingBulbRadius = 0.03`, `kReadingShadowFov = 1.0` (spots);
  - the feature id `bath_shadow`, in the `ultra` preset.

- [x] **Step 1: Failing tests**

In `test/features/spot_lights_test.dart`, add:

```dart
  test('the reading lights are small bulbs with a shadow frustum on the core', () {
    expect(kReadingBulbRadius, closeTo(0.03, 1e-9));
    // Narrower than the default (2 × outer × 1.05) but wider than the inner cone.
    expect(kReadingShadowFov, lessThan(2 * kReadingLightOuter * 1.05));
    expect(kReadingShadowFov, greaterThan(2 * kReadingLightInner));
  });
```

In `test/features/lamps_feature_test.dart`, add:

```dart
  test('lamp bulbs have a physical size', () => expect(kBulbRadius, closeTo(0.06, 1e-9)));
```

In `test/hotel/presets_test.dart`, add:

```dart
  test('the bath light shadow is an ultra feature', () {
    expect(presetIds(Preset.ultra), contains('bath_shadow'));
    expect(presetIds(Preset.high), isNot(contains('bath_shadow')));
  });
```

Run: `fvm flutter test test/features test/hotel`. Expected: FAIL.

- [x] **Step 2: Light sizes and the spot shadow frustum**

In `lamps_feature.dart`, add `const double kBulbRadius = 0.06;` next to the other constants, and `radius: kBulbRadius,` to both `PointLight(...)`s.

In `spot_lights_feature.dart`, add:

```dart
/// The bulb inside the brass shade (flutter_scene 0.24 light radius: glossy
/// highlights widen to it).
const double kReadingBulbRadius = 0.03;

/// Vertical FOV of each reading light's shadow frustum: the pillows sit in the
/// core of the cone, so spend the 2048² tile there instead of on the soft rim.
const double kReadingShadowFov = 1.0;
```

Add `radius: kReadingBulbRadius,` to the `SpotLight(...)`. Right after the field initialiser, add `..shadowFieldOfView = kReadingShadowFov`; if `SpotLight`'s constructor takes `shadowFieldOfView:` (it does in 0.24, `light.dart:836`), pass it there instead.

In the feature's `tick`, in debug builds only, log the overflow when it changes:

```dart
  int _lastOverflow = 0;
  // in tick():
    assert(() {
      final o = ctx.scene.shadowCasterOverflowCount;
      if (o != _lastOverflow) {
        debugPrint('spot lights: $o shadowed light(s) over the atlas cap');
        _lastOverflow = o;
      }
      return true;
    }());
```

- [x] **Step 3: Bath light point shadow**

Create `lib/features/bath_shadow_feature.dart`:

```dart
import 'package:flutter_scene/scene.dart';

import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import 'lamps_feature.dart';

/// The bathroom ceiling lights cast point-light shadows (flutter_scene 0.24),
/// so the door frame and the basin throw shadows into each bathroom and
/// through its doorway. Ultra only: six cube faces per light per frame, two
/// lights (one per room) against the atlas cap of four point casters.
class BathShadowFeature extends HotelFeature {
  @override
  String get id => 'bath_shadow';
  @override
  String get label => 'Bath light shadows (point)';
  @override
  CostTier get tier => CostTier.mid;
  @override
  bool get defaultOn => false;

  final Set<PointLight> _shadowed = {};

  void _apply() {
    for (final light in LampsFeature.bathLights) {
      if (_shadowed.add(light)) {
        light
          ..castsShadow = true
          ..shadowMapResolution = 512
          ..shadowNear = 0.05;
      }
    }
    // Lamps remounted: forget lights that no longer exist.
    _shadowed.retainAll(LampsFeature.bathLights);
  }

  @override
  Future<void> mount(HotelContext ctx) async => _apply();

  @override
  void tick(HotelContext ctx, double dt) => _apply();

  @override
  void unmount(HotelContext ctx) {
    for (final light in _shadowed) {
      light.castsShadow = false;
    }
    _shadowed.clear();
  }
}
```

`LampsFeature` keeps its bath fixtures in a private `_bathLights` list of `_BathLight`, each with a `final PointLight light` (`lamps_feature.dart:35`, `:138`). Expose them the way `PlayerFeature` exposes its input, as static state:

```dart
  /// The mounted bath lights' PointLights, for features that adjust them
  /// (bath_shadow). Empty while lamps are unmounted.
  static final List<PointLight> bathLights = [];
```

In `mount`, after `_bathLights.add(bath);`, add `bathLights.add(bath.light);`. In `unmount`, next to `_bathLights.clear();`, add `bathLights.clear();`.

Register `BathShadowFeature()` in `buildCatalog()` **after** `LampsFeature()`, and add `'bath_shadow'` to `_ultra` in `presets.dart`.

- [x] **Step 4: Startup: preload and warm-up**

In `hotel_scene.dart` `start()`, replace `await Scene.initializeStaticResources();` with:

```dart
    // 0.24: also loads the physical-material extension shaders (sheen,
    // clearcoat on the fabrics) and the SMAA tables up front, instead of on
    // first use mid-tour.
    await Scene.preload(physicalMaterials: true, smaa: true);
```

In `hotel_page.dart`, add `warmUp: true,` to `SceneView(...)`. 0.24 slices the warm-up so input keeps flowing.

- [ ] **Step 5: Test, look, commit** (tests/analyze and commit done; macOS Ultra startup, zero overflow, and 22:00 bath shadow A/B observed; simulator, clear door-frame floor shadow and pillow shadow checks remain unobserved)

```bash
fvm flutter test && fvm flutter analyze lib test
```

On the simulator:
- Run with `HOTEL_PRESET=ultra` if your launch supports it, or apply Ultra in the Effects sheet.
- Stand in the bathroom doorway at 22:00, and toggle "Bath light shadows". The door frame's shadow appears on the floor.
- Check the reading lights still shadow the pillows, and that no `over the atlas cap` line prints with all lamps on.

```bash
git add lib test learning.md
git commit -m "feat(hotel): physical bulb sizes, bath light point shadows, tighter spot shadows, preload"
```

### Task 10: Hotel z-fighting, GI probe view, Auto render scale

**Files:**
- Modify: `lib/features/placeholder_rooms.dart`, `lib/features/books_feature.dart` (only the pairs Task 2's note lists)
- Create: `lib/features/gi_probes_feature.dart`
- Modify: `lib/features/render_features.dart` (`RenderScaleAutoFeature`)
- Modify: `lib/hotel/feature_catalog.dart`
- Modify: `test/hotel/presets_test.dart`, `test/features/render_scale_test.dart`

**Interfaces:**
- Consumes: `docs/superpowers/notes/2026-10-06-coplanar-overlaps.md` (Task 2) and `ctx.scene.globalIlluminationProbeGrid`.
- Produces: feature ids `gi_probes` and `render_scale_auto`, in no preset.

- [ ] **Step 1: Failing tests**

In `test/features/render_scale_test.dart`, add:

```dart
  test('Auto is in the render-scale group, off by default, and leaves full resolution behind', () {
    final f = RenderScaleAutoFeature();
    expect(f.exclusiveGroup, kRenderScaleGroup);
    expect(f.defaultOn, isFalse);
    expect(f.id, 'render_scale_auto');
  });
```

In `presets_test.dart`, add `'render_scale_auto'` and `'gi_probes'` to the ultra exception set (next to `gpu_pacing_2`), and add `'render_scale_auto'` to `scaleIds`.

Run: `fvm flutter test test/features/render_scale_test.dart test/hotel`. Expected: FAIL.

- [ ] **Step 2: Auto render scale**

In `render_features.dart`, add:

```dart
/// Starts at full resolution and lets flutter_scene 0.24 lower the render scale
/// (down to 60%) whenever frames miss 60 fps, recovering when they keep it.
/// In no preset: its numbers aren't reproducible, which is the point of the
/// fixed scales.
class RenderScaleAutoFeature extends HotelFeature {
  @override
  String get id => 'render_scale_auto';
  @override
  String get label => 'Render scale: Auto (adaptive, 60 fps target)';
  @override
  CostTier get tier => CostTier.free;
  @override
  bool get defaultOn => false;
  @override
  String? get exclusiveGroup => kRenderScaleGroup;

  @override
  Future<void> mount(HotelContext ctx) async {
    ctx.scene.renderScale = 1.0;
    ctx.scene.renderQuality
      ..adaptive = true
      ..targetFrameRate = 60
      ..minRenderScale = 0.6
      ..maxRenderScale = 1.0;
  }

  @override
  void unmount(HotelContext ctx) => ctx.scene.renderQuality.adaptive = false;
}
```

Register it after `RenderScale75Feature()`.

- [ ] **Step 3: GI probe view**

Create `lib/features/gi_probes_feature.dart`:
- a default-off `HotelFeature`: id `gi_probes`, label `Show GI probes`, tier `free`;
- each `tick`, read `ctx.scene.globalIlluminationProbeGrid` (null when dynamic GI is off);
- when the grid's `origin`, `spacing` or `counts` change, rebuild one node holding an `InstancedMesh` of 5 cm unlit cubes, one per probe at `origin + spacing * (i, j, k)`;
- remove it in `unmount`, or when the grid becomes null.

Use the `InstancedMesh` and `InstancedMeshComponent` pattern from `lib/features/instancing_feature.dart`.

Register it after `DynamicGiFeature()`. Check on the simulator: enable dynamic GI plus "Show GI probes", and a lattice of dots appears through both rooms, with planes on the walls and floor as described in learning.md's "Dynamic GI" entry.

- [ ] **Step 4: Replace mm offsets with depth layers**

For each pair in `docs/superpowers/notes/2026-10-06-coplanar-overlaps.md` that is a hotel overlay (TV poster on the screen, book backdrop, rug or panel on the floor or wall), do two things:
- set `material.depthLayer = 1` on the overlay's material (0.24 `Material.depthLayer`; on `PhysicallyBasedMaterial` it's a field, and on a `.fmat` it's `depth_layer:` in the header);
- remove the 1–5 mm offset that separated it.

Leave alone any pair whose surfaces only touch at an edge.

If the note says "none reported", skip this step and say so in the commit message.

Re-run the hotel and confirm two things:
- the overlaps are gone from the debug log;
- every changed surface still shows on top.

- [ ] **Step 5: Test, commit**

```bash
fvm flutter test && fvm flutter analyze lib test
git add lib test learning.md
git commit -m "feat(hotel): Auto render scale, GI probe view, depth layers for coplanar overlays"
```

---

### Task 11: Docs

**Files:**
- Modify: `learning.md`, `docs/island/06-island-scene.md`, `docs/island/FLUTTER-3D-PLAYBOOK.md`, `skills/flutter-3d-in-apps/SKILL.md`, `skills/flutter-3d-in-apps/references/*`, `README.md`

- [ ] **Step 1: `learning.md`.** Make sure there is one entry for each of:
  - mediump material bodies;
  - scene fps vs Flutter fps under pacing;
  - `displayReferred` pages;
  - the lightning and firefly decision;
  - whether the hook rebuilt new sources;
  - the shared scene-copy result;
  - anything a task flagged.

  Use the existing format: Found, Why it matters, Do, Talk?.
- [ ] **Step 2: `06-island-scene.md`.**
  - "Repo facts": flutter_scene 0.24.0.
  - "Draw calls" finding: now real draws, from `Scene.renderStats`.
  - Mark findings 2 (unlit and engine inputs), 6 and the seagull trap 1 (hook cache), and 10 (diagnostics) with what 0.24 changed.
  - Add the new modes' switches (campfire shadows, X-ray, decals, pacing, Auto, frame cap, scene copies) to the Super Ultra table and the debug section.
- [ ] **Step 3: `FLUTTER-3D-PLAYBOOK.md` §4.** Add the rule `precision highp float;` in every `.fmat` body under 0.24, and why it's invisible on Metal and the emulator.
- [ ] **Step 4: `skills/flutter-3d-in-apps`.** Say it's written against 0.24.0. Mark `measured-costs.md` numbers as 0.23 and paced-out (pre-pacing), and rename or extend `traps-0.23.md` with the still-open traps from the spec's "Still broken" table.
- [ ] **Step 5: `README.md`.** Requirements: flutter_scene 0.24.0. Under the profile commands, note that frame rates are now scene fps.
- [ ] **Step 6: Commit**

```bash
git add learning.md docs skills README.md
git commit -m "docs: flutter_scene 0.24.0: findings, what changed, how to read the new numbers"
```

---

## Self-review notes (for the plan's author)

- **Spec coverage:** spec sections map to tasks as follows:
  - Fixed table → Tasks 1, 3, 4, 9
  - Still broken → Global Constraints and Task 11
  - Silent changes 1 → Task 1; 2 → Task 3; 3–5 → Task 2; 6 → Task 1 (bound at build; no change); 7 → Tasks 2 and 10
  - Island design → Tasks 5–8; Hotel design → Tasks 9–10
  - Verification → each task's last steps
- **Review Focus coverage:** Task 8 (1), Task 3 (2, 3), Task 5 (4), Task 7 (5).
- **Names used across tasks:** `onScreenDraws` (Task 3, used in 3), `SceneFrameMeter` (3), `SuperUltraGpuPacing` (3, read in 8's picker ordering), `bath_shadow`, `gpu_pacing_2`, `render_scale_auto`, `gi_probes` (presets tests in 3, 9, 10).
