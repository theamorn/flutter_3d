# Hotel 3D Tour Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Flutter app where you walk in first person through two mirrored, connected family rooms on the 30th floor of a beach hotel. Every 3D effect can be switched on and off from an Effects menu, and a live HUD shows its frame cost.

**Architecture:** A plain Dart `HotelScene` owns one `flutter_scene` `Scene` plus a `FeatureRegistry` of `HotelFeature`s. Each feature mounts its nodes under its own root and fully unmounts when switched off, so the HUD numbers are honest. All maths (floor plan, collision, movement, picking, schedulers, API parsing) lives in GPU-free files with unit tests. One `LookState` is composed into the single `EnvironmentSettings` literal, so no feature can accidentally null the sky.

**Tech Stack:** Flutter 3.47.2 via `fvm flutter` (Dart 3.13.2), `flutter_scene 0.23.0` (Impeller / Flutter GPU), `vector_math`, `webview_flutter`, `http`, PokéAPI (`https://pokeapi.co/api/v2`).

**Spec:** This document's **Design** section below (from the brainstorming conversation, 2026-09-26). Supporting reference: the user's "Flutter 3D playbook (`flutter_scene`)" notes, whose rules are summarised in *Engine rules* below.

## Progress

_Updated 2026-09-26. Step boxes below are ticked for finished tasks._

| Task | Status | Commit |
|---|---|---|
| 1–8 (Waves A–B): setup, core framework, floor plan, movement, picking, PokéAPI, schedulers, presets | Done, merged to `main` | `698fc86` … `8185dc9` |
| 9 Rooms (placeholder geometry, mirrored Room B) | Done | `a434e8e` |
| 10 First-person player | Done | `b7fa2e6` |
| 11 Tap-to-interact | Done | `3b3d03f` |
| 12 Sky, time of day, IBL | Done | `b8ae86a` |
| 13 Ocean and beach | Done | `f06486d` |
| 14 Post-effect toggles | Done | `bc7211e` |
| 15 Shadows and MSAA toggles | Done | `b869aaa` |
| 16–26, 29 (Wave D) | Done, on branch `hotel-tour/wave-d` | `6efd91a` … `97eac30` |
| 27–28 (Wave E) | Not started (28 blocked on the real `.glb`) | — |

Tasks 9–15 (Wave C) are on branch `hotel-tour/wave-c`: done and reviewed, not merged yet. The review's hand-offs to Wave D are written into Tasks 17, 20, 23 and 24 as **Wave C notes**. Where the code departs from this plan (sky exposure and moon, bloom threshold, window layout, and so on), the reason is recorded in `learning.md`, and each decision is logged in the local ledger `.superpowers/sdd/2026-09-26-hotel-3d-tour/progress.md`.

## Global Constraints

- Run Flutter as `fvm flutter …` and Dart as `fvm dart …`. Never use bare `flutter`.
- `flutter_scene: ^0.23.0`, `flutter_gpu: {sdk: flutter}`, `vector_math` explicitly. Import `package:vector_math/vector_math.dart`, **never** `vector_math_64`.
- **No codegen**: no freezed, json_serializable or build_runner. Hand-write models and `fromJson`.
- Launch with `fvm flutter run --enable-flutter-gpu`. Never pass `--enable-experiment=native-assets`.
- iOS: `FLTEnableFlutterGPU` = `true` in `ios/Runner/Info.plist`. Android: `<meta-data android:name="io.flutter.embedding.android.EnableFlutterGPU" android:value="true"/>` in `android/app/src/main/AndroidManifest.xml`.
- World units are metres. +Y is up and +Z points toward the ocean. The room floor is at y = 0 and the sea at y = −90 (30th floor).
- Every toggleable feature must **unmount** its nodes (not just hide them) when off.
- Each task edits only the files listed under its **Files**. The shared files `lib/hotel/feature_catalog.dart`, `lib/hotel/hotel_context.dart` and `lib/hotel/look.dart` are owned by Task 2. A later task may *add* a field to `LookState` only if its Files list says so.
- Performance claims only from a physical device in profile mode. Simulator and emulator results are for correctness only.
- Do not commit API keys. The app uses none (PokéAPI is keyless; the TV and PC are plain WebViews).
- **Record learnings in `learning.md`** (repo root). Whenever you find something worth knowing while coding, append an entry before your task's commit and include `learning.md` in that commit. That covers an engine trap, an API that differs from this plan, a workaround, a performance number measured on a device, or a talk-worthy "expensive vs worth it" finding. Rules:
  - **Append only**: add new entries at the end and never edit or delete others. On a merge conflict in this file, keep both sides.
  - Use the format below. Don't record what the code or git log already says; record what was *surprising* or *non-obvious*.
  - If the finding contradicts this plan, say so in the entry and follow what the code actually does.
  - Before starting a task, read `learning.md`. An earlier agent may already have hit your problem.

  ```markdown
  ## <short title> (Task N, YYYY-MM-DD)
  - **Found:** what happened / what's true (exact error text if short)
  - **Why it matters:** the consequence if you don't know it
  - **Do:** the rule or workaround
  - **Talk?** yes/no — whether it's worth a slide
  ```

## Engine rules (read before any GPU task)

Distilled from the user's playbook and verified against `~/.pub-cache/hosted/pub.dev/flutter_scene-0.23.0`. Also read `.claude/skills/flutter_scene-idioms/references/traps.md`.

1. `scene.environmentSettings = EnvironmentSettings(...)` replaces the **whole** look, and a literal without `skybox:` sets the sky to null. Only `composeLook()` (Task 2) builds that literal. Re-apply lighting afterwards.
2. `.fmat` rules: no `#include <noise.glsl>`; no reversed `smoothstep(hi, lo, x)`; no `pow` on a possibly negative base; clamp `acos`/`asin` input; guard divisions; no reserved names (`sample`, `input`, `output`, `filter`, `patch`, `active`); `depth_write: false` on anything that reads `scene_depth`; blending is only `opaque` or `alpha`. After every `.fmat` edit, grep the build output for `keeping the previous shaders`. If that line appears, the change did not compile.
3. `castsShadows` and `Node.layers` are **not inherited**. Set them on every node.
4. Don't raycast per frame or per particle. `Scene.raycast` is fine for a single tap.
5. Stop rendering with `TickerMode`, not by toggling `SceneView(autoTick:)`.
6. A negative-scale parent transform is supported: the encoder flips winding on a negative determinant (`node.dart:430`, `scene_encoder.dart:879`). Room B is Room A under `scale.x = -1`.
7. `WidgetComponent` renders a live Flutter widget subtree onto a 3D surface, with tap input forwarded at the hit UV (`WidgetInput.automatic`). `ExternalTexture` captures **an empty frame on iOS/macOS** in 0.23.0 (see its doc comment), so a platform-view WebView cannot become a mesh texture. The TV and PC use a screen-aligned overlay instead (Task 24).
8. If a new `.fmat` or `.glb` doesn't appear: `rm -rf .dart_tool/hooks_runner/flutter_3d` and rebuild.

## Review Focus

1. **Walking through the connecting door while it is closing.** The player must never end up inside the door collider or trapped in a wall. Pinned by `colliders_test.dart: "player overlapping a newly-enabled box is pushed out, not stuck"` (Task 3).
2. **The PokéAPI is offline or slow.** A book must still open and show a "Couldn't load — tap to retry" page, and the app must not crash or hang. Pinned by `pokeapi_client_test.dart: "network error returns PokemonLoadFailure"` and `"timeout returns PokemonLoadFailure"` (Task 6).
3. **Rapidly toggling one feature on/off/on while it is still mounting.** There must be no duplicate nodes and no crash, and the last choice wins. Pinned by `feature_registry_test.dart: "later toggle supersedes an in-flight mount"` (Task 2).
4. **Dragging the time slider continuously.** The sky IBL must not rebake every frame; it rebakes at most every 0.4 s while dragging and once on release. Pinned by `rebake_throttle_test.dart` (Task 12).
5. **Tapping a TV while looking at it through the open connecting door from the other room.** The tap must go to the nearest visible screen, and hidden (portal-culled) rooms must not be pickable. Pinned by `picking_test.dart: "nearest hit wins"` (Task 5) and `portal_test.dart: "culled room is not pickable"` (Task 17).
6. **Walking in and out of the entrance zone right at its edge.** The "Book now" button must not flicker on and off every frame. Pinned by `entrance_zone_test.dart: "hysteresis: no flicker at the boundary"` (Task 29).

---

## Design

### Scene layout (world coordinates, metres)

```
            +Z (ocean, 90 m below)
   z=7.8 ┌──────── balcony A ────────┬──────── balcony B ────────┐
   z=6.0 ├═════ window wall A ═══════╪═════ window wall B ═══════┤  ← glass + curtains
         │ bed      sofa     TV      │      TV     sofa      bed │
         │                    [conn. door x=0, z∈[2.0,2.9]]      │
         │ bath(mirror,shower,faucet)│(mirrored bath)            │
   z=0.0 └───────── corridor ────────┴───────────────────────────┘
        x=-8                        x=0                         x=8
         ROOM A (authored)             ROOM B = A mirrored in x
   Ceiling y=2.8. Eye height 1.6.
```

- **Room A** is authored in the local space x ∈ [−8, 0]. **Room B** is the same subtree under a parent with `scale = (−1, 1, 1)`, which lands it in x ∈ [0, 8].
- The shared wall at x = 0 has the connecting door (width 0.9 m, height 2.1 m, hinge at z = 2.0).
- The bathroom is x ∈ [−8, −5.2], z ∈ [0, 2.6]. It has a door opening at x = −5.2, z ∈ [1.2, 2.0].
- The sea, beach and palms sit at y = −90, from z = 20 to z = 700.

### Node-name contract (placeholder builder and the future real `.glb` must match)

| Name | What | Used by |
|---|---|---|
| `floor`, `walls`, `ceiling` | shell | rooms, shadows |
| `door_connect` | connecting door leaf (hinge at its local origin) | Task 17 |
| `lamp_bedside`, `lamp_floor` | lamp bodies; the light is attached at `+0.3 y` | Task 16 |
| `faucet_spout` | basin faucet; water emits from its origin, −Y | Task 19 |
| `shower_head` | emits from its origin, −Y | Task 19 |
| `shower_glass` | glass door | Task 21 (steam) |
| `mirror` | bathroom mirror plane, normal +X in Room A local space | Task 23 |
| `window_glass` | large window plane at z = 6 | Task 21 |
| `curtain_left`, `curtain_right` | curtain panels | Task 18 |
| `tv_screen` | 16:9 quad, 1.2 × 0.675 m | Task 24 |
| `pc_screen` | 16:10 quad, 0.55 × 0.34 m | Task 24 |
| `book_0` … `book_5` | books on the shelf | Task 25 |
| `door_entrance` | room entrance door on the corridor wall (z = 0), x ∈ [−2.3, −1.3]; decorative, always closed | Task 29 |

### Features (catalog)

| id | Label | Tier | Toggle | Task |
|---|---|---|---|---|
| `rooms` | Rooms | free | no (base) | 9 |
| `player` | First-person walk | free | no (base) | 10 |
| `interactions` | Tap to interact | free | no (base) | 11 |
| `sky` | Sky + time of day + IBL | cheap | yes | 12 |
| `ocean` | Ocean + beach view | cheap | yes | 13 |
| `tone_mapping` | ACES tone mapping | free | yes | 14 |
| `fog` | Atmospheric fog | cheap | yes | 14 |
| `bloom` | Bloom + lens flare | expensive | yes | 14 |
| `ao` | GTAO ambient occlusion | expensive | yes | 14 |
| `god_rays` | God rays | expensive | yes | 14 |
| `ssr` | Screen-space reflections | expensive | yes | 14 |
| `shadows` | Sun shadows | mid | yes | 15 |
| `msaa` | MSAA anti-aliasing | mid | yes | 15 |
| `lamps` | Dynamic lamp lights | mid | yes | 16 |
| `portal_culling` | Hide the room you can't see | free | yes | 17 |
| `water_fx` | Faucet + shower particles | mid | yes | 19 |
| `rain` | Rain outside | expensive | yes | 20 |
| `rain_glass` | Rain on the window (refraction) | expensive | yes | 21 |
| `lightning` | Lightning storm | mid | yes | 22 |
| `mirror` | Bathroom mirror (planar reflection) | expensive | yes | 23 |
| `sea_reflection` | Sea planar reflection | expensive | yes | 23 |
| `instancing` | Instanced beach props | cheap | yes | 26 |

Door, curtains, TV/PC, books and the entrance **Book now** flow are interactions, not toggles (`entrance` is a non-toggleable feature, Task 29). Tasks 17, 18, 24 and 25 register them through `InteractionRegistry`.

### UI (Flutter over the `SceneView`)

- Bottom-left: `VirtualJoystick` (move). Right half: drag to look.
- Top-left: HUD with FPS and UI/raster ms (avg / p90 over 2 s) from `SchedulerBinding.addTimingsCallback`, plus mounted-mesh and triangle counts.
- Top-right: an "🎛 Effects" button opens a sheet grouped by tier, with a switch per toggleable feature and preset chips **Low / Medium / High / Ultra**.
- Bottom: a time-of-day slider (0–24 h) and a 🌧 weather toggle.
- Centre: a crosshair. Tapping the screen picks what's under the tap point.

### Out of scope for this plan

- **Native add-to-app host** (a native iOS booking screen embedding this tour, and a native slider driving the time). Separate plan, once this app runs.
- **Real hotel `.glb`.** Task 28 defines the import contract. It is blocked until the user supplies the asset.

---

## File structure

```
lib/
  main.dart                          # app entry, MaterialApp → HotelPage          (T2)
  hotel/
    feature.dart                     # HotelFeature, CostTier                        (T2)
    feature_registry.dart            # mount/unmount + supersede token               (T2)
    feature_catalog.dart             # the list of all features                      (T2)
    hotel_context.dart               # shared state handed to features               (T2)
    look.dart                        # LookState + composeLook()                     (T2)
    hotel_scene.dart                 # owns Scene, camera, tick loop                 (T2)
    presets.dart                     # Low/Medium/High/Ultra → enabled ids           (T8)
  math/                              # GPU-free, unit-tested
    floor_plan.dart                  #                                               (T3)
    colliders.dart                   #                                               (T3)
    fp_movement.dart                 #                                               (T4)
    picking.dart                     #                                               (T5)
    schedulers.dart                  # weather fade, lightning, rebake throttle      (T7)
    portal.dart                      #                                               (T17)
    door_hinge.dart                  #                                               (T17)
  data/
    pokemon.dart                     # model + client                                (T6)
  features/                          # one file per feature (stubs from T2)
    rooms_feature.dart               # + placeholder_rooms.dart                      (T9)
    player_feature.dart                                                              (T10)
    interactions_feature.dart        # + interaction_registry.dart                   (T11)
    sky_feature.dart                                                                 (T12)
    ocean_feature.dart                                                               (T13)
    post_features.dart               # tone_mapping, fog, bloom, ao, god_rays, ssr   (T14)
    render_features.dart             # shadows, msaa                                 (T15)
    lamps_feature.dart                                                               (T16)
    door_feature.dart                # door interaction + portal_culling feature     (T17)
    curtains_feature.dart                                                            (T18)
    water_fx_feature.dart                                                            (T19)
    rain_feature.dart                                                                (T20)
    rain_glass_feature.dart                                                          (T21)
    lightning_feature.dart                                                           (T22)
    reflection_features.dart         # mirror, sea_reflection                        (T23)
    screens_feature.dart             # TV + PC webviews                              (T24)
    books_feature.dart               # + book_page.dart                              (T25)
    instancing_feature.dart                                                          (T26)
    entrance_feature.dart            # proximity → "Book now" button             (T29)
  ui/
    hotel_page.dart                  # SceneView + overlays                          (T2)
    effects_sheet.dart                                                               (T2, presets row T8)
    hud.dart                                                                         (T2)
    look_pad.dart                    # drag-to-look area                             (T10)
    screen_overlay.dart              # WebView aligned to a 3D quad                  (T24)
    booking_page.dart                # booking details + price route               (T29)
assets/materials/
    rain_glass.fmat                                                                  (T21)
    page_curl.fmat                                                                   (T25)
test/  mirrors lib/ for every file under math/, data/, hotel/feature_registry.dart, hotel/look.dart, hotel/presets.dart
tool/
    capture_tour.sh                                                                  (T27)
```

## Execution waves (parallelism)

| Wave | Tasks | Can run in parallel? | Depends on |
|---|---|---|---|
| A | 1 → 2 | **Serial**, one agent | — |
| B | 3, 4, 5, 6, 7, 8 | **Yes**, all pure Dart | A |
| C | 9, 10, 11, 12, 13, 14, 15 | **Yes** | 9 needs 3; 10 needs 3 + 4; 11 needs 5 |
| D | 16–26, 29 | **Yes** | C (they find nodes named by Task 9 and use Task 11's registry) |
| E | 27, 28 | Yes | D |

Each parallel agent should work in its own git worktree (`superpowers:using-git-worktrees`) and touch only its task's files. Because Task 2 created every feature file as a stub, and the catalog already imports them, Wave C and D tasks never edit a shared file.

---

## Wave A

### Task 1: Project setup, dependencies, GPU flags, own git repo

`flutter_3d` currently lives inside the parent `~/Documents` git repo, which is on an unrelated branch with many unrelated changes. Give it its own repo so that agents' commits stay isolated.

**Files:**
- Modify: `pubspec.yaml`
- Modify: `ios/Runner/Info.plist`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `.gitignore`
- Create: `.fvmrc`
- Create: `learning.md`

**Interfaces:** Produces a project that builds with `fvm flutter run --enable-flutter-gpu`.

- [x] **Step 1: Create a nested git repo**

```bash
cd /Users/pikmin/Documents/flutter_3d
git init -b main
printf '{\n  "flutter": "3.47.2"\n}\n' > .fvmrc
```

Also add `flutter_3d/` to the parent repo's ignore rules, locally only, so the parent doesn't track it:

```bash
echo "flutter_3d/" >> /Users/pikmin/Documents/.git/info/exclude
```

- [x] **Step 2: Dependencies.** Replace the `dependencies:` block of `pubspec.yaml` with:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_gpu:
    sdk: flutter
  flutter_scene: ^0.23.0
  vector_math: ^2.1.4
  webview_flutter: ^4.9.0
  http: ^1.2.0
```

Under `flutter:`, make sure these lines exist:

```yaml
flutter:
  uses-material-design: true
  assets:
    - flutter_scene_generated/
    - assets/materials/
```

Create the folder: `mkdir -p assets/materials && touch assets/materials/.gitkeep`

- [x] **Step 3: GPU flags.** Add the following to `ios/Runner/Info.plist`, inside the top-level `<dict>`:

```xml
<key>FLTEnableFlutterGPU</key>
<true/>
```

Add the following to `android/app/src/main/AndroidManifest.xml`, inside `<application>`:

```xml
<meta-data android:name="io.flutter.embedding.android.EnableFlutterGPU" android:value="true"/>
```

Also add `<uses-permission android:name="android.permission.INTERNET"/>` inside `<manifest>`, for PokéAPI and the WebViews.

- [x] **Step 3b: Create `learning.md`** with this header. It's the shared learning log; see Global Constraints.

```markdown
# Learnings — Hotel 3D Tour

Append-only log of non-obvious findings from building this app with flutter_scene 0.23.0.
Read it before starting a task; add to it before committing one. Format:

## <short title> (Task N, YYYY-MM-DD)
- **Found:**
- **Why it matters:**
- **Do:**
- **Talk?** yes/no
```

- [ ] **Step 4: Verify.**

```bash
fvm flutter pub get
fvm dart run flutter_scene:skills --check
fvm flutter analyze
```

Expected: pub get succeeds, the skills are reported up to date, and analyze shows no errors.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: project setup — flutter_scene 0.23, GPU flags, deps"
```

---

### Task 2: Core framework: feature contract, registry, context, look, app shell, Effects sheet, HUD

This task defines every shared interface. Later tasks only fill in stubs.

**Files:**
- Create: `lib/hotel/feature.dart`, `lib/hotel/feature_registry.dart`, `lib/hotel/feature_catalog.dart`, `lib/hotel/hotel_context.dart`, `lib/hotel/look.dart`, `lib/hotel/hotel_scene.dart`
- Create: `lib/features/interaction_registry.dart` (the real implementation lives here, because Task 11 needs a stable API. Task 11 adds tap handling.)
- Create stubs: every `lib/features/*_feature.dart` and `*_features.dart` listed in *File structure*
- Create: `lib/ui/hotel_page.dart`, `lib/ui/effects_sheet.dart`, `lib/ui/hud.dart`
- Modify: `lib/main.dart`
- Test: `test/hotel/feature_registry_test.dart`, `test/hotel/look_test.dart`

**Interfaces (Produces; every later task depends on these exact names):**

```dart
// lib/hotel/feature.dart
enum CostTier { free, cheap, mid, expensive }

abstract class HotelFeature {
  String get id;
  String get label;
  CostTier get tier;
  bool get toggleable => true;
  bool get defaultOn => true;
  /// Build and attach nodes. May be async (asset loads). Must attach
  /// everything under nodes it can later remove in [unmount].
  Future<void> mount(HotelContext ctx);
  /// Remove every node/component/light added in [mount] and restore any
  /// shared state it changed (LookState flags, scene settings).
  void unmount(HotelContext ctx);
  /// Called every frame while mounted. dt in seconds.
  void tick(HotelContext ctx, double dt) {}
}
```

```dart
// lib/hotel/hotel_context.dart   (fields later tasks read or write)
class HotelContext {
  HotelContext(this.scene);
  final Scene scene;
  final PerspectiveCamera camera = PerspectiveCamera(
      position: Vector3(-4, 1.6, 3), target: Vector3(-4, 1.6, 6),
      fovRadiansY: 60 * degrees2Radians, fovNear: 0.05, fovFar: 900);
  final LookState look = LookState();
  final InteractionRegistry interactions = InteractionRegistry();
  final ValueNotifier<double> timeOfDay = ValueNotifier(15.0);  // hours 0..24
  final ValueNotifier<bool> rainRequested = ValueNotifier(false);
  double weather = 0.0;              // smoothed 0 clear..1 storm (Task 20 writes)
  final Map<RoomId, Node> rooms = {}; // filled by rooms feature (Task 9)
  final ValueNotifier<bool> doorOpen = ValueNotifier(false); // Task 17 writes
  Vector2 playerXZ = Vector2(-4, 3);  // Task 10 writes
  double playerYaw = 0.0;             // radians, 0 looks toward +Z
  /// Extra collision boxes features can add (door leaf). Key = owner id.
  final Map<String, List<Box2>> dynamicColliders = {};
  void applyLook() => scene.environmentSettings = composeLook(look);
  /// Every node named [name] in both rooms (A first). Empty if rooms not mounted.
  List<Node> nodesNamed(String name);
}
```

`RoomId`, `Box2` come from `lib/math/floor_plan.dart` and `lib/math/colliders.dart`. Task 2 creates **minimal versions** of those two types (below) so that it compiles. Task 3 then extends the same files.

```dart
// lib/hotel/look.dart
class LookState {
  bool toneMapping = true, fog = false, bloom = false, ao = false,
       godRays = false, ssr = false;
  double exposure = 1.0;
  double environmentIntensity = 1.0;
  double fogDensity = 0.004;
  Skybox? skybox;                    // Task 12 sets
  SkyEnvironment? skyEnvironment;    // Task 12 sets
  DirectionalLight? sunLight;        // Task 12 sets
}
EnvironmentSettings composeLook(LookState s);
```

```dart
// lib/features/interaction_registry.dart
class Interactable {
  Interactable({required this.node, required this.label, required this.onTap});
  final Node node;          // raycast target; Task 11 marks it raycastable
  final String label;       // shown in the crosshair tooltip, e.g. "Turn on lamp"
  final void Function() onTap;
}
class InteractionRegistry extends ChangeNotifier {
  void register(Interactable i);
  void unregister(Interactable i);
  Interactable? forNode(Node n); // walks up parents to find a registered node
  Iterable<Interactable> get all;
}
```

- [x] **Step 1: Write the failing registry test** (`test/hotel/feature_registry_test.dart`)

```dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/hotel/feature.dart';
import 'package:flutter_3d/hotel/feature_registry.dart';

class _Fake extends HotelFeature {
  _Fake(this.id, {this.delay = Duration.zero});
  @override final String id;
  final Duration delay;
  int mounts = 0, unmounts = 0;
  @override String get label => id;
  @override CostTier get tier => CostTier.cheap;
  // Parameter widened to Object? (a legal override) so tests can pass null.
  @override Future<void> mount(Object? ctx) async { await Future.delayed(delay); mounts++; }
  @override void unmount(Object? ctx) { unmounts++; }
}

void main() {
  test('setEnabled mounts then unmounts', () async {
    final f = _Fake('a');
    final r = FeatureRegistry([f], mountContext: null);
    await r.setEnabled('a', true);
    expect(r.isEnabled('a'), true);
    expect(f.mounts, 1);
    await r.setEnabled('a', false);
    expect(r.isEnabled('a'), false);
    expect(f.unmounts, 1);
  });

  test('later toggle supersedes an in-flight mount', () async {
    final f = _Fake('a', delay: const Duration(milliseconds: 50));
    final r = FeatureRegistry([f], mountContext: null);
    final first = r.setEnabled('a', true);
    final second = r.setEnabled('a', false); // user flips it back before mount finishes
    await first;
    await second;
    expect(r.isEnabled('a'), false);
    // the late mount must be undone: mounted count == unmounted count
    expect(f.mounts, f.unmounts);
  });

  test('on/off/on quickly leaves exactly one mount', () async {
    final f = _Fake('a', delay: const Duration(milliseconds: 20));
    final r = FeatureRegistry([f], mountContext: null);
    unawaited(r.setEnabled('a', true));
    unawaited(r.setEnabled('a', false));
    await r.setEnabled('a', true);
    await Future.delayed(const Duration(milliseconds: 80));
    expect(r.isEnabled('a'), true);
    expect(f.mounts - f.unmounts, 1);
  });

  test('non-toggleable feature cannot be disabled', () async {
    final f = _Base();
    final r = FeatureRegistry([f], mountContext: null);
    await r.setEnabled('base', true);
    await r.setEnabled('base', false);
    expect(r.isEnabled('base'), true);
  });
}

class _Base extends _Fake {
  _Base() : super('base');
  @override bool get toggleable => false;
}
```

- [x] **Step 2: Run it and check it fails**

Run: `fvm flutter test test/hotel/feature_registry_test.dart`
Expected: FAIL (compile error: `feature_registry.dart` not found).

- [x] **Step 3: Implement `feature.dart` and `feature_registry.dart`**

```dart
// lib/hotel/feature.dart
import 'hotel_context.dart';

enum CostTier { free, cheap, mid, expensive }

abstract class HotelFeature {
  String get id;
  String get label;
  CostTier get tier;
  bool get toggleable => true;
  bool get defaultOn => true;
  Future<void> mount(HotelContext ctx);
  void unmount(HotelContext ctx);
  void tick(HotelContext ctx, double dt) {}
}
```

```dart
// lib/hotel/feature_registry.dart
import 'package:flutter/foundation.dart';
import 'feature.dart';
import 'hotel_context.dart';

/// Owns which features are mounted. Requests for one feature are serialised
/// through a per-feature chain; each step reconciles "mounted" with the
/// latest "wanted", so a quick on/off/on ends in exactly the last state.
class FeatureRegistry extends ChangeNotifier {
  FeatureRegistry(this.features, {required this.mountContext});

  final List<HotelFeature> features;
  /// Null only in tests.
  final HotelContext? mountContext;

  final Set<String> _mounted = {};
  final Set<String> _wanted = {};
  final Map<String, Future<void>> _chain = {};

  HotelFeature byId(String id) => features.firstWhere((f) => f.id == id);
  bool isEnabled(String id) => _wanted.contains(id);
  bool isMounted(String id) => _mounted.contains(id);

  Future<void> setEnabled(String id, bool on) {
    final f = byId(id);
    if (!on && !f.toggleable) return Future.value();
    on ? _wanted.add(id) : _wanted.remove(id);
    notifyListeners();
    final next = (_chain[id] ?? Future.value()).then((_) => _reconcile(f));
    _chain[id] = next;
    return next;
  }

  Future<void> _reconcile(HotelFeature f) async {
    // mountContext is null only in tests, whose fakes accept Object?.
    final ctx = mountContext as dynamic;
    final want = _wanted.contains(f.id);
    final have = _mounted.contains(f.id);
    if (want && !have) {
      await f.mount(ctx);
      _mounted.add(f.id);
    } else if (!want && have) {
      f.unmount(ctx);
      _mounted.remove(f.id);
    }
    notifyListeners();
  }

  Future<void> mountDefaults() async {
    for (final f in features) {
      if (f.defaultOn || !f.toggleable) await setEnabled(f.id, true);
    }
  }

  void tick(double dt) {
    final ctx = mountContext;
    if (ctx == null) return;
    for (final f in features) {
      if (_mounted.contains(f.id)) f.tick(ctx, dt);
    }
  }
}
```

`HotelFeature.mount` takes a non-null `HotelContext`. The test fakes widen that parameter to `Object?`, which is a legal override, so the `null` passed through `dynamic` is accepted. Real features never see `null`, because `HotelScene` always passes a context.

- [x] **Step 4: Run the tests and check they pass**

Run: `fvm flutter test test/hotel/feature_registry_test.dart`
Expected: 4 tests PASS.

- [x] **Step 5: Write the failing look test** (`test/hotel/look_test.dart`)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_3d/hotel/look.dart';

void main() {
  test('flags map onto EnvironmentSettings', () {
    final s = LookState()
      ..bloom = true
      ..ao = true
      ..fog = true
      ..toneMapping = false;
    final e = composeLook(s);
    expect(e.bloomEnabled, true);
    expect(e.lensFlareEnabled, true);
    expect(e.ambientOcclusionEnabled, true);
    expect(e.ambientOcclusionMethod, AmbientOcclusionMethod.gtao);
    expect(e.fogEnabled, true);
    expect(e.toneMapping, ToneMappingMode.none);
  });

  test('sky fields are always passed through (engine rule 1)', () {
    final s = LookState();
    final e = composeLook(s);
    expect(e.skybox, same(s.skybox));
    expect(e.skyEnvironment, same(s.skyEnvironment));
  });
}
```

Before writing it, check the enum member names:
`grep -n "enum AmbientOcclusionMethod\|enum ToneMappingMode" -A8 ~/.pub-cache/hosted/pub.dev/flutter_scene-0.23.0/lib/src/*.dart`
If GTAO or "none" is spelled differently, use the real names in both the test and the implementation.

- [x] **Step 6: Implement `look.dart`**

```dart
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

class LookState {
  bool toneMapping = true, fog = false, bloom = false, ao = false,
      godRays = false, ssr = false;
  double exposure = 1.0;
  double environmentIntensity = 1.0;
  double fogDensity = 0.004;
  Skybox? skybox;
  SkyEnvironment? skyEnvironment;
  DirectionalLight? sunLight;
}

/// The ONLY place an EnvironmentSettings literal is built (engine rule 1).
EnvironmentSettings composeLook(LookState s) => EnvironmentSettings(
      skybox: s.skybox,
      skyEnvironment: s.skyEnvironment,
      sunLight: s.sunLight,
      toneMapping: s.toneMapping ? ToneMappingMode.aces : ToneMappingMode.none,
      exposure: s.exposure,
      environmentIntensity: s.environmentIntensity,
      bloomEnabled: s.bloom,
      bloomThreshold: 1.0,
      lensFlareEnabled: s.bloom,
      lensFlareHaloIntensity: 0.3,
      ambientOcclusionEnabled: s.ao,
      ambientOcclusionMethod: AmbientOcclusionMethod.gtao,
      ambientOcclusionBentNormals: true,
      ambientOcclusionHalfResolution: true,
      fogEnabled: s.fog,
      fogDensity: s.fogDensity,
      fogSkyColorInfluence: 1.0,
      fogColor: Vector3(0.7, 0.78, 0.86),
      godRaysEnabled: s.godRays,
      godRaysStepCount: 24,
      godRaysDensity: 0.18,
      screenSpaceReflectionsEnabled: s.ssr,
    );
```

Run: `fvm flutter test test/hotel/look_test.dart`. Expected: PASS.

- [x] **Step 7: Minimal shared math types**, so that Task 2 compiles. Task 3 extends these same files.

```dart
// lib/math/floor_plan.dart
enum RoomId { a, b }
```

```dart
// lib/math/colliders.dart
import 'package:vector_math/vector_math.dart';

/// Axis-aligned box on the XZ plane.
class Box2 {
  const Box2(this.minX, this.minZ, this.maxX, this.maxZ);
  final double minX, minZ, maxX, maxZ;
}
```

- [x] **Step 8: Context, interaction registry, scene, catalog, stubs**

```dart
// lib/features/interaction_registry.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart';

class Interactable {
  Interactable({required this.node, required this.label, required this.onTap});
  final Node node;
  final String label;
  final void Function() onTap;
}

class InteractionRegistry extends ChangeNotifier {
  final List<Interactable> _items = [];
  Iterable<Interactable> get all => _items;
  void register(Interactable i) { _items.add(i); notifyListeners(); }
  void unregister(Interactable i) { _items.remove(i); notifyListeners(); }
  Interactable? forNode(Node n) {
    Node? cur = n;
    while (cur != null) {
      for (final i in _items) { if (identical(i.node, cur)) return i; }
      cur = cur.parent;
    }
    return null;
  }
}
```

```dart
// lib/hotel/hotel_context.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';
import '../features/interaction_registry.dart';
import '../math/colliders.dart';
import '../math/floor_plan.dart';
import 'look.dart';

class HotelContext {
  HotelContext(this.scene);
  final Scene scene;
  final PerspectiveCamera camera = PerspectiveCamera(
    position: Vector3(-4, 1.6, 3),
    target: Vector3(-4, 1.6, 6),
    fovRadiansY: 60 * degrees2Radians,
    fovNear: 0.05,
    fovFar: 900,
  );
  final LookState look = LookState();
  final InteractionRegistry interactions = InteractionRegistry();
  final ValueNotifier<double> timeOfDay = ValueNotifier(15.0);
  final ValueNotifier<bool> rainRequested = ValueNotifier(false);
  double weather = 0.0;
  final Map<RoomId, Node> rooms = {};
  final ValueNotifier<bool> doorOpen = ValueNotifier(false);
  Vector2 playerXZ = Vector2(-4, 3);
  double playerYaw = 0.0;
  final Map<String, List<Box2>> dynamicColliders = {};

  void applyLook() => scene.environmentSettings = composeLook(look);

  List<Node> nodesNamed(String name) {
    final out = <Node>[];
    for (final id in RoomId.values) {
      final root = rooms[id];
      if (root == null) continue;
      void walk(Node n) {
        if (n.name == name) out.add(n);
        for (final c in n.children) walk(c);
      }
      walk(root);
    }
    return out;
  }
}
```

Verify that `Node.name`, `Node.children` and `Node.parent` exist with those names:
`grep -n "String name\|get children\|Node? get parent\|Node? parent" ~/.pub-cache/hosted/pub.dev/flutter_scene-0.23.0/lib/src/node.dart`

Create one **stub per feature**. Here is the template, shown for `sky`. Repeat it for each id in the *Features* table, using that row's label, tier and toggleable value. Group files hold several classes:
- `post_features.dart`: `ToneMappingFeature`, `FogFeature`, `BloomFeature`, `AoFeature`, `GodRaysFeature`, `SsrFeature`
- `render_features.dart`: `ShadowsFeature`, `MsaaFeature`
- `reflection_features.dart`: `MirrorFeature`, `SeaReflectionFeature`
- `door_feature.dart`: `DoorFeature` (non-toggleable, id `door`, tier free) and `PortalCullingFeature`
- `curtains_feature.dart`: `CurtainsFeature` (non-toggleable)
- `screens_feature.dart`: `ScreensFeature` (non-toggleable, id `screens`)
- `books_feature.dart`: `BooksFeature` (non-toggleable, id `books`)
- `entrance_feature.dart`: `EntranceFeature` (non-toggleable, id `entrance`, tier free)

```dart
// lib/features/sky_feature.dart   (STUB, replaced by Task 12)
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

class SkyFeature extends HotelFeature {
  @override String get id => 'sky';
  @override String get label => 'Sky + time of day + IBL';
  @override CostTier get tier => CostTier.cheap;
  @override Future<void> mount(HotelContext ctx) async {}
  @override void unmount(HotelContext ctx) {}
}
```

```dart
// lib/hotel/feature_catalog.dart
import 'feature.dart';
import '../features/rooms_feature.dart';
import '../features/player_feature.dart';
import '../features/interactions_feature.dart';
import '../features/sky_feature.dart';
import '../features/ocean_feature.dart';
import '../features/post_features.dart';
import '../features/render_features.dart';
import '../features/lamps_feature.dart';
import '../features/door_feature.dart';
import '../features/curtains_feature.dart';
import '../features/water_fx_feature.dart';
import '../features/rain_feature.dart';
import '../features/rain_glass_feature.dart';
import '../features/lightning_feature.dart';
import '../features/reflection_features.dart';
import '../features/screens_feature.dart';
import '../features/books_feature.dart';
import '../features/instancing_feature.dart';
import '../features/entrance_feature.dart';

/// Mount order matters: rooms first (others look nodes up by name).
List<HotelFeature> buildCatalog() => [
      RoomsFeature(), PlayerFeature(), InteractionsFeature(),
      SkyFeature(), OceanFeature(),
      ToneMappingFeature(), FogFeature(), BloomFeature(), AoFeature(),
      GodRaysFeature(), SsrFeature(),
      ShadowsFeature(), MsaaFeature(),
      LampsFeature(), DoorFeature(), PortalCullingFeature(), CurtainsFeature(),
      WaterFxFeature(), RainFeature(), RainGlassFeature(), LightningFeature(),
      MirrorFeature(), SeaReflectionFeature(),
      ScreensFeature(), BooksFeature(), InstancingFeature(), EntranceFeature(),
    ];
```

Default-on values: `rooms, player, interactions, sky, ocean, tone_mapping, fog, shadows, lamps, door, portal_culling, curtains, screens, books, instancing, entrance` are `true`. Every **expensive** feature, plus `msaa`, `water_fx` and `lightning`, has `defaultOn => false`.

```dart
// lib/hotel/hotel_scene.dart
import 'package:flutter_scene/scene.dart';
import 'feature_catalog.dart';
import 'feature_registry.dart';
import 'hotel_context.dart';

class HotelScene {
  HotelScene() {
    ctx = HotelContext(scene);
    registry = FeatureRegistry(buildCatalog(), mountContext: ctx);
  }
  final Scene scene = Scene();
  late final HotelContext ctx;
  late final FeatureRegistry registry;

  Future<void> start() async {
    ctx.applyLook();
    await registry.mountDefaults();
  }

  void tick(double dt) => registry.tick(dt);
}
```

Check the `SceneView.onTick` signature before wiring it:
`grep -n "onTick" ~/.pub-cache/hosted/pub.dev/flutter_scene-0.23.0/lib/src/widgets/scene_view.dart | head`
Adapt `hotel_page.dart` so the callback receives dt in seconds.

- [x] **Step 9: UI shell**

```dart
// lib/ui/hotel_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import '../hotel/hotel_scene.dart';
import 'effects_sheet.dart';
import 'hud.dart';

class HotelPage extends StatefulWidget {
  const HotelPage({super.key});
  @override State<HotelPage> createState() => _HotelPageState();
}

class _HotelPageState extends State<HotelPage> {
  final hotel = HotelScene();
  late final Future<void> _ready = hotel.start();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder(
        future: _ready,
        builder: (context, snap) => Stack(children: [
          Positioned.fill(
            child: SceneView(hotel.scene,
                camera: hotel.ctx.camera,
                onTick: (dt) => hotel.tick(dt)),   // adapt to real signature
          ),
          const Positioned(top: 48, left: 12, child: Hud()),
          Positioned(
            top: 48, right: 12,
            child: FilledButton.tonal(
              onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => EffectsSheet(registry: hotel.registry)),
              child: const Text('🎛 Effects'),
            ),
          ),
          Positioned(
            left: 16, right: 16, bottom: 24,
            child: Row(children: [
              const Text('🕑', style: TextStyle(fontSize: 20)),
              Expanded(
                child: ValueListenableBuilder<double>(
                  valueListenable: hotel.ctx.timeOfDay,
                  builder: (_, t, __) => Slider(
                      min: 0, max: 24, value: t,
                      label: '${t.floor()}:00',
                      onChanged: (v) => hotel.ctx.timeOfDay.value = v),
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: hotel.ctx.rainRequested,
                builder: (_, on, __) => IconButton(
                  icon: Text(on ? '🌧' : '☀️', style: const TextStyle(fontSize: 22)),
                  onPressed: () => hotel.ctx.rainRequested.value = !on),
              ),
            ]),
          ),
          if (snap.connectionState != ConnectionState.done)
            const Center(child: CircularProgressIndicator()),
        ]),
      ),
    );
  }
}
```

The joystick, look pad and crosshair are added by Tasks 10 and 11 **inside their own feature files**. Each exposes a `static Widget overlay(HotelContext ctx)`. To avoid any Wave C task editing `hotel_page.dart`, add these three lines to the `Stack` now:

```dart
PlayerFeature.overlay(hotel.ctx),
InteractionsFeature.overlay(hotel.ctx),
ScreensFeature.overlay(hotel.ctx),
EntranceFeature.overlay(hotel.ctx),
```

Give each stub feature a `static Widget overlay(HotelContext ctx) => const SizedBox.shrink();`.

```dart
// lib/ui/effects_sheet.dart
import 'package:flutter/material.dart';
import '../hotel/feature.dart';
import '../hotel/feature_registry.dart';

class EffectsSheet extends StatelessWidget {
  const EffectsSheet({super.key, required this.registry, this.presetRow});
  final FeatureRegistry registry;
  /// Task 8 passes its preset chips here.
  final Widget? presetRow;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: registry,
      builder: (context, _) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, scroll) => ListView(controller: scroll, children: [
          if (presetRow != null) presetRow!,
          for (final tier in CostTier.values) ...[
            ListTile(title: Text(tier.name.toUpperCase(),
                style: Theme.of(context).textTheme.labelLarge)),
            for (final f in registry.features
                .where((f) => f.tier == tier && f.toggleable))
              SwitchListTile(
                title: Text(f.label),
                value: registry.isEnabled(f.id),
                onChanged: (v) => registry.setEnabled(f.id, v),
              ),
          ],
        ]),
      ),
    );
  }
}
```

```dart
// lib/ui/hud.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// FPS + UI/raster ms (avg and p90 over the last 2 s of FrameTimings).
class Hud extends StatefulWidget {
  const Hud({super.key});
  @override State<Hud> createState() => _HudState();
}

class _HudState extends State<Hud> {
  final List<FrameTiming> _window = [];
  String _text = '…';

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  void _onTimings(List<FrameTiming> t) {
    _window.addAll(t);
    final cutoff = _window.last.timestampInMicroseconds(FramePhase.rasterFinish) - 2000000;
    _window.removeWhere((f) => f.timestampInMicroseconds(FramePhase.rasterFinish) < cutoff);
    double ms(Duration d) => d.inMicroseconds / 1000;
    List<double> sorted(Iterable<double> xs) => xs.toList()..sort();
    final ui = sorted(_window.map((f) => ms(f.buildDuration)));
    final raster = sorted(_window.map((f) => ms(f.rasterDuration)));
    double avg(List<double> xs) => xs.reduce((a, b) => a + b) / xs.length;
    double p90(List<double> xs) => xs[(xs.length * 0.9).floor().clamp(0, xs.length - 1)];
    setState(() => _text =
        '${(_window.length / 2).round()} fps\n'
        'UI  ${avg(ui).toStringAsFixed(1)} / p90 ${p90(ui).toStringAsFixed(1)} ms\n'
        'GPU ${avg(raster).toStringAsFixed(1)} / p90 ${p90(raster).toStringAsFixed(1)} ms');
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(_text, style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace')),
        ),
      );
}
```

Replace `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'ui/hotel_page.dart';

void main() => runApp(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HotelPage(),
    ));
```

Delete `test/widget_test.dart`. It tests the counter template.

- [x] **Step 10: Verify.** Run `fvm flutter analyze` and expect no errors. Run `fvm flutter test` and expect everything to pass. Then run `fvm flutter run --enable-flutter-gpu -d "iPhone 17 Pro"`. Expected: a black scene with the HUD, the Effects button (the sheet lists every toggle grouped by tier), and the time slider. Toggling doesn't crash.

- [x] **Step 11: Commit**

```bash
git add -A
git commit -m "feat: core framework — feature registry, look composer, catalog stubs, HUD, effects sheet"
```

---

## Wave B (pure Dart; run all six in parallel)

### Task 3: Floor plan and 2D colliders

**Files:**
- Modify: `lib/math/floor_plan.dart` (keep `enum RoomId`)
- Modify: `lib/math/colliders.dart` (keep `Box2`)
- Test: `test/math/floor_plan_test.dart`, `test/math/colliders_test.dart`

**Interfaces (Produces):**

```dart
// floor_plan.dart
enum RoomId { a, b }
class FloorPlan {
  static const double roomWidth = 8, roomDepth = 6, balconyDepth = 1.8,
      ceiling = 2.8, eyeHeight = 1.6, wallT = 0.12;
  static const double doorZ0 = 2.0, doorZ1 = 2.9;     // connecting door span on x=0
  static const double bathX1 = -5.2, bathZ1 = 2.6;    // bathroom box corner (room A)
  static const double bathDoorZ0 = 1.2, bathDoorZ1 = 2.0;
  static RoomId roomOf(Vector2 xz);                   // x<0 → a, else b
  static Vector2 mirror(Vector2 xz);                  // (-x, z)
  /// Static wall + furniture boxes for BOTH rooms (room B = mirror of A),
  /// with the connecting-door gap left open. The door leaf is dynamic (Task 17).
  static List<Box2> staticColliders();
  /// Room A furniture footprints (Task 9 builds placeholder meshes from these).
  static const Map<String, Box2> furnitureA;
}
// colliders.dart
class Box2 { const Box2(minX,minZ,maxX,maxZ); Box2 mirrored(); bool contains(Vector2 p); }
/// Moves a circle from [from] toward [to], sliding along boxes; never ends inside one.
Vector2 moveCircle(Vector2 from, Vector2 to, double radius, Iterable<Box2> boxes);
```

- [x] **Step 1: Failing tests**

```dart
// test/math/colliders_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/math/colliders.dart';

void main() {
  const wall = Box2(0, 0, 1, 10); // wall occupying x∈[0,1]
  const r = 0.25;

  test('free movement is unchanged', () {
    final p = moveCircle(Vector2(-3, 5), Vector2(-2, 5), r, [wall]);
    expect(p.x, closeTo(-2, 1e-9));
    expect(p.y, closeTo(5, 1e-9));
  });

  test('walking into a wall stops at radius distance', () {
    final p = moveCircle(Vector2(-1, 5), Vector2(0.5, 5), r, [wall]);
    expect(p.x, closeTo(-r, 1e-6));
  });

  test('diagonal into wall slides along it', () {
    final p = moveCircle(Vector2(-1, 5), Vector2(0.5, 6), r, [wall]);
    expect(p.x, closeTo(-r, 1e-6));
    expect(p.y, closeTo(6, 1e-6));
  });

  test('fast step cannot tunnel through a thin wall', () {
    const thin = Box2(0, 0, 0.12, 10);
    final p = moveCircle(Vector2(-1, 5), Vector2(3, 5), r, [thin]);
    expect(p.x, lessThan(0));
  });

  test('player overlapping a newly-enabled box is pushed out, not stuck', () {
    const door = Box2(-0.05, 2.0, 0.05, 2.9);
    final start = Vector2(0.0, 2.45); // standing in the doorway as it closes
    final p = moveCircle(start, start, r, [door]);
    final inside = p.x > door.minX - r + 1e-6 && p.x < door.maxX + r - 1e-6 &&
        p.y > door.minZ - r + 1e-6 && p.y < door.maxZ + r - 1e-6;
    expect(inside, false);
  });

  test('mirrored box flips x', () {
    final m = const Box2(-8, 0, -5.2, 2.6).mirrored();
    expect([m.minX, m.maxX], [5.2, 8]);
  });
}
```

```dart
// test/math/floor_plan_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/math/floor_plan.dart';
import 'package:flutter_3d/math/colliders.dart';

void main() {
  test('roomOf splits at x=0', () {
    expect(FloorPlan.roomOf(Vector2(-0.1, 3)), RoomId.a);
    expect(FloorPlan.roomOf(Vector2(0.1, 3)), RoomId.b);
  });

  test('colliders are symmetric in x', () {
    final boxes = FloorPlan.staticColliders();
    for (final b in boxes) {
      final m = b.mirrored();
      expect(boxes.any((o) =>
          (o.minX - m.minX).abs() < 1e-9 && (o.maxX - m.maxX).abs() < 1e-9 &&
          (o.minZ - m.minZ).abs() < 1e-9 && (o.maxZ - m.maxZ).abs() < 1e-9), true,
          reason: 'missing mirror of $b');
    }
  });

  test('you can walk from room A to room B through the open door gap', () {
    var p = Vector2(-1.0, 2.45);
    for (var i = 0; i < 40; i++) {
      p = moveCircle(p, p + Vector2(0.05, 0), 0.25, FloorPlan.staticColliders());
    }
    expect(p.x, greaterThan(0.5));
  });

  test('you cannot walk through the shared wall outside the door', () {
    var p = Vector2(-1.0, 4.5);
    for (var i = 0; i < 40; i++) {
      p = moveCircle(p, p + Vector2(0.05, 0), 0.25, FloorPlan.staticColliders());
    }
    expect(p.x, lessThan(0));
  });

  test('balcony railing keeps you inside z < 7.8', () {
    var p = Vector2(-4, 6.5);
    for (var i = 0; i < 60; i++) {
      p = moveCircle(p, p + Vector2(0, 0.05), 0.25, FloorPlan.staticColliders());
    }
    expect(p.y, lessThan(7.8));
  });
}
```

Add `Box2.toString()` so failures print readably.

- [x] **Step 2:** Run `fvm flutter test test/math/`. Expected: FAIL (`moveCircle` and `FloorPlan` undefined).

- [x] **Step 3: Implement**

```dart
// lib/math/colliders.dart
import 'dart:math' as math;
import 'package:vector_math/vector_math.dart';

class Box2 {
  const Box2(this.minX, this.minZ, this.maxX, this.maxZ);
  final double minX, minZ, maxX, maxZ;
  Box2 mirrored() => Box2(-maxX, minZ, -minX, maxZ);
  bool contains(Vector2 p) => p.x >= minX && p.x <= maxX && p.y >= minZ && p.y <= maxZ;
  @override
  String toString() => 'Box2($minX,$minZ → $maxX,$maxZ)';
}

/// Pushes a circle (centre [p], radius [r]) out of [b]. Returns the corrected centre.
Vector2 _pushOut(Vector2 p, double r, Box2 b) {
  final cx = p.x.clamp(b.minX, b.maxX).toDouble();
  final cz = p.y.clamp(b.minZ, b.maxZ).toDouble();
  final dx = p.x - cx, dz = p.y - cz;
  final d2 = dx * dx + dz * dz;
  if (d2 >= r * r) return p;
  if (d2 > 1e-12) {
    final d = math.sqrt(d2);
    return Vector2(cx + dx / d * r, cz + dz / d * r);
  }
  // Centre inside the box: exit through the nearest face.
  final exits = <double>[p.x - b.minX, b.maxX - p.x, p.y - b.minZ, b.maxZ - p.y];
  var k = 0;
  for (var i = 1; i < 4; i++) {
    if (exits[i] < exits[k]) k = i;
  }
  return switch (k) {
    0 => Vector2(b.minX - r, p.y),
    1 => Vector2(b.maxX + r, p.y),
    2 => Vector2(p.x, b.minZ - r),
    _ => Vector2(p.x, b.maxZ + r),
  };
}

Vector2 moveCircle(Vector2 from, Vector2 to, double radius, Iterable<Box2> boxes) {
  final list = boxes.toList();
  final delta = to - from;
  // Sub-step so no step exceeds half the radius (no tunnelling through thin walls).
  final steps = math.max(1, (delta.length / (radius * 0.5)).ceil());
  var p = from.clone();
  for (var s = 0; s < steps; s++) {
    p += delta / steps.toDouble();
    for (var iter = 0; iter < 3; iter++) {
      for (final b in list) {
        p = _pushOut(p, radius, b);
      }
    }
  }
  if (steps == 0 || delta.length2 == 0) {
    for (final b in list) {
      p = _pushOut(p, radius, b);
    }
  }
  return p;
}
```

Build `lib/math/floor_plan.dart` using the Design layout. Wall boxes for room A (thickness `wallT` = 0.12):
- the back (corridor) wall at z ∈ [−0.12, 0];
- the outer side wall at x ∈ [−8.12, −8];
- the shared wall at x ∈ [−0.06, 0] in two pieces, z ∈ [0, doorZ0] and z ∈ [doorZ1, 6];
- the window wall at z ∈ [6, 6.12], **except** a 1.2 m balcony-door gap at x ∈ [−3.6, −2.4];
- the balcony railing at z ∈ [7.8, 7.92], x ∈ [−8, 0];
- the balcony side at x ∈ [−0.06, 0], z ∈ [6, 7.8];
- the bathroom walls: x ∈ [−5.26, −5.2] with a gap for z ∈ [bathDoorZ0, bathDoorZ1], and z ∈ [2.6, 2.66] for x ∈ [−8, −5.2].

`furnitureA` holds the following boxes. The bed and sofa get colliders; the TV and desk are against walls.

```dart
static const Map<String, Box2> furnitureA = {
  'bed':  Box2(-7.4, 3.2, -5.4, 5.4),
  'sofa': Box2(-2.6, 3.6, -0.8, 4.4),
  'desk': Box2(-4.6, 0.0, -3.0, 0.6),
  'tv_unit': Box2(-7.6, 2.66, -5.8, 2.9),  // against the bathroom wall, facing the bed
  'shelf': Box2(-1.6, 0.0, -0.5, 0.4),
  'basin': Box2(-8.0, 0.0, -7.4, 1.0),
  'shower': Box2(-6.4, 0.0, -5.2, 1.1),
};
```

`staticColliders()` returns room A's walls and furniture **plus** `.mirrored()` of each, **without** duplicating the boxes that lie on x = 0. The shared-wall pieces are added only once: make them symmetric, x ∈ [−0.06, 0.06], and skip them in the mirroring step.

- [x] **Step 4:** Run `fvm flutter test test/math/`. Expected: all PASS.

- [x] **Step 5: Commit**

```bash
git add lib/math/floor_plan.dart lib/math/colliders.dart test/math/floor_plan_test.dart test/math/colliders_test.dart
git commit -m "feat(math): floor plan and sliding circle-vs-box colliders"
```

---

### Task 4: First-person movement maths

**Files:** Create `lib/math/fp_movement.dart`. Test: `test/math/fp_movement_test.dart`.

**Interfaces (Produces):**

```dart
class FpState { FpState(this.xz, this.yaw, this.pitch); final Vector2 xz; final double yaw, pitch; }
const double kWalkSpeed = 1.4;          // m/s at full stick
const double kLookSensitivity = 0.005;  // rad per logical pixel
const double kMaxPitch = 80 * degrees2Radians;
/// yaw 0 → looking toward +Z; positive yaw turns toward +X.
Vector3 forwardOf(double yaw, double pitch);
/// stick: x = strafe right, y = forward (+1 = up on the joystick). Returns the desired xz (pre-collision).
Vector2 desiredStep(FpState s, Offset stick, double dt);
FpState applyLook(FpState s, Offset dragDelta);  // drag right → turn right; drag up → look up
```

- [x] **Step 1: Failing test**

```dart
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/math/fp_movement.dart';

void main() {
  test('yaw 0 looks +Z, yaw +90° looks +X', () {
    final f0 = forwardOf(0, 0);
    expect(f0.z, closeTo(1, 1e-9));
    final f90 = forwardOf(math.pi / 2, 0);
    expect(f90.x, closeTo(1, 1e-9));
  });

  test('full forward stick for 1 s moves kWalkSpeed along forward', () {
    final s = FpState(Vector2(0, 0), 0, 0);
    final p = desiredStep(s, const Offset(0, 1), 1.0);
    expect(p.y, closeTo(kWalkSpeed, 1e-9));
    expect(p.x, closeTo(0, 1e-9));
  });

  test('strafe right at yaw 0 moves toward -X (right-hand when facing +Z)', () {
    final p = desiredStep(FpState(Vector2(0, 0), 0, 0), const Offset(1, 0), 1.0);
    expect(p.x, closeTo(-kWalkSpeed, 1e-9));
  });

  test('diagonal stick is not faster than full stick', () {
    final p = desiredStep(FpState(Vector2(0, 0), 0, 0), const Offset(1, 1), 1.0);
    expect(p.length, lessThanOrEqualTo(kWalkSpeed + 1e-9));
  });

  test('pitch clamps to ±80°', () {
    var s = FpState(Vector2.zero(), 0, 0);
    s = applyLook(s, const Offset(0, -100000));
    expect(s.pitch, closeTo(kMaxPitch, 1e-9));
  });

  test('drag right turns right (toward -X when facing +Z)', () {
    final s = applyLook(FpState(Vector2.zero(), 0, 0), const Offset(10, 0));
    // Facing +Z with +Y up, "right" is -X. Turning right must move forward toward -X.
    expect(forwardOf(s.yaw, 0).x, lessThan(0));
  });
}
```

(With +Y up and facing +Z, the viewer's right-hand side is −X. That's why strafe-right and turn-right go toward −X. Confirm on the simulator in Task 10. If the screen shows the mirror image, the camera's handedness differs, so flip the signs in `desiredStep` and `applyLook` **and** these tests together.)

- [x] **Step 2:** Run `fvm flutter test test/math/fp_movement_test.dart`. Expected: FAIL.

- [x] **Step 3: Implement**

```dart
import 'dart:math' as math;
import 'dart:ui';
import 'package:vector_math/vector_math.dart';

class FpState {
  FpState(this.xz, this.yaw, this.pitch);
  final Vector2 xz;
  final double yaw, pitch;
}

const double kWalkSpeed = 1.4;
const double kLookSensitivity = 0.005;
const double kMaxPitch = 80 * degrees2Radians;

Vector3 forwardOf(double yaw, double pitch) => Vector3(
    math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch));

Vector2 desiredStep(FpState s, Offset stick, double dt) {
  var v = Vector2(stick.dx, stick.dy);
  if (v.length > 1) v = v.normalized();
  final fwd = Vector2(math.sin(s.yaw), math.cos(s.yaw));
  final right = Vector2(-fwd.y, fwd.x); // facing +Z (yaw 0) → right is −X
  return s.xz + (fwd * v.y + right * v.x) * (kWalkSpeed * dt);
}

FpState applyLook(FpState s, Offset d) => FpState(
      s.xz,
      s.yaw - d.dx * kLookSensitivity,
      (s.pitch - d.dy * kLookSensitivity).clamp(-kMaxPitch, kMaxPitch).toDouble(),
    );
```

Check for yaw 0: `fwd = (0, 1)`, so `right = (-1, 0)` = −X, as the strafe test expects. For `applyLook`, drag right (+dx) decreases yaw, so forward swings from +Z toward −X, which is what the turn-right test expects.

- [x] **Step 4:** Run the test again. Expected: PASS.
- [x] **Step 5: Commit**: `git add lib/math/fp_movement.dart test/math/fp_movement_test.dart && git commit -m "feat(math): first-person movement and look"`

---

### Task 5: Picking maths (screen → ray, nearest hit)

**Files:** Create `lib/math/picking.dart`. Test: `test/math/picking_test.dart`.

**Interfaces (Produces):**

```dart
class PickRay { PickRay(this.origin, this.direction); final Vector3 origin, direction; }
/// Ray through [screen] (logical px) for a perspective camera.
PickRay screenRay({required Offset screen, required Size viewport,
    required Vector3 eye, required Vector3 target, required Vector3 up, required double fovY});
/// Of candidate hits (distance or null), the index of the nearest non-null, or null.
int? nearest(List<double?> distances);
```

- [x] **Step 1: Failing test**

```dart
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/math/picking.dart';

void main() {
  final eye = Vector3(0, 1.6, 0), target = Vector3(0, 1.6, 5), up = Vector3(0, 1, 0);
  const vp = Size(400, 800);

  test('centre of screen points at target', () {
    final r = screenRay(screen: const Offset(200, 400), viewport: vp,
        eye: eye, target: target, up: up, fovY: 60 * degrees2Radians);
    expect(r.direction.z, closeTo(1, 1e-6));
    expect(r.origin, eye);
  });

  test('top edge is +fovY/2 above forward', () {
    final r = screenRay(screen: const Offset(200, 0), viewport: vp,
        eye: eye, target: target, up: up, fovY: 60 * degrees2Radians);
    final elev = r.direction.y / r.direction.xz.length;
    expect(elev, closeTo(0.57735, 1e-4)); // tan 30°
  });

  test('nearest hit wins', () {
    expect(nearest([null, 3.0, 1.5, 2.0]), 2);
    expect(nearest([null, null]), isNull);
  });
}
```

- [x] **Step 2:** Run it. Expected: FAIL.
- [x] **Step 3: Implement**

```dart
import 'dart:math' as math;
import 'dart:ui';
import 'package:vector_math/vector_math.dart';

class PickRay {
  PickRay(this.origin, this.direction);
  final Vector3 origin, direction;
}

PickRay screenRay({required Offset screen, required Size viewport,
    required Vector3 eye, required Vector3 target, required Vector3 up,
    required double fovY}) {
  final fwd = (target - eye).normalized();
  final right = fwd.cross(up).normalized();
  final camUp = right.cross(fwd).normalized();
  final ndcX = screen.dx / viewport.width * 2 - 1;
  final ndcY = 1 - screen.dy / viewport.height * 2;
  final t = math.tan(fovY / 2);
  final aspect = viewport.width / viewport.height;
  final dir = (fwd + right * (ndcX * t * aspect) + camUp * (ndcY * t)).normalized();
  return PickRay(eye.clone(), dir);
}

int? nearest(List<double?> d) {
  int? best;
  for (var i = 0; i < d.length; i++) {
    final v = d[i];
    if (v != null && (best == null || v < d[best]!)) best = i;
  }
  return best;
}
```

`fwd.cross(up)` gives the camera's right vector; for fwd = +Z and up = +Y that's −X. This matches Task 4's convention.

- [x] **Step 4:** Run it. Expected: PASS.
- [x] **Step 5: Commit**: `git add lib/math/picking.dart test/math/picking_test.dart && git commit -m "feat(math): screen-ray picking"`

---

### Task 6: PokéAPI model and client

**Files:** Create `lib/data/pokemon.dart`. Test: `test/data/pokeapi_client_test.dart`. Uses `package:http` (`MockClient` comes from `package:http/testing.dart`).

**Interfaces (Produces):**

```dart
class Pokemon {
  final int id; final String name; final List<String> types;
  final Map<String, int> stats;   // hp, attack, defense, special-attack, special-defense, speed
  final String artworkUrl;        // sprites.other['official-artwork'].front_default
  final int heightDm, weightHg;
  factory Pokemon.fromJson(Map<String, dynamic> j);
  String get displayName;         // "Pikachu"
}
sealed class PokemonResult {}
class PokemonLoaded extends PokemonResult { final Pokemon pokemon; }
class PokemonLoadFailure extends PokemonResult { final String message; }
class PokeApiClient {
  PokeApiClient({http.Client? client, this.timeout = const Duration(seconds: 6)});
  Future<PokemonResult> fetch(int id);   // caches successes in memory
}
const List<int> kBookPokemon = [1, 4, 7, 25, 133, 143]; // book_0..book_5
```

- [x] **Step 1: Failing test**

```dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_3d/data/pokemon.dart';

const _pikachu = {
  'id': 25, 'name': 'pikachu', 'height': 4, 'weight': 60,
  'types': [{'slot': 1, 'type': {'name': 'electric'}}],
  'stats': [
    {'base_stat': 35, 'stat': {'name': 'hp'}},
    {'base_stat': 55, 'stat': {'name': 'attack'}},
  ],
  'sprites': {'other': {'official-artwork': {'front_default': 'https://img/25.png'}}},
};

void main() {
  test('parses name, types, stats, artwork', () {
    final p = Pokemon.fromJson(_pikachu);
    expect(p.displayName, 'Pikachu');
    expect(p.types, ['electric']);
    expect(p.stats['hp'], 35);
    expect(p.artworkUrl, 'https://img/25.png');
  });

  test('fetch hits /pokemon/<id> and caches', () async {
    var calls = 0;
    final c = PokeApiClient(client: MockClient((req) async {
      calls++;
      expect(req.url.toString(), 'https://pokeapi.co/api/v2/pokemon/25');
      return http.Response(jsonEncode(_pikachu), 200);
    }));
    expect(await c.fetch(25), isA<PokemonLoaded>());
    await c.fetch(25);
    expect(calls, 1);
  });

  test('network error returns PokemonLoadFailure', () async {
    final c = PokeApiClient(client: MockClient((_) async => throw http.ClientException('offline')));
    expect(await c.fetch(25), isA<PokemonLoadFailure>());
  });

  test('HTTP 404 returns PokemonLoadFailure', () async {
    final c = PokeApiClient(client: MockClient((_) async => http.Response('nope', 404)));
    expect(await c.fetch(25), isA<PokemonLoadFailure>());
  });

  test('timeout returns PokemonLoadFailure', () async {
    final c = PokeApiClient(
        timeout: const Duration(milliseconds: 20),
        client: MockClient((_) => Completer<http.Response>().future));
    expect(await c.fetch(25), isA<PokemonLoadFailure>());
  });

  test('missing artwork does not throw (empty url)', () {
    final j = Map<String, dynamic>.from(_pikachu)..['sprites'] = {};
    expect(Pokemon.fromJson(j).artworkUrl, '');
  });
}
```

- [x] **Step 2:** Run `fvm flutter test test/data/`. Expected: FAIL.
- [x] **Step 3: Implement** a hand-written `fromJson` using the paths shown above. `displayName` capitalises the first letter. `fetch` wraps `client.get(...).timeout(timeout)` in try/catch, returns a failure for non-200, and caches `PokemonLoaded` values in a `Map<int, Pokemon>`. Read nested maps with `as Map<String, dynamic>?` and `?.` so missing keys produce `''` or empty lists, never a throw.
- [x] **Step 4:** Run the tests. Expected: 6 PASS.
- [x] **Step 5: Commit**: `git add lib/data test/data && git commit -m "feat(data): PokéAPI model and client with failure results"`

---

### Task 7: Schedulers (weather fade, lightning timing, rebake throttle)

**Files:** Create `lib/math/schedulers.dart`. Tests: `test/math/weather_test.dart`, `test/math/lightning_schedule_test.dart`, `test/math/rebake_throttle_test.dart`.

**Interfaces (Produces):**

```dart
/// Moves [current] toward [target] at 1/fadeSeconds per second, clamped 0..1.
double approach(double current, double target, double dt, {double fadeSeconds = 2.5});

class LightningScheduler {
  LightningScheduler({required math.Random random, this.minGap = 4.5, this.maxGap = 12});
  /// Advance time; returns true on the frame a new strike should start.
  bool tick(double dt, {required bool enabled});
  /// Flash brightness 0..1 at [t] seconds since strike start; 0 after ~0.6 s.
  static double envelope(double t, List<double> pulseStarts);
  List<double> pulsesForStrike(); // 2–3 pulse start times within 0.5 s
}

/// Allows a rebake at most every [minInterval] while changes keep coming,
/// plus one final rebake once changes stop.
class RebakeThrottle {
  RebakeThrottle({this.minInterval = 0.4});
  void markDirty();
  /// Call every frame; returns true when a rebake should happen now.
  bool tick(double dt);
}
```

- [x] **Step 1: Failing tests**

```dart
// test/math/weather_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/math/schedulers.dart';

void main() {
  test('reaches target after fadeSeconds, never overshoots', () {
    var w = 0.0;
    for (var i = 0; i < 150; i++) { w = approach(w, 1, 1 / 60); }
    expect(w, 1.0);
    expect(approach(0.99, 1, 1), 1.0);
    expect(approach(0.5, 0, 0.5, fadeSeconds: 2.5), closeTo(0.3, 1e-9));
  });
}
```

```dart
// test/math/lightning_schedule_test.dart
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/math/schedulers.dart';

void main() {
  test('strikes are at least minGap apart', () {
    final s = LightningScheduler(random: math.Random(1));
    final times = <double>[];
    var t = 0.0;
    for (var i = 0; i < 60 * 120; i++) {
      t += 1 / 60;
      if (s.tick(1 / 60, enabled: true)) times.add(t);
    }
    expect(times.length, greaterThan(5));
    for (var i = 1; i < times.length; i++) {
      expect(times[i] - times[i - 1], greaterThanOrEqualTo(4.5 - 1e-9));
    }
  });

  test('disabled never strikes', () {
    final s = LightningScheduler(random: math.Random(1));
    for (var i = 0; i < 6000; i++) { expect(s.tick(1 / 60, enabled: false), false); }
  });

  test('envelope: at most 3 pulses, 0 after 0.7 s, peaks ≤ 1', () {
    final s = LightningScheduler(random: math.Random(2));
    final pulses = s.pulsesForStrike();
    expect(pulses.length, inInclusiveRange(2, 3));
    var peak = 0.0;
    for (var t = 0.0; t < 0.7; t += 0.001) {
      peak = math.max(peak, LightningScheduler.envelope(t, pulses));
    }
    expect(peak, lessThanOrEqualTo(1.0));
    expect(LightningScheduler.envelope(0.75, pulses), 0.0);
  });
}
```

```dart
// test/math/rebake_throttle_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/math/schedulers.dart';

void main() {
  test('continuous dragging rebakes at most every 0.4 s', () {
    final r = RebakeThrottle();
    var bakes = 0;
    for (var i = 0; i < 120; i++) { // 2 s of dragging at 60 fps
      r.markDirty();
      if (r.tick(1 / 60)) bakes++;
    }
    expect(bakes, inInclusiveRange(4, 6));
  });

  test('one final bake after changes stop', () {
    final r = RebakeThrottle();
    r.markDirty();
    var bakes = 0;
    for (var i = 0; i < 120; i++) { if (r.tick(1 / 60)) bakes++; }
    expect(bakes, 1);
  });

  test('no changes → no bakes', () {
    final r = RebakeThrottle();
    for (var i = 0; i < 120; i++) { expect(r.tick(1 / 60), false); }
  });
}
```

- [x] **Step 2:** Run `fvm flutter test test/math/`. Expected: the new tests FAIL.
- [x] **Step 3: Implement.**
  - `approach`: `current + (target - current).sign * min(|Δ|, dt / fadeSeconds)`, then clamp to 0..1.
  - `LightningScheduler`: keeps `_untilNext`, initialised to `minGap + r * (maxGap - minGap)`. It counts down only while enabled, returns true once it reaches ≤ 0, then resets.
  - `pulsesForStrike()`: `[0, 0.12 + r * 0.08]`, plus a third at `0.35 + r * 0.1` half the time.
  - `envelope`: the sum over pulses of `rise(12 ms) * exp(-(t - p - 0.012) / 0.055)`, with the first pulse at 0.4 amplitude and the rest at 1.0. Clamp to 1. Return 0 when `t > 0.7`.
  - `RebakeThrottle`: `_dirty`, `_sinceBake` (initially ∞). `tick` adds dt; if `_dirty && _sinceBake >= minInterval`, it bakes, clears dirty and resets `_sinceBake = 0`.

  The final bake after the drag ends follows naturally: dirty stays set until the interval allows it.
- [x] **Step 4:** Run the tests. Expected: PASS.
- [x] **Step 5: Commit**: `git add lib/math/schedulers.dart test/math/*_test.dart && git commit -m "feat(math): weather fade, lightning schedule, rebake throttle"`

---

### Task 8: Quality presets

**Files:** Create `lib/hotel/presets.dart` and `test/hotel/presets_test.dart`. Modify `lib/ui/effects_sheet.dart` to add the preset row (only this file's `presetRow` default).

**Interfaces (Produces):**

```dart
enum Preset { low, medium, high, ultra }
/// Toggleable feature ids that are ON for [p]. Each tier ⊇ the one below.
Set<String> presetIds(Preset p);
Future<void> applyPreset(FeatureRegistry r, Preset p); // enable listed, disable the other toggleables
```

Tiers:
- **low** = `{sky, ocean, tone_mapping, portal_culling, instancing}`
- **medium** = low + `{fog, shadows, lamps, water_fx}`
- **high** = medium + `{bloom, ao, msaa, rain, lightning}`
- **ultra** = high + `{god_rays, ssr, rain_glass, mirror, sea_reflection}`

- [x] **Step 1: Failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/hotel/presets.dart';
import 'package:flutter_3d/hotel/feature_catalog.dart';

void main() {
  test('each preset is a superset of the one below', () {
    for (var i = 1; i < Preset.values.length; i++) {
      expect(presetIds(Preset.values[i]).containsAll(presetIds(Preset.values[i - 1])), true);
    }
  });

  test('every id in a preset exists and is toggleable', () {
    final toggleable = buildCatalog().where((f) => f.toggleable).map((f) => f.id).toSet();
    for (final p in Preset.values) {
      expect(toggleable.containsAll(presetIds(p)), true, reason: '$p');
    }
  });

  test('ultra enables every toggleable feature', () {
    final toggleable = buildCatalog().where((f) => f.toggleable).map((f) => f.id).toSet();
    expect(presetIds(Preset.ultra), toggleable);
  });
}
```

- [x] **Step 2:** Run it. Expected: FAIL.
- [x] **Step 3: Implement.** Add to `EffectsSheet.build`: if `presetRow` is null, show a `Wrap` of four `ActionChip`s that call `applyPreset(registry, p)`.
- [x] **Step 4:** Run it. Expected: PASS.
- [x] **Step 5: Commit**: `git add lib/hotel/presets.dart test/hotel/presets_test.dart lib/ui/effects_sheet.dart && git commit -m "feat: Low/Medium/High/Ultra presets"`

---

## Wave C (run in parallel)

GPU tasks can't be unit-tested. Their verification is a **run plus screenshot** on the iOS simulator:

```bash
fvm flutter run --enable-flutter-gpu -d "iPhone 17 Pro" --pid-file /tmp/hotel.pid > run.log 2>&1 &
# after edits: kill -USR2 $(cat /tmp/hotel.pid)   # hot restart (.fmat needs full rebuild)
xcrun simctl io booted screenshot /tmp/shot.png
```

Then open the PNG with the Read tool and check the listed "expected" items. Also check **Android emulator (GLES)** for any task that adds a `.fmat` file.

### Task 9: Rooms (placeholder geometry, mirrored Room B)

**Files:** Replace `lib/features/rooms_feature.dart`. Create `lib/features/placeholder_rooms.dart`.
**Consumes:** `FloorPlan`, `Box2` (Task 3). **Produces:** `ctx.rooms[RoomId.a]` and `ctx.rooms[RoomId.b]`, with every node named per the *Node-name contract*.

- [x] **Step 1: Check the geometry APIs before coding.** Run:
`grep -n "class CuboidGeometry\|class PlaneGeometry\|class BoxGeometry\|class .*Geometry extends" -r ~/.pub-cache/hosted/pub.dev/flutter_scene-0.23.0/lib/src/geometry | head -30`
`grep -n "class PhysicallyBasedMaterial\|class UnlitMaterial" -A20 -r ~/.pub-cache/hosted/pub.dev/flutter_scene-0.23.0/lib/src/material | grep "this\.\|required" | head -30`
Also read `.claude/skills/flutter_scene-idioms/SKILL.md` for the idiomatic way to build a mesh node. Use a box geometry and PBR material with the names found.

- [x] **Step 2: Implement `placeholder_rooms.dart`**: `Node buildRoomA()` returns a node tree in Room A local space (x ∈ [−8, 0]). It contains:
  - The floor slab (named `floor`: wood-brown base colour, roughness 0.6), the ceiling (`ceiling`), and wall boxes from the Task 3 wall list, grouped under `walls`.
  - A box per `FloorPlan.furnitureA` entry, 0.45–0.9 m tall, with the bed white and the sofa blue-grey.
  - `door_connect`: a 0.9 × 2.1 × 0.05 box whose **origin is the hinge**. Child mesh offset +0.45 in z; node placed at (0, 0, doorZ0). Only Room A gets a door leaf; hide Room B's copy after mirroring (`nodesNamed('door_connect')[1].visible = false`), so there's one shared door.
  - `lamp_bedside` on a bedside table at (−7.7, 0.6, 5.6) and `lamp_floor` at (−0.4, 0, 5.6): a cylinder plus a shade.
  - `faucet_spout` at (−7.7, 1.05, 0.5), `shower_head` at (−5.8, 2.1, 0.55) and `shower_glass`, a 0.02-thick glass box at x = −6.4, z ∈ [0, 1.1], y ∈ [0, 2.0].
  - `mirror`: a quad on the wall x = −7.99, z ∈ [0.1, 1.0], y ∈ [1.1, 2.0], normal +X.
  - `window_glass`: a glass quad covering the window wall gap, alpha 0.15.
  - `curtain_left` and `curtain_right`: 0.05-thick boxes at the window, 1.4 m wide each, open by default (pushed to the sides).
  - `tv_screen`: an emissive-black quad 1.2 × 0.675 m, centre (−6.7, 1.3, 2.68), facing +z.
  - `pc_screen`: 0.55 × 0.34 on the desk at (−3.8, 1.05, 0.25), facing +z.
  - `book_0`…`book_5`: 0.03 × 0.24 × 0.17 boxes standing on the `shelf` at y = 1.0.
  - `door_entrance`: a 1.0 × 2.1 × 0.05 dark-wood box on the corridor wall at x ∈ [−2.3, −1.3], z = 0.03, with a small brass handle box. It is decorative; the wall collider behind it stays solid.

  Set `castsShadows = true` on every mesh node, individually.

- [x] **Step 3: Implement `RoomsFeature`**: `id 'rooms'`, `toggleable false`, tier free. `mount` does the following:

```dart
final a = buildRoomA()..name = 'room_a';
final b = Node(name: 'room_b')..add(buildRoomA());
b.localTransform = Matrix4.diagonal3Values(-1, 1, 1);
ctx.scene.add(a); ctx.scene.add(b);
ctx.rooms[RoomId.a] = a; ctx.rooms[RoomId.b] = b;
ctx.nodesNamed('door_connect').last.visible = false;
```

Check the node constructor and `localTransform` setter names first: `grep -n "Node({\|set localTransform\|bool visible" ~/.pub-cache/hosted/pub.dev/flutter_scene-0.23.0/lib/src/node.dart`.
`unmount` removes both nodes, clears `ctx.rooms`, and removes them from the scene (`grep -n "void remove" .../scene.dart`).

- [x] **Step 4: Verify.** Hot restart, then take a screenshot from the default camera at (−4, 1.6, 3), which looks toward +z. Expected:
  - the window wall, bed on the left, sofa on the right;
  - Room B is not visible;
  - furniture reads as boxes with lighting and **not inside-out**. With default studio lighting, faces are lit and not black.

  Temporarily set the camera to (4, 1.6, 3) for Room B and check the same (mirrored) layout. That is the mirror check. Revert the camera.
- [x] **Step 5: Commit**: `git add lib/features/rooms_feature.dart lib/features/placeholder_rooms.dart && git commit -m "feat: placeholder rooms, Room B mirrored by negative scale"`

### Task 10: First-person player (joystick + look pad + collision)

**Files:** Replace `lib/features/player_feature.dart`. Create `lib/ui/look_pad.dart`.
**Consumes:** `FloorPlan.staticColliders`, `moveCircle`, `ctx.dynamicColliders` (Task 3); `FpState`, `desiredStep`, `applyLook`, `forwardOf` (Task 4); `VirtualJoystick` from `package:flutter_scene/kit.dart`.

- [x] **Step 1:** Check the joystick callback type: `sed -n 17,50p ~/.pub-cache/hosted/pub.dev/flutter_scene-0.23.0/lib/src/kit/camera/virtual_joystick.dart`. Find what `onChanged` passes and whether up is +y or −y.

- [x] **Step 2: Implement.** `PlayerFeature` holds a `static final ValueNotifier<Offset> stick` and `static Offset pendingLook`. `tick`:

```dart
var s = FpState(ctx.playerXZ, ctx.playerYaw, _pitch);
s = applyLook(s, pendingLook); pendingLook = Offset.zero;
final want = desiredStep(s, stick.value, dt);
final boxes = [...FloorPlan.staticColliders(), ...ctx.dynamicColliders.values.expand((b) => b)];
ctx.playerXZ = moveCircle(s.xz, want, 0.25, boxes);
ctx.playerYaw = s.yaw; _pitch = s.pitch;
final eye = Vector3(ctx.playerXZ.x, FloorPlan.eyeHeight, ctx.playerXZ.y);
ctx.camera.position = eye;
ctx.camera.target = eye + forwardOf(s.yaw, s.pitch);
```

Cache `FloorPlan.staticColliders()` in a field; don't rebuild it every frame.

`static Widget overlay(ctx)` returns a `Stack` containing:
- `Positioned(left: 24, bottom: 90, child: VirtualJoystick(onChanged: (v) => stick.value = Offset(v.x, -v.y)))`. Adapt the sign so that pushing up means forward.
- `Positioned(right: 0, top: 0, bottom: 150, width: MediaQuery.width / 2, child: LookPad(onDrag: (d) => pendingLook += d))`.

`LookPad` is a `GestureDetector(onPanUpdate: (d) => onDrag(d.delta), behavior: HitTestBehavior.translucent)`.

- [x] **Step 3: Verify on the simulator.** Push up: you move toward the window. Drag right: the view turns right (if it's mirrored, go back to Task 4's note). Walk into the bed: you slide along it. Walk to the shared wall at z ≈ 2.45 and through the door gap into Room B. (The door is closed but has no collider until Task 17, so it's expected to pass through.) Walk to the balcony railing: you stop.
- [x] **Step 4: Commit**: `git add lib/features/player_feature.dart lib/ui/look_pad.dart && git commit -m "feat: first-person joystick walk with sliding collision"`

### Task 11: Tap-to-interact

**Files:** Replace `lib/features/interactions_feature.dart`.
**Consumes:** `InteractionRegistry` (Task 2), `screenRay`, `nearest` (Task 5), `Scene.raycast(Ray, {maxDistance, where, includeInvisible})` (signature verified in `scene.dart:349`).

- [x] **Step 1:** Read `raycast.dart:26-40` for `SceneRaycastHit` fields (node, distance), and check the `Ray` constructor: `grep -n "class Ray" -A10 ~/.pub-cache/hosted/pub.dev/vector_math-*/lib/src/vector_math/ray.dart`. Check that `Node.raycastable` exists (`grep -n raycastable .../node.dart`).

- [x] **Step 2: Implement.** In `mount`, listen to `ctx.interactions` and set `raycastable = true` on every registered node **and its descendants**. `overlay(ctx)` shows:
  - a centre crosshair `Icon(Icons.add, color: Colors.white70)`;
  - a label chip under it with the aimed-at `Interactable.label`, updated every 200 ms with a raycast from the screen centre;
  - a full-screen translucent `GestureDetector(onTapUp: ...)` placed **below** the joystick and look pad in the Stack order, so it doesn't steal drags. Use `onTapUp` only; the look pad handles pans.

  On tap:

```dart
final r = screenRay(screen: d.localPosition, viewport: size, eye: ctx.camera.position,
    target: ctx.camera.target, up: Vector3(0, 1, 0), fovY: ctx.camera.fovRadiansY);
final hit = ctx.scene.raycast(Ray.originDirection(r.origin, r.direction),
    maxDistance: 6, where: (n) => n.visible);
final i = hit == null ? null : ctx.interactions.forNode(hit.node);
if (i != null) i.onTap();
```

Keep `includeInvisible` false, so that portal-culled rooms (made invisible by Task 17) can't be picked. Limit `maxDistance` to 6 m: you interact within reach, and so it's not possible to click a lamp from across two rooms.

- [x] **Step 3: Verify.** Temporarily register an interactable on `lamp_bedside` that prints `debugPrint('tap lamp')`. Tap it on the simulator and check `run.log`. Remove the temporary code.
- [x] **Step 4: Commit**: `git add lib/features/interactions_feature.dart && git commit -m "feat: tap-to-interact with crosshair label"`

### Task 12: Sky, time of day, IBL

**Files:** Replace `lib/features/sky_feature.dart`.
**Consumes:** `ctx.look` and `ctx.applyLook()` (Task 2), `RebakeThrottle` (Task 7), `DayNightCycleComponent` (`kit`, fields `timeOfDay`, `latitude`, `sunLightNode`, `skySource`, `targetScene`), `PhysicalSkySource`, `Skybox`, `SkyEnvironment`.

- [x] **Step 1:** Read `.claude/skills/flutter_scene-looks/SKILL.md` and `.claude/skills/flutter_scene-kit/SKILL.md` (the day/night section). Check the constructors: `grep -n "Skybox(\|SkyEnvironment(\|PhysicalSkySource(" -A12 ~/.pub-cache/hosted/pub.dev/flutter_scene-0.23.0/lib/src/{skybox,sky_environment,sky_sources}.dart | grep "this\.\|required\|refresh"`. Find how to trigger a manual refresh (`invalidate()` or similar).

- [x] **Step 2: Implement.**
  - `mount`: create a sun `DirectionalLight` with `castsShadow: false` (Task 15 owns shadows). Put `PhysicalSkySource` in `Skybox(sky)` and `SkyEnvironment(sky, refresh: manual, faceResolution: 64, equirectWidth: 256)`. Store them in `ctx.look.skybox`, `.skyEnvironment` and `.sunLight`, then call `ctx.applyLook()`.
  - Add an **unmounted** `DayNightCycleComponent(latitude: 13.7)` to drive the sun direction, colour and intensity from `ctx.timeOfDay.value` (playbook §3 rule 5: `evaluateLighting()` works unmounted). Latitude 13.7° is Bangkok-ish.
  - Listen to `ctx.timeOfDay` and call `throttle.markDirty()`. In `tick`: update the sun direction every frame (cheap). When `throttle.tick(dt)` returns true, invalidate the sky environment (rebake the IBL).
  - Night (sun below the horizon): `ctx.look.environmentIntensity = 0.3` and a cold, dim moon light. Otherwise 1.0. After changing look fields, call `ctx.applyLook()`.
  - `unmount`: null the three look fields and call `applyLook()`. That shows the "no sky" look, which makes a good toggle demo.

- [x] **Step 3: Verify.**
  - At 15:00, looking out the window, the sky is blue, not the app background (sample a sky pixel; it must not be pure black).
  - Drag the slider to 19:00: an orange horizon. At 23:00: dark, with the room still readable.
  - `run.log` shows no NaN warnings.
  - Face the low sun: the frame must not be white (playbook §3 rule 3). If it is, lower `ctx.look.exposure` at low sun elevations.
- [x] **Step 4: Commit**: `git add lib/features/sky_feature.dart && git commit -m "feat: physical sky with time-of-day slider and throttled IBL rebake"`

### Task 13: Ocean and beach, 90 m below

**Files:** Replace `lib/features/ocean_feature.dart`.

- [x] **Step 1:** Read `.claude/skills/flutter_scene-procedural/SKILL.md` (ocean and terrain sections), and grep `WaterSurfaceComponent` and `GerstnerWave` in `lib/src/kit/environment/water_surface_component.dart`.
- [x] **Step 2: Implement.**
  - The sea: a large opaque plane, or the kit water surface, at y = −90 covering z ∈ [40, 800] and x ∈ [−600, 600]. Use a PBR material, dark teal base colour, roughness 0.15, so the sky reflects via IBL. Set `frustumCulled = false` if you displace it on the GPU.
  - The beach: a sand-coloured box strip at y = −90.2, z ∈ [0, 40], plus a sloped quad joining the water.
  - A hotel facade below the balcony: one large box at x ∈ [−30, 30], z ∈ [−20, 6], y ∈ [−90, 0], so you don't see void when looking down.
  - Store the sea node as `ctx.scene`-level node `sea` (name it `sea`). Task 23 looks for it.
  - Instanced palms and umbrellas are Task 26; don't add them here.

  `unmount` removes everything.
- [x] **Step 3: Verify.** Stand on the balcony and look down (pitch −45°). You see the beach, and the sea reaches the horizon. With fog on (Task 14), the far edge fades.
- [x] **Step 4: Commit**: `git add lib/features/ocean_feature.dart && git commit -m "feat: ocean and beach backdrop 90 m below"`

### Task 14: Post-effect toggles

**Files:** Replace `lib/features/post_features.dart` (6 classes).
**Consumes:** `ctx.look` flags and `ctx.applyLook()`.

- [x] **Step 1: Implement.** Each class sets its flag in `mount`, clears it in `unmount`, and calls `ctx.applyLook()` in both. Example:

```dart
class BloomFeature extends HotelFeature {
  @override String get id => 'bloom';
  @override String get label => 'Bloom + lens flare';
  @override CostTier get tier => CostTier.expensive;
  @override bool get defaultOn => false;
  @override Future<void> mount(HotelContext ctx) async { ctx.look.bloom = true; ctx.applyLook(); }
  @override void unmount(HotelContext ctx) { ctx.look.bloom = false; ctx.applyLook(); }
}
```

Mapping: `tone_mapping` → `look.toneMapping`, `fog` → `look.fog`, `bloom` → `look.bloom`, `ao` → `look.ao`, `god_rays` → `look.godRays`, `ssr` → `look.ssr`.
- [x] **Step 2: Verify.** Toggle each one in the sheet and screenshot before and after. Each makes a visible difference, and the sky stays after every toggle (engine rule 1).
- [x] **Step 3: Commit**: `git add lib/features/post_features.dart && git commit -m "feat: post-processing toggles"`

### Task 15: Shadows and MSAA toggles

**Files:** Replace `lib/features/render_features.dart`.

- [x] **Step 1:** `grep -n "castsShadow\|shadowMapSize\|cascade" ~/.pub-cache/hosted/pub.dev/flutter_scene-0.23.0/lib/src/light.dart | head -20` and `sed -n 110,130p .../scene.dart` (the `AntiAliasingMode` values).
- [x] **Step 2: Implement.**
  - `ShadowsFeature.mount`: `ctx.look.sunLight?.castsShadow = true` with shadow map size 2048 and 2 cascades, if those fields exist. Then `applyLook()`. `unmount` sets it false. If the sky feature is off (`sunLight == null`), mount is a no-op. It also re-applies when Task 12 creates the light: Task 12 creates the light with `castsShadow: ctx.look.sunShadows`. Add `bool sunShadows = false` to `LookState`; **this is the one allowed edit to `lib/hotel/look.dart`**. Set it here, and Task 12 reads it.
  - `MsaaFeature.mount`: `ctx.scene.antiAliasingMode = AntiAliasingMode.msaa`. `unmount` sets `AntiAliasingMode.none`.
- [x] **Step 3: Verify.** At 15:00 there are furniture shadows on the floor; toggle off and they're gone. With MSAA, the bed edges are smooth (zoom into the screenshot).
- [x] **Step 4: Commit**: `git add lib/features/render_features.dart lib/hotel/look.dart && git commit -m "feat: shadow and MSAA toggles"`

---

## Wave D (run in parallel; each needs Tasks 9 and 11 merged)

### Task 16: Lamps (dynamic point lights, tap to switch)

**Files:** Replace `lib/features/lamps_feature.dart`.

- [x] **Step 1:** `sed -n 516,560p ~/.pub-cache/hosted/pub.dev/flutter_scene-0.23.0/lib/src/light.dart` (the `PointLight` fields), and check the `PointLightComponent(this.light)` usage.
- [x] **Step 2: Implement.** For each node in `ctx.nodesNamed('lamp_bedside')` + `ctx.nodesNamed('lamp_floor')`:
  - add a child node at `+0.3 y` with `PointLightComponent(PointLight(color: warm 2700K ≈ (1.0, 0.78, 0.55), intensity: 8, range: 6))`;
  - register an `Interactable(node: lamp, label: 'Lamp on/off', onTap: toggle)`. Toggling flips the light's intensity between 0 and 8 and the shade's emissive colour, which gives bloom something to find.

  The feature toggle off removes all light nodes and unregisters the interactables. That shows the cost of 4 point lights (2 per room).
- [x] **Step 3: Verify.** At 22:00 with the lamps on, there are warm pools of light. Tap one: it goes off. Turn the feature off: the room is lit only by the IBL.
- [x] **Step 4: Commit**: `git add lib/features/lamps_feature.dart && git commit -m "feat: tappable lamps with point lights"`

### Task 17: Connecting door and portal culling

**Files:** Replace `lib/features/door_feature.dart`. Create `lib/math/door_hinge.dart` and `lib/math/portal.dart`. Tests: `test/math/door_hinge_test.dart`, `test/math/portal_test.dart`.

> **Wave C note (final review):** `door_connect` lives in room A's subtree, and room B has a hidden, mirrored copy. Portal culling that hides room A while the player is in room B (door closed) also hides the only visible leaf. Room B then shows a hole in its wall, and the door can't be tapped (hidden nodes aren't pickable) while its collider still blocks the player. Fix it in this task: each tick, show the copy in the camera's room and hide the other one. Drive room B's copy with local angle −θ; mirroring conjugates the rotation, so its world pose matches A's leaf. Register both copies as interactables.

**Interfaces (Produces):**

```dart
// door_hinge.dart
const double kDoorOpenAngle = 100 * degrees2Radians;
double stepHinge(double angle, bool open, double dt, {double speed = 2.5}); // rad/s, clamped
/// Door-leaf collider for the current angle: closed → box on x∈[-0.05,0.05], z∈[2.0,2.9];
/// open (≥ 60°) → empty (leaf swung against Room A wall); between → closed box.
List<Box2> doorColliders(double angle);
// portal.dart
/// Which rooms must be visible.
Set<RoomId> visibleRooms({required RoomId cameraRoom, required bool doorOpen, required bool cullingEnabled});
```

- [x] **Step 1: Failing tests**

```dart
// test/math/portal_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/math/floor_plan.dart';
import 'package:flutter_3d/math/portal.dart';

void main() {
  test('door closed + culling → only your room', () {
    expect(visibleRooms(cameraRoom: RoomId.a, doorOpen: false, cullingEnabled: true), {RoomId.a});
  });
  test('door open → both rooms', () {
    expect(visibleRooms(cameraRoom: RoomId.b, doorOpen: true, cullingEnabled: true), {RoomId.a, RoomId.b});
  });
  test('culling disabled → both rooms always', () {
    expect(visibleRooms(cameraRoom: RoomId.a, doorOpen: false, cullingEnabled: false), {RoomId.a, RoomId.b});
  });
  test('culled room is not pickable', () {
    // The invariant that makes this true: culled rooms are set visible=false
    // and Task 11 raycasts with includeInvisible:false. Pin the first half here.
    final v = visibleRooms(cameraRoom: RoomId.a, doorOpen: false, cullingEnabled: true);
    expect(v.contains(RoomId.b), false);
  });
}
```

```dart
// test/math/door_hinge_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/math/door_hinge.dart';

void main() {
  test('opens to kDoorOpenAngle and stops', () {
    var a = 0.0;
    for (var i = 0; i < 300; i++) { a = stepHinge(a, true, 1 / 60); }
    expect(a, kDoorOpenAngle);
  });
  test('closes to 0 and stops', () {
    var a = kDoorOpenAngle;
    for (var i = 0; i < 300; i++) { a = stepHinge(a, false, 1 / 60); }
    expect(a, 0);
  });
  test('collider present while closed or closing, absent once open', () {
    expect(doorColliders(0), isNotEmpty);
    expect(doorColliders(30 * 3.14159 / 180), isNotEmpty);
    expect(doorColliders(kDoorOpenAngle), isEmpty);
  });
}
```

- [x] **Step 2:** Run `fvm flutter test test/math/door_hinge_test.dart test/math/portal_test.dart`. Expected: FAIL.
- [x] **Step 3: Implement the maths** (straightforward from the interfaces), then run the tests. Expected: PASS.
- [x] **Step 4: Implement the features.**
  - `DoorFeature` (non-toggleable): registers an interactable on `ctx.nodesNamed('door_connect').first` with the label "Open door" or "Close door", which flips `ctx.doorOpen`. `tick` does the following:
    - steps the hinge;
    - sets the door node's rotation about Y, at the hinge;
    - writes `ctx.dynamicColliders['door'] = doorColliders(angle)`;
    - after the player's collision, pushes the player out of a closing door. This happens naturally because `moveCircle` pushes out (Task 3 test).
  - `PortalCullingFeature` (toggleable, default on): `tick` computes `visibleRooms(...)` with `cameraRoom = FloorPlan.roomOf(ctx.playerXZ)` and sets `ctx.rooms[id]!.visible` for each room. `unmount` sets both rooms visible.
- [x] **Step 5: Verify.**
  - The door closed blocks walking.
  - Tap it: it swings open (about 0.6 s), and you walk through.
  - With culling on and the door closed, the HUD triangle and mesh counts halve compared with culling off.
  - Stand in the doorway while the door closes: you get pushed out, not stuck.
- [x] **Step 6: Commit**: `git add lib/features/door_feature.dart lib/math/door_hinge.dart lib/math/portal.dart test/math/door_hinge_test.dart test/math/portal_test.dart && git commit -m "feat: connecting door with hinge collider and portal culling"`

### Task 18: Curtains

**Files:** Replace `lib/features/curtains_feature.dart`.

- [x] **Step 1: Implement.** For each room, register an interactable on both `curtain_left` and `curtain_right`, labelled "Open curtains" or "Close curtains". A tap toggles that room's curtains. `tick` eases each panel's x-scale between 0.25 (bunched at the side, open) and 1.0 (closed), anchoring at the outer edge by also moving its x-position. Use `approach()` from Task 7 with a fade of 0.8 s.
- [x] **Step 2: Verify.** At 15:00, close the curtains: the room darkens noticeably, since direct sun and sky are blocked (with shadows on). Open them again.
- [x] **Step 3: Commit**: `git add lib/features/curtains_feature.dart && git commit -m "feat: tappable curtains"`

### Task 19: Faucet and shower particles

**Files:** Replace `lib/features/water_fx_feature.dart`.

- [x] **Step 1:** Read the particle section of `.claude/skills/flutter_scene-idioms/SKILL.md`. Check `ParticleSystem({maxParticles, shape, spawner, modules, lifetime, startSpeed, startSize, startColor, gravity, ...})` (verified in `particles/particle_system.dart:48`), `Spawner({rate, bursts})` (with `rate` mutable), the emitter shapes in `particles/emitter_shape.dart`, and how a system is attached (`particle_emitter_component.dart`).
- [x] **Step 2: Implement.** Per room:
  - **Faucet**: a cone emitter at `faucet_spout`, pointing −Y. 180/s, lifetime 0.35 s, speed 0.6, size 0.012, gravity −9.8, alpha 0.6 light blue, `velocityStretched`. Add a tiny splash burst at the basin, y = 0.85.
  - **Shower**: a disk emitter of radius 0.12 at `shower_head`. 600/s, lifetime 0.6 s, speed 1.0.
  - **Steam** while the shower is on: 12/s large soft puffs rising at 0.15 m/s, lifetime 4 s, alpha 0.12. Give the sprites a soft-dot texture (a radial gradient from `Texture2D.fromPixels`); without one a sprite is a hard square.
  - Register interactables: `faucet_spout` "Water on/off" and `shower_head` "Shower on/off". They set `Spawner.rate` between 0 and the value above.
  - The feature toggle off unmounts every system and unregisters the interactables.
- [x] **Step 3: Verify.** Tap the faucet: a stream falls into the basin. Tap the shower: rain plus steam. Watch the HUD UI ms rise, since particles are CPU-stepped.
- [x] **Step 4: Commit**: `git add lib/features/water_fx_feature.dart && git commit -m "feat: faucet and shower particles with steam"`

### Task 20: Rain outside (and the weather level)

**Files:** Replace `lib/features/rain_feature.dart`.

> **Wave C note (final review):** `ctx.look.exposure` belongs to the sky feature (Task 12). It sets exposure from the time of day on every slider change and restores its own base on unmount. So don't multiply or restore `look.exposure` here. Dragging the slider would wipe out the rain darkening, and restoring a stored base leaves the wrong exposure once the time has changed. Instead, add `double exposureScale = 1.0` to `LookState` (this task's one allowed `look.dart` edit). Set it to `1 - 0.35 * weather` and reset it to 1 on unmount. Make `composeLook` use `exposure * exposureScale`, including the bloom threshold `1 / (exposure * exposureScale)`.
**Consumes:** `approach()` (Task 7), `ctx.rainRequested`, `ctx.weather`.

- [x] **Step 1: Implement.**
  - The feature owns the weather: `tick` does `ctx.weather = approach(ctx.weather, ctx.rainRequested.value ? 1 : 0, dt)`.
  - Rain particles: a box emitter 30 × 30 m at x ∈ [−15, 15], z ∈ [6.5, 36.5], 15 m above the balcony, **outside only**, so none fall inside the room. Speed 11 m/s, width 0.014–0.024, `velocityStretched`, alpha 0.55, and `spawner.rate = 1500 * ctx.weather`.
  - Tint by daylight: rain colour × `clamp(sunIntensity, 0.15, 1)`, so it doesn't glow white at night.
  - While raining, adjust the look and call `applyLook()` only when the value changes by more than 0.02:
    - `ctx.look.fogDensity = lerp(0.004, 0.016, weather)`;
    - `ctx.look.exposure *= (1 - 0.35 * weather)`. Store the base value in `mount` and restore it in `unmount`.
  - Balcony splashes: a burst module at y = 0 for the balcony floor, at 10% of the rain rate (playbook: fewer ground splashes).
  - Off: set the rate to 0. Unmount once no particles remain (`ParticleSystem` alive count, or after 3 s).
- [x] **Step 2: Verify.** Tap 🌧: rain fades in over about 2.5 s, visible past the window and on the balcony, never indoors. Fog thickens over the sea. Tap ☀️: it fades out.
- [x] **Step 3: Commit**: `git add lib/features/rain_feature.dart && git commit -m "feat: rain outside with weather fade"`

### Task 21: Rain on the window glass (refraction shader)

**Files:** Create `assets/materials/rain_glass.fmat`. Replace `lib/features/rain_glass_feature.dart`.

- [x] **Step 1:** Read `.claude/skills/flutter_scene-idioms/` for the `.fmat` reference and engine rule 2 above.
- [x] **Step 2: Write the shader.**

```glsl
material {
  name: rain_glass,
  shading: lit,
  blending: alpha,
  depth_write: false,
  engine_inputs: [scene_color],
  parameters: [
    { type: float, name: time },
    { type: float, name: wetness }
  ]
}

fragment {
  float Hash12(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
  }

  // One layer of sliding drops: returns xy = refraction offset, z = drop mask.
  vec3 DropLayer(vec2 uv, float t, float scale) {
    vec2 grid = vec2(6.0, 2.0) * scale;
    vec2 st = uv * grid;
    float col = floor(st.x);
    float speed = 0.2 + Hash12(vec2(col, scale)) * 0.3;
    st.y += t * speed;
    vec2 id = floor(st);
    vec2 f = fract(st) - 0.5;
    float h = Hash12(id + scale);
    vec2 c = vec2((h - 0.5) * 0.6, (fract(h * 7.0) - 0.5) * 0.6);
    vec2 d = (f - c) * vec2(1.0, 2.0);
    float r = length(d);
    float mask = 1.0 - smoothstep(0.08, 0.14, r);
    return vec3(d * mask * 0.5, mask);
  }

  void Surface(inout MaterialInputs material) {
    vec2 uv = GetUV0();
    float t = material.time;
    vec3 a = DropLayer(uv, t, 1.0);
    vec3 b = DropLayer(uv + 0.37, t, 2.3);
    vec2 offset = (a.xy + b.xy * 0.6) * 0.03 * material.wetness;
    float m = max(a.z, b.z) * material.wetness;
    material.base_color = vec4(0.0, 0.0, 0.0, 0.0);
    material.emissive = GetSceneColor(offset) * mix(1.0, 0.85, m);
    material.specular = 0.0;
    material.roughness = 0.05;
    // Fully opaque where we composite the refracted scene; the glass itself is invisible otherwise.
    material.base_color.a = 1.0;
  }
}
```

Check the `MaterialInputs` field names (`base_color`, `emissive`, `specular`, `roughness`) and how parameters are accessed (`material.time`, or bare `time`) against the idioms reference before building. The playbook table says `base_color` has straight alpha and `emissive` is added after lighting.

- [x] **Step 3: Build.** Run `fvm flutter run --enable-flutter-gpu …` (a full rebuild; hot restart won't pick up `.fmat` files). Then run `grep -n "keeping the previous shaders" run.log`. Expected: no match. Check `flutter_scene_generated/material.*.index.json` for `rain_glass`.
- [x] **Step 4: Implement the feature.** Load it with `loadFmatMaterial('assets/materials/rain_glass.fmat')`. On mount, swap the material of both `window_glass` nodes, keeping the old material to restore on unmount. `tick` sets `time += dt` and `wetness = ctx.weather` through `material.parameters.setFloat(...)` (check the exact API in the idioms skill).
- [x] **Step 5: Verify on the iOS simulator AND the Android emulator.** With rain on, the window shows drops refracting the view outside. With rain off, the glass is clear. On the emulator: no black or transparent glass.
- [x] **Step 6: Commit**: `git add assets/materials/rain_glass.fmat lib/features/rain_glass_feature.dart && git commit -m "feat: rain-on-glass refraction shader"`

### Task 22: Lightning over the sea

**Files:** Replace `lib/features/lightning_feature.dart`.
**Consumes:** `LightningScheduler` (Task 7), `ctx.weather`.

- [x] **Step 1: Implement.**
  - Strikes only when `ctx.weather > 0.7`.
  - A strike builds a bolt by midpoint displacement: 6 passes, kick 0.26 × segment length, from (x, 300, z) to the sea (y = −90), with x in [−80, 80] and z in [120, 220], in front of the window.
  - The bolt geometry is `TubeGeometry(PolylinePath(points), radius: 0.4, radialSegments: 5, caps: false)` with an HDR `UnlitMaterial` (colour × 12). Grep `TubeGeometry` and `PolylinePath` in `lib/src/geometry` first.
  - **Hide the node between pulses**, rather than dimming it.
  - Flash light: a shadowless `DirectionalLight` from the bolt, intensity = `envelope × 4 × darkness`. Add a room-light boost as `ctx.look.environmentIntensity += envelope * 0.8 * darkness`, restored after the strike. Here `darkness` = 0.3 by day and 1.0 at night.
  - Don't rebake the IBL during a flash.
  - A debug hold: `const bool kHoldLightning = bool.fromEnvironment('HOLD_LIGHTNING')`. When set, freeze the envelope at its peak for 2 s. Log `debugPrint('lightning strike')`.
- [x] **Step 2: Verify.** Run with `--dart-define=HOLD_LIGHTNING=true` and rain on. When `lightning strike` appears in the log, take a screenshot. Expected: a bolt over the sea and a lit room.
- [x] **Step 3: Commit**: `git add lib/features/lightning_feature.dart && git commit -m "feat: lightning strikes during storms"`

### Task 23: Planar reflections (bathroom mirror and sea)

**Files:** Replace `lib/features/reflection_features.dart`.

> **Wave C note:** `sea` is a scene-level node (Task 13). Find it among `ctx.scene.root.children`, because `ctx.nodesNamed` only searches the two rooms.

- [x] **Step 1:** Read the `PlanarReflectorComponent({resolutionScale, layerMask, reflectionGroupId, clipBias, localNormal})` docs (`components/planar_reflector_component.dart`), including how a material samples `planar_reflection`. Check whether the default PBR material uses the capture automatically or needs an `.fmat` with `engine_inputs: [planar_reflection]`.
- [x] **Step 2: Implement.**
  - `MirrorFeature`: add `PlanarReflectorComponent(resolutionScale: 0.5, localNormal: Vector3(1, 0, 0))` to each `mirror` node. If a custom material is needed, the fmat is `mirror.fmat`: unlit, `emissive = GetPlanarReflection().rgb`, `specular = 0`. In that case, **add `assets/materials/mirror.fmat` to this task's files**. Unmount removes the component and restores the material.
  - `SeaReflectionFeature`: the same on the node named `sea` (Task 13) with `localNormal` +Y and resolution 0.5. Its `layerMask` excludes the sea's own layer (playbook §7 "free win"): put the sea on layer bit 2 and use `layerMask = 0xFFFFFFFF & ~(1 << 2)`.
  - Room B's mirror sits under a negative-scale parent, so its world normal flips automatically. Verify it.
- [x] **Step 3: Verify.** In the bathroom, the mirror shows the room and **you**. There's no player body, so it shows the room behind you. Check both rooms' mirrors are the right way round. Check that turning on the mirror raises raster ms noticeably in the HUD.
- [x] **Step 4: Commit**: `git add lib/features/reflection_features.dart assets/materials/ && git commit -m "feat: planar reflections for bathroom mirror and sea"`

### Task 24: TV and PC WebViews on the 3D screens

**Files:** Replace `lib/features/screens_feature.dart`. Create `lib/ui/screen_overlay.dart`.

> **Wave C note:** room B's screen quads are built with u flipped (commit `d63cf81`), so a texture reads left to right from the front in both rooms. Bind the same poster to both.
**Consumes:** `webview_flutter` `WebViewController` / `WebViewWidget`.

URLs (constants at the top of the file; **the user will confirm them**):

```dart
const kTvUrl = 'https://www.youtube.com/@GoogleDevelopers';       // TODO(user): replace with the real channel
const kPcUrl = 'https://www.facebook.com/GoogleDevelopersThailand'; // TODO(user): replace with the real page
```

These two constants are the only placeholders in the plan, and they are user data, not code. Ask the user for the URLs before the task is marked done.

Design (engine rule 7): a WebView is a platform view and can't become a mesh texture in 0.23.0. So:

1. **In the scene:** the screen mesh shows a still image while not focused: a black screen with a "▶ Tap to watch" label. Render the label with `WidgetComponent.bindOnly(child: _PosterCard(...), size: Size(640, 360), update: WidgetUpdatePolicy.manual, bind: (tex) => screenMaterial.baseColorTexture = …)`. Check the material texture slot name in the idioms skill.
2. **On tap (interactable "Watch TV" / "Open PC"):** the camera eases over 0.6 s to a pose 0.9 m in front of the screen centre, facing it (lerp position and target). Set `PlayerFeature` input to ignored while focused, using a `static bool focusLocked`. **This is an allowed read/write from this task of a static on `PlayerFeature`, declared by Task 10.** If Task 10 didn't declare it, add `static bool focusLocked = false;` and an early `return` in its `tick`; list `player_feature.dart` in the commit.
3. **Overlay:** once the ease finishes, project the screen quad's 4 world corners to screen space with the same maths as `screenRay`, inverted. Put that in `screen_overlay.dart` as `Offset? projectToScreen(Vector3 p, camera, Size viewport)`, returning null when the point is behind the camera. Show a `Positioned` `WebViewWidget` over the axis-aligned bounding rect of those corners, with a close ✕ button. Because the camera faces the screen head-on, the rect matches the quad, so it really does look like the page is on the TV.
4. **Close:** remove the WebView and ease the camera back to the player's pose.

**Stretch goal (only after the above works):** keep the WebView attached while walking by applying a `Matrix4` perspective `Transform` from the 4 projected corners. Test it on a real iPhone; if platform-view transforms glitch, leave it out and say so in the talk.

- [x] **Step 1:** Write `projectToScreen` plus a unit test in `test/ui/screen_overlay_test.dart`: the target point projects to the viewport centre, and a point behind the camera returns null.

```dart
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/ui/screen_overlay.dart';

void main() {
  test('target projects to the centre; behind camera is null', () {
    final eye = Vector3(0, 1.6, 0), target = Vector3(0, 1.6, 5);
    const vp = Size(400, 800);
    final c = projectToScreen(target, eye: eye, target: target, fovY: 60 * degrees2Radians, viewport: vp);
    expect(c!.dx, closeTo(200, 1e-6));
    expect(c.dy, closeTo(400, 1e-6));
    expect(projectToScreen(Vector3(0, 1.6, -1), eye: eye, target: target, fovY: 1.0, viewport: vp), isNull);
  });
}
```

Run it, check it fails, implement it (the inverse of Task 5: project onto camera right/up/forward, divide by forward depth times tan(fov/2)), and run it again to check it passes.
- [x] **Step 2:** Implement the feature and overlay as described. `overlay(ctx)` returns a `ValueListenableBuilder` on a static `ValueNotifier<_Focus?>`.
- [x] **Step 3: Verify on the iOS simulator and the Android emulator.** Tap the TV: the camera glides in, and YouTube loads and plays with audio. ✕ glides back. Same for the PC with Facebook. The HUD shows the platform-view composite cost.
- [x] **Step 4: Commit**: `git add lib/features/screens_feature.dart lib/ui/screen_overlay.dart test/ui/screen_overlay_test.dart && git commit -m "feat: TV and PC WebViews aligned to 3D screens"`

### Task 25: Pokémon books (API → 3D pages, page curl)

**Files:** Replace `lib/features/books_feature.dart`. Create `lib/features/book_page.dart` and `assets/materials/page_curl.fmat`.
**Consumes:** `PokeApiClient`, `kBookPokemon`, `PokemonLoaded` / `PokemonLoadFailure` (Task 6); `WidgetComponent` (engine rule 7).

- [x] **Step 1: `book_page.dart`**: `class BookPage extends StatelessWidget` taking a `PokemonResult?`:
  - `null`: shows "Loading…".
  - `PokemonLoadFailure`: shows "Couldn't load — tap to retry" (the whole page is a `GestureDetector`; `onRetry` callback).
  - `PokemonLoaded`: shows `Image.network(artworkUrl)` (with `errorBuilder` to a Pokéball icon), `#025 Pikachu`, type chips, 6 stat bars (`LinearProgressIndicator(value: stat / 255)`) and height/weight, on a cream paper background, fixed at 512 × 700 logical px.
- [x] **Step 2: Interaction.** Register each `book_N` node as "Read book". On tap:
  - Hide the shelf book and spawn an open-book node 0.45 m in front of the camera, facing it. The open book is two quads (left and right page) on a thin cover box.
  - The left page is a `WidgetComponent(child: BookPage(result), size: Size(512, 700), pixelRatio: 2, update: WidgetUpdatePolicy.everyFrame while loading, then manual, input: WidgetInput.automatic)`.
  - The right page shows the next Pokémon in `kBookPokemon`, so the book is a Pokédex.
  - Swipe left or right on the look pad while a book is open to turn the page. A tap outside the book closes it.
  - Fetch with `PokeApiClient.fetch(id)`; rebuild the widget on result, then call `controller.requestCapture()`.
- [x] **Step 3: Page-curl shader** (`page_curl.fmat`). The turning page is a subdivided quad (24 × 1 segments) with a vertex block. Pages bend around a cylinder of radius 0.05 m whose axis sweeps across the page as `progress` goes 0 → 1.

```glsl
material {
  name: page_curl,
  shading: unlit,
  blending: opaque,
  culling: none,
  parameters: [
    { type: float, name: progress },
    { type: float, name: page_width },
    { type: sampler2d, name: page_tex }
  ]
}

vertex {
  void Vertex(inout VertexInputs vertex) {
    float x = vertex.position.x;                    // 0..page_width from the spine
    float axis = mix(page_width, -page_width * 0.2, progress);
    float r = 0.05;
    vec3 p = vertex.position;
    if (x > axis) {
      float arc = x - axis;
      float theta = min(arc / r, 3.14159265);
      float flat = max(arc - 3.14159265 * r, 0.0);
      p.x = axis + r * sin(theta) - flat;
      p.z = vertex.position.z + r * (1.0 - cos(theta));
    }
    vertex.world_position = (GetModelTransform() * vec4(p, 1.0)).xyz;
  }
}

fragment {
  void Surface(inout MaterialInputs material) {
    material.base_color = vec4(SRGBToLinear(texture(page_tex, GetUV0()).rgb), 1.0);
  }
}
```

**Before building, check** how the vertex stage gets the model transform: `vertex.world_position` may already be in world space, with object space in `vertex.position`. Check the vertex-stage reference in the idioms skill and replace `GetModelTransform()` with the real accessor. If the page texture has to come from a `WidgetComponent`, use its `bind:` callback to call `material.parameters.setTexture('page_tex', tex, …)`.

Build and grep for `keeping the previous shaders` (expect none). Test on the Android emulator (GLES).
- [x] **Step 4: Verify.**
  - Tap a book: it opens with Bulbasaur's real data and artwork.
  - Swipe: the page curls over and Charmander appears.
  - Turn Wi-Fi off in the simulator (network link conditioner, or airplane mode on a device) and open a new book: "Couldn't load — tap to retry". Wi-Fi back on, tap: it loads.
- [x] **Step 5: Commit**: `git add lib/features/books_feature.dart lib/features/book_page.dart assets/materials/page_curl.fmat && git commit -m "feat: Pokédex books — PokéAPI data on WidgetComponent pages with page-curl shader"`

### Task 26: Instanced beach props

**Files:** Replace `lib/features/instancing_feature.dart`.

- [x] **Step 1:** Grep `InstancedMesh` and `InstancedMeshComponent` in `lib/src/instanced_mesh.dart` and `components/instanced_mesh_component.dart` for the API.
- [x] **Step 2: Implement.** On the beach (y = −90, z ∈ [5, 35], x ∈ [−120, 120]), place 400 palm trees (a cylinder trunk plus a cone of leaves) and 300 umbrellas (a cone on a pole) on a jittered grid seeded with `Random(7)`. Draw them as **2 instanced meshes** (one per prop type).

  For the talk comparison, add `const bool kNaiveProps = bool.fromEnvironment('NAIVE_PROPS')`. When it's true, build the same 700 props as individual nodes instead. The HUD mesh count and UI ms show the difference.
- [x] **Step 3: Verify.** From the balcony, the beach is dotted with palms and umbrellas. Profile both modes on a device and note the UI ms in the commit message body.
- [x] **Step 4: Commit**: `git add lib/features/instancing_feature.dart && git commit -m "feat: instanced palms and umbrellas on the beach"`

---

### Task 29: Entrance "Book now" → Flutter booking page (3D → app)

When the player walks back to the room's entrance door, a Flutter **Book now** button slides up. Tapping it pushes a normal Flutter route with the booking details and price. The 3D scene pauses while the route covers it and resumes on return. This is the "3D drives the app" moment of the talk.

**Files:**
- Create: `lib/math/entrance_zone.dart`, `lib/data/booking.dart`, `lib/ui/booking_page.dart`
- Replace: `lib/features/entrance_feature.dart` (stub from Task 2)
- Modify: `lib/ui/hotel_page.dart` (wrap the `SceneView` in `TickerMode`; this is the only edit to that file)
- Test: `test/math/entrance_zone_test.dart`, `test/data/booking_test.dart`

**Interfaces:**
- Consumes: `ctx.playerXZ`, `ctx.playerYaw` (Task 10); `FloorPlan.roomOf` (Task 3); `approach()` (Task 7) for the button slide.
- Produces:

```dart
// entrance_zone.dart
/// Entrance door centres (room A authored, room B mirrored).
const double kEntranceX = -1.8, kEntranceZ = 0.0;
/// Hysteresis: enter within 1.2 m, leave beyond 1.5 m.
class EntranceZone {
  bool inside = false;
  /// Updates and returns [inside] for a player at [xz].
  bool update(Vector2 xz);
}
// booking.dart
enum RoomOption { familyRoom, familySuiteConnected }  // one room, or both via the connecting door
class BookingQuote {
  BookingQuote({required this.option, required this.checkIn, required this.nights,
      required this.adults, required this.children});
  final RoomOption option; final DateTime checkIn; final int nights, adults, children;
  int get nightlyRateThb;   // familyRoom 5,900; familySuiteConnected 10,900
  int get subtotalThb;      // nightlyRate × nights
  int get serviceChargeThb; // 10% of subtotal, rounded
  int get vatThb;           // 7% of (subtotal + service), rounded
  int get totalThb;
  DateTime get checkOut;
  BookingQuote copyWith({RoomOption? option, DateTime? checkIn, int? nights, int? adults, int? children});
}
String formatThb(int v); // "฿10,900"
```

The prices are demo values. Put them at the top of `booking.dart` as named constants so the user can change them.

- [x] **Step 1: Failing tests**

```dart
// test/math/entrance_zone_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/math/entrance_zone.dart';

void main() {
  test('enters near room A entrance', () {
    final z = EntranceZone();
    expect(z.update(Vector2(-1.8, 0.8)), true);
  });
  test('enters near room B entrance (mirrored)', () {
    expect(EntranceZone().update(Vector2(1.8, 0.8)), true);
  });
  test('far away is outside', () {
    expect(EntranceZone().update(Vector2(-4, 5)), false);
  });
  test('hysteresis: no flicker at the boundary', () {
    final z = EntranceZone();
    z.update(Vector2(-1.8, 1.0));                 // inside (1.0 < 1.2)
    expect(z.update(Vector2(-1.8, 1.35)), true);  // between 1.2 and 1.5 → stays inside
    expect(z.update(Vector2(-1.8, 1.6)), false);  // beyond 1.5 → leaves
    expect(z.update(Vector2(-1.8, 1.35)), false); // between → stays outside
  });
}
```

```dart
// test/data/booking_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/data/booking.dart';

void main() {
  final q = BookingQuote(option: RoomOption.familySuiteConnected,
      checkIn: DateTime(2026, 12, 24), nights: 3, adults: 2, children: 2);

  test('price breakdown', () {
    expect(q.subtotalThb, 32700);
    expect(q.serviceChargeThb, 3270);
    expect(q.vatThb, 2518);          // round(0.07 × 35,970) = 2,517.9 → 2,518
    expect(q.totalThb, 38488);
  });
  test('check-out crosses the year', () {
    expect(q.checkOut, DateTime(2026, 12, 27));
    expect(q.copyWith(nights: 9).checkOut, DateTime(2027, 1, 2));
  });
  test('switching option changes the rate', () {
    expect(q.copyWith(option: RoomOption.familyRoom).nightlyRateThb, 5900);
  });
  test('formatThb groups thousands', () {
    expect(formatThb(38488), '฿38,488');
    expect(formatThb(900), '฿900');
  });
}
```

- [x] **Step 2:** Run `fvm flutter test test/math/entrance_zone_test.dart test/data/booking_test.dart`. Expected: FAIL.

- [x] **Step 3: Implement the maths and the model.**
  - `EntranceZone.update`: distance to the nearer of (kEntranceX, kEntranceZ) and (−kEntranceX, kEntranceZ). If not inside, enter when `d < 1.2`; if inside, leave when `d > 1.5`.
  - `BookingQuote`: straightforward from the interface. Use `.round()` for service and VAT. `checkOut` is `DateTime(checkIn.year, checkIn.month, checkIn.day + nights)`, which avoids DST drift.
  - `formatThb`: insert commas every 3 digits from the right.

  Run the tests. Expected: PASS.

- [x] **Step 4: `booking_page.dart`.** A normal `Scaffold` route, `BookingPage({required BookingQuote initial})`:
  - A header image: a screenshot of the current 3D view. Before pushing, capture a still with `RenderRepaintBoundary.toImage` around the `SceneView`, and pass it as `ui.Image?`. Fall back to a gradient if it's null.
  - A `SegmentedButton<RoomOption>`: "Family Room" / "Family Suite (2 connected rooms)". The initial selection is **Suite if the connecting door was open (`ctx.doorOpen.value`) when the player reached the entrance**, and Room otherwise. That's the second piece of 3D state flowing into the app.
  - A check-in date row (`showDatePicker`, from today up to +365 days), a nights stepper (1–30), adults (1–4) and children (0–4) steppers.
  - The price breakdown: `nightly × nights`, service 10%, VAT 7%, and the **total** in bold, all via `formatThb`.
  - A "Confirm booking" `FilledButton` that shows a `SnackBar("Demo only — no booking made")` and pops back to the scene.

- [x] **Step 5: `EntranceFeature`** (non-toggleable, id `entrance`):
  - `static final ValueNotifier<bool> showBookNow = ValueNotifier(false);`
  - `tick`: `showBookNow.value = _zone.update(ctx.playerXZ)`.
  - `static Widget overlay(HotelContext ctx)`: a `ValueListenableBuilder` that animates (`AnimatedSlide` + `AnimatedOpacity`, 250 ms) a bottom-centre `FilledButton.icon(icon: Icon(Icons.hotel), label: Text('Book now'))`, placed above the time slider.
  - The press handler is `onBookNow(BuildContext context, HotelContext ctx)`. It builds the initial `BookingQuote` (check-in = tomorrow, 2 nights, 2 adults, 2 children, option from `ctx.doorOpen`) and calls `Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookingPage(initial: quote, preview: image)))`.
  - When the route pops, move the player 0.6 m back into the room (so the button doesn't reappear straight away) by setting `ctx.playerXZ.y += 0.6`.

- [x] **Step 6: Pause the scene under the route** (engine rule 5). In `hotel_page.dart`, wrap the `SceneView` in `TickerMode(enabled: ModalRoute.of(context)?.isCurrent ?? true, child: …)`. The scene then stops rendering while the booking page covers it: no hidden GPU cost, and the frame chart proves it.

- [x] **Step 7: Verify on the simulator.**
  - Walk to the entrance: **Book now** slides up; walk away and it hides.
  - Tap it: the booking page shows the price, and changing nights or the option updates the total.
  - With the connecting door opened beforehand, the page pre-selects "Family Suite".
  - Back: the scene resumes, and the HUD shows ~0 ms while the page was open. Check `run.log` for no errors.

- [x] **Step 8: Commit**

```bash
git add lib/math/entrance_zone.dart lib/data/booking.dart lib/ui/booking_page.dart lib/features/entrance_feature.dart lib/ui/hotel_page.dart test/math/entrance_zone_test.dart test/data/booking_test.dart learning.md
git commit -m "feat: entrance Book now → booking page with price, scene paused under route"
```

---

## Wave E

### Task 27: Debug tour and screenshot capture

**Files:** Create `lib/hotel/debug_tour.dart` and `tool/capture_tour.sh`. Modify `lib/hotel/hotel_scene.dart` (one call in `start()`).

- [ ] **Step 1: Implement.** `debug_tour.dart` reads `bool.fromEnvironment('HOTEL_TOUR')` and `String.fromEnvironment('HOTEL_PRESET')`. When the tour is on (debug builds only; assert `kDebugMode`), it steps through fixed stops every 8 s, setting `ctx.playerXZ`, `playerYaw` and `timeOfDay`, and toggling rain. At each stop it logs `hotel tour: <stop name>`. Stops:
  1. room A window, 15:00
  2. room A window, 19:00
  3. balcony looking down, 12:00
  4. bathroom mirror, 21:00
  5. through the open door into room B, 15:00
  6. window in rain, 17:00
  7. TV, 22:00
  8. entrance with Book now showing, 15:00

  If `HOTEL_PRESET` names a preset, apply it after load.
- [ ] **Step 2: Capture script** (`tool/capture_tour.sh`), from playbook §6:

```zsh
#!/bin/zsh
# Usage: tool/capture_tour.sh <out_dir>
set -e
out=${1:-/tmp/hotel_tour}; mkdir -p $out
fvm flutter run --enable-flutter-gpu -d "iPhone 17 Pro" \
  --dart-define=HOTEL_TOUR=true --dart-define=HOTEL_PRESET=${PRESET:-high} \
  --pid-file /tmp/hotel.pid > $out/run.log 2>&1 &
until grep -q "hotel tour" $out/run.log 2>/dev/null; do sleep 1; done
seen=0
for i in 1 2 3 4 5 6 7 8; do
  until [ $(grep -c "hotel tour" $out/run.log) -gt $seen ]; do sleep 0.5; done
  seen=$(grep -c "hotel tour" $out/run.log)
  name=$(grep "hotel tour" $out/run.log | tail -1 | sed 's/.*hotel tour: //; s/ /_/g')
  sleep 5
  xcrun simctl io booted screenshot "$out/$i-$name.png"
done
kill $(cat /tmp/hotel.pid)
```

- [ ] **Step 3: Verify.** Run `chmod +x tool/capture_tour.sh && tool/capture_tour.sh /tmp/hotel_tour`. Expected: 8 PNGs. Read each one and check that none is all-black or all-white.
- [ ] **Step 4: Commit**: `git add lib/hotel/debug_tour.dart lib/hotel/hotel_scene.dart tool/capture_tour.sh && git commit -m "chore: debug tour and screenshot capture script"`

### Task 28: Real hotel `.glb` import (BLOCKED until the user supplies the asset)

**Files:** Create `lib/features/glb_rooms.dart`. Modify `lib/features/rooms_feature.dart` (choose the GLB when `assets/models/room.glb` exists; keep the placeholder as fallback).

- [ ] **Step 1: Screen the asset** (playbook §1):
  - It is a `.glb` with embedded textures; not a `.gltf` with `uri:` sidecars.
  - No duplicate node names.
  - Every node is reachable from the scene.
  - It's in metres, laid out in Room A local space (x ∈ [−8, 0], origin on the shared wall at floor level). Otherwise, wrap it in a correcting transform.
  - Its node names match the *Node-name contract*. List the mismatches for the user; don't rename silently.
  - `metallic = 0` on non-metal props, and no `KHR_materials_unlit`.
- [ ] **Step 2:** `buildRoomA()` in `glb_rooms.dart` returns `await Node.fromGlbAsset('assets/models/room.glb')` (verified in `node.dart:1112`). `RoomsFeature` uses it in place of the placeholder. Set `castsShadows` on every mesh node (not inherited).
- [ ] **Step 3:** Update `FloorPlan.furnitureA` and the walls to the model's real footprint. Run `fvm flutter test test/math/` to check the symmetry and walk-through tests still pass.
- [ ] **Step 4:** Run Task 27's tour and compare the screenshots.
- [ ] **Step 5: Commit**: `git add assets/models lib/features/glb_rooms.dart lib/features/rooms_feature.dart lib/math/floor_plan.dart && git commit -m "feat: real hotel room model"`
