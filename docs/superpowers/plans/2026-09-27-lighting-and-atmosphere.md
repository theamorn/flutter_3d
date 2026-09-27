# Lighting and Atmosphere Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add eight lighting and atmosphere features to the hotel scene: baked light probes, dynamic GI, auto exposure, cached static shadows, FXAA/SMAA/TAA, reading spot lights, area lights and volumetric fog. Each gets its own switch on the Effects sheet.

**Architecture:** Every technique is a `HotelFeature` (`lib/hotel/feature.dart`) listed in `buildCatalog()`.
- **Settings-only effects** are `LookState` flags that `composeLook` turns into engine settings.
- **Node-based effects** add and remove their own nodes and components.
- **The shared foundation** (Wave A) adds:
  - exclusive toggle groups;
  - a settle timer;
  - a lighting-revision counter;
  - an occlusion hold;
  - the look flags;
  - a skeleton class for every feature.

After that, each Wave B task owns separate files, so Wave B can run in parallel.

**Tech Stack:** Flutter 3.47.2 via `fvm`, flutter_scene 0.23.0 (Flutter GPU), vector_math, flutter_test.

**Spec:** `docs/superpowers/specs/2026-09-27-lighting-and-atmosphere-design.md`. Read it before your task.

---

## How to split this across agents

| Wave | Tasks | Who | Starts when |
|---|---|---|---|
| A (foundation) | 0 → 1 → 2 → 3 → 4, in order | one agent | now |
| B (features) | 5, 6, 7, 8, 11, 12 in parallel; 9 then 10 | one agent per task (9 and 10 can be the same agent) | Wave A is merged to `main` |
| C (verification) | 13 | one agent | all of Wave B is merged |

Each Wave B agent branches from `main` after Wave A, for example with `git worktree add ../hotel-task-5 -b task-5`. It commits only the files listed for its task and merges back. Two Wave B tasks never touch the same file:

| Task | Owns (the only files it may change) |
|---|---|
| 5 Auto exposure | `lib/features/auto_exposure_feature.dart`, `test/features/auto_exposure_feature_test.dart` |
| 6 Static shadows | `lib/features/static_shadows_feature.dart`, `test/features/static_shadows_test.dart` |
| 7 Volumetric fog | `lib/features/volumetric_fog_feature.dart`, `test/features/volumetric_fog_test.dart` |
| 8 Area lights | `lib/features/area_lights_feature.dart`, `test/features/area_lights_test.dart` |
| 9 Reading-light fixtures | `lib/features/placeholder_rooms.dart`, `test/features/reading_lights_test.dart` |
| 10 Spot lights | `lib/features/spot_lights_feature.dart`, `test/features/spot_lights_test.dart` |
| 11 Light probes | `lib/features/light_probes_feature.dart`, `lib/math/light_probes.dart`, `test/math/light_probes_test.dart` |
| 12 Dynamic GI | `lib/features/dynamic_gi_feature.dart`, `test/features/dynamic_gi_test.dart` |

Wave B agents do not edit `learning.md`. Put anything non-obvious you found in your final report; Task 13 folds it in.

## Global Constraints

- Run tools through fvm: `fvm flutter test`, `fvm flutter analyze lib test`, `fvm flutter run --enable-flutter-gpu`.
- flutter_scene stays at 0.23.0. Add no new dependencies.
- `composeLook` in `lib/hotel/look.dart` stays the only place the look's `EnvironmentSettings` is built. The one documented exception is the light-probes base snapshot in Task 11.
- A feature's `unmount` removes every node, component, light and tap it added, and restores every shared value it changed.
- A feature that owns a tap must be `defaultOn` (learning.md: "A tap owned by a default-off feature silently doesn't exist").
- Unit tests must not construct `Scene`, `Geometry`, `Mesh` or textured materials, because they need the GPU (learning.md). Bare `Node`s, lights and components work in `flutter test`, and so do fake `HotelContext`s (`class _Context extends Fake implements HotelContext`).
- `OcclusionFeature` stays last in `buildCatalog()`.
- Nodes that belong to a room are added under `roomContentsRoot(room)` (Task 3), never directly under `ctx.rooms[id]`. For room B that is the `room` child under the x-mirror, so geometry, lights and probes are mirrored for free, and occlusion culling still finds the room's contents.
- A mesh-less child (a light node) makes its parent's combined bounds null. Occlusion culling then never hides that parent, and the engine treats the subtree as always visible. That's acceptable for small fixtures (the lamps already do it), but hang room-wide nodes (probes, window lights) under `roomContentsRoot`, not under a piece of furniture.
- Before every commit: `fvm flutter analyze lib test` shows no new issues (one known info in `hook/build.dart`), and `fvm flutter test` passes.

## Review Focus

1. **AA presets:** switching presets high → medium → low → high leaves at most one anti-aliasing feature wanted and mounted, the preset's own. (Task 4 test.)
2. **Hold release:** switching Baked light probes off during a re-capture releases the occlusion hold, so culling resumes. (Task 11 `CaptureQueue` test, plus `unmount` calling `_setHold(ctx, false)`.)
3. **Room B aim:** room B's mirrored reading lights and window light aim into room B, not back through the wall. (Task 8 and Task 10 tests.)
4. **Slow weather:** rain building 0.01 per frame still triggers a re-capture once the weather has moved 0.05 in total. (Task 11 `LightingSignature` test.)
5. **Sky remount:** switching the Sky off and on while Baked light probes is on is noticed as a lighting change. (Task 11 `LightingSignature` test.)

---

## Wave A: foundation (one agent, in order)

### Task 0: Commit the work already in the tree

The occlusion-culling work and the soft bedding are finished but uncommitted. Later agents branch from `main`, so this must land first.

**Files:** everything currently shown by `git status`.

- [ ] **Step 1: Check the tree is green**

Run: `fvm flutter analyze lib test && fvm flutter test`
Expected: `No issues found!` (or only the known `hook/build.dart` info) and `All tests passed!`

- [ ] **Step 2: Commit the bedding on its own**

```bash
git add lib/features/placeholder_rooms.dart lib/features/bedding_mesh.dart test/features/bedding_test.dart
git commit -m "feat(rooms): soft cloth bedding (puffed pillows, draped duvet and throw)"
```

- [ ] **Step 3: Commit occlusion culling and the perf probe**

```bash
git add learning.md lib/features/lightning_feature.dart lib/features/ocean_feature.dart \
  lib/features/reflection_features.dart lib/features/sky_feature.dart lib/hotel/debug_tour.dart \
  lib/hotel/feature_catalog.dart lib/hotel/hotel_scene.dart lib/hotel/presets.dart lib/ui/hud.dart \
  lib/features/occlusion_feature.dart lib/hotel/perf_probe.dart lib/math/occlusion.dart \
  test/math/occlusion_test.dart
git commit -m "perf: camera occlusion culling (cells and portals, per-camera mirrors, sea capture layer) and a profile-mode perf probe"
git status --short   # expected: empty
```

### Task 1: Settle timer, context fields, exclusive toggle groups

**Files:**
- Modify: `lib/math/schedulers.dart` (append `SettleTimer`)
- Modify: `lib/hotel/hotel_context.dart` (two fields)
- Modify: `lib/hotel/feature.dart` (`exclusiveGroup`)
- Modify: `lib/hotel/feature_registry.dart` (`setEnabled`)
- Create: `test/math/settle_timer_test.dart`
- Modify: `test/hotel/feature_registry_test.dart`

**Interfaces:**
- Produces: `class SettleTimer { SettleTimer({double quiet = 0.5}); bool get pending; void markDirty(); bool tick(double dt); }`
- Produces: `HotelContext.lightingRevision` (`ValueNotifier<int>`) and `HotelContext.occlusionHolds` (`int`)
- Produces: `String? get exclusiveGroup` on `HotelFeature` (null by default). `FeatureRegistry.setEnabled(id, true)` switches off the other wanted members of the group.

- [ ] **Step 1: Write the failing settle-timer test** (`test/math/settle_timer_test.dart`)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/math/schedulers.dart';

void main() {
  test('fires once, after the quiet period', () {
    final t = SettleTimer(quiet: 0.5)..markDirty();
    expect(t.pending, isTrue);
    expect(t.tick(0.3), isFalse);
    expect(t.tick(0.3), isTrue);
    expect(t.pending, isFalse);
    expect(t.tick(1.0), isFalse);
  });

  test('never fires while changes keep coming', () {
    final t = SettleTimer(quiet: 0.5);
    for (var i = 0; i < 20; i++) {
      t.markDirty();
      expect(t.tick(0.1), isFalse);
    }
    expect(t.tick(0.5), isTrue);
  });

  test('an idle timer never fires', () {
    expect(SettleTimer().tick(10), isFalse);
  });
}
```

- [ ] **Step 2: Add the failing exclusive-group test** to `test/hotel/feature_registry_test.dart` (it already has `_Fake`)

```dart
class _Grouped extends _Fake {
  _Grouped(String id) : super(id);
  @override
  String? get exclusiveGroup => 'aa';
}
```

and inside `main()`:

```dart
  test('enabling one member of an exclusive group switches the others off', () async {
    final a = _Grouped('a'), b = _Grouped('b'), c = _Fake('c');
    final r = FeatureRegistry([a, b, c], mountContext: null);
    await r.setEnabled('a', true);
    await r.setEnabled('c', true);
    await r.setEnabled('b', true);
    expect(r.isEnabled('a'), isFalse);
    expect(r.isMounted('a'), isFalse);
    expect(a.unmounts, 1);
    expect(r.isEnabled('b'), isTrue);
    expect(r.isMounted('b'), isTrue);
    expect(r.isEnabled('c'), isTrue, reason: 'features outside the group are untouched');
  });
```

- [ ] **Step 3: Run to see both fail**

Run: `fvm flutter test test/math/settle_timer_test.dart test/hotel/feature_registry_test.dart`
Expected: compile errors: `SettleTimer` isn't defined, and `exclusiveGroup` isn't a member.

- [ ] **Step 4: Implement**

Append to `lib/math/schedulers.dart`:

```dart
/// Fires once, [quiet] seconds after the last [markDirty], and never while
/// changes keep coming: for work too heavy to repeat mid-change (a probe
/// re-capture). [RebakeThrottle], by contrast, also fires during changes.
class SettleTimer {
  SettleTimer({this.quiet = 0.5});

  final double quiet;
  double? _sinceChange;

  /// Whether a change is waiting for the quiet period to end.
  bool get pending => _sinceChange != null;

  void markDirty() => _sinceChange = 0;

  /// Call every frame; true on the frame the quiet period ends.
  bool tick(double dt) {
    final since = _sinceChange;
    if (since == null) return false;
    final now = since + dt;
    if (now < quiet) {
      _sinceChange = now;
      return false;
    }
    _sinceChange = null;
    return true;
  }
}
```

In `lib/hotel/hotel_context.dart`, below `dynamicColliders`:

```dart
  /// Bumped when a light the probes should see is switched (lamps, the
  /// bathroom light, reading lights). The light-probes feature re-captures
  /// once things settle.
  final ValueNotifier<int> lightingRevision = ValueNotifier(0);

  /// While above zero, occlusion culling hides nothing: a probe capture must
  /// see the whole scene, not just what the camera sees. Take and release it
  /// in pairs.
  int occlusionHolds = 0;
```

In `lib/hotel/feature.dart`, below `defaultOn`:

```dart
  /// Features sharing a group are alternatives: switching one on switches
  /// the others off (the anti-aliasing modes). Null: no group.
  String? get exclusiveGroup => null;
```

In `lib/hotel/feature_registry.dart`, replace `setEnabled`:

```dart
  Future<void> setEnabled(String id, bool on) {
    final f = byId(id);
    if (!on && !f.toggleable) return Future.value();
    final group = f.exclusiveGroup;
    // Switching a grouped feature on switches its alternatives off.
    final rivals = [
      if (on && group != null)
        for (final g in features)
          if (g.id != id && g.exclusiveGroup == group && _wanted.contains(g.id)) g,
    ];
    on ? _wanted.add(id) : _wanted.remove(id);
    for (final g in rivals) {
      _wanted.remove(g.id);
    }
    notifyListeners();
    return Future.wait([for (final g in rivals) _enqueue(g), _enqueue(f)]);
  }
```

- [ ] **Step 5: Run the tests**

Run: `fvm flutter test test/math/settle_timer_test.dart test/hotel/feature_registry_test.dart`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/math/schedulers.dart lib/hotel/hotel_context.dart lib/hotel/feature.dart \
  lib/hotel/feature_registry.dart test/math/settle_timer_test.dart test/hotel/feature_registry_test.dart
git commit -m "feat(hotel): settle timer, lighting revision, occlusion hold, exclusive toggle groups"
```

### Task 2: Look flags for auto exposure, volumetric fog and dynamic GI

**Files:**
- Modify: `lib/hotel/look.dart`
- Modify: `test/hotel/look_test.dart`

**Interfaces:**
- Produces: `LookState.autoExposure`, `LookState.volumetricFog`, `LookState.dynamicGi` (bool, default false) and `LookState.volumetricFogThickness` (double, default 1.0).
- Produces constants: `kAutoExposureRangeEv`, `kVolumetricFogDensity`, `kVolumetricFogFalloff`, `kVolumetricFogHeight`, `kVolumetricSunInScatter`, `kVolumetricGodRaysDensity`, `kVolumetricGodRaysIntensity`, `kVolumetricGodRaysMaxDistance`, `kGiVisibility`, `kGiVisibilityBias`.

- [ ] **Step 1: Write the failing tests.** Add `import 'dart:math' as math;` to `test/hotel/look_test.dart`, then these tests inside `main()`:

```dart
  test('volumetric fog: height fog, sun glow and forced shafts', () {
    final plain = composeLook(LookState()..fog = true);
    expect(plain.fogHeightFalloff, 0);
    expect(plain.fogSunInScatter, 0);
    expect(plain.godRaysEnabled, isFalse);

    final v = composeLook(LookState()..volumetricFog = true);
    expect(v.fogEnabled, isTrue, reason: 'on even with the plain fog switch off');
    expect(v.fogHeight, kVolumetricFogHeight);
    expect(v.fogHeightFalloff, kVolumetricFogFalloff);
    expect(v.fogSunInScatter, kVolumetricSunInScatter);
    expect(v.godRaysEnabled, isTrue);
    expect(v.godRaysDensity, kVolumetricGodRaysDensity);
    expect(v.godRaysMaxDistance, kVolumetricGodRaysMaxDistance);

    final storm = composeLook(LookState()
      ..volumetricFog = true
      ..volumetricFogThickness = 2.5);
    expect(storm.fogDensity, closeTo(kVolumetricFogDensity * 2.5, 1e-12));
  });

  test('the rooms, 90 m above the sea, see under a tenth of its fog', () {
    expect(math.exp(-kVolumetricFogFalloff * (0 - kVolumetricFogHeight)), lessThan(0.1));
  });

  test('auto exposure and dynamic GI flags', () {
    final off = composeLook(LookState());
    expect(off.autoExposureEnabled, isFalse);
    expect(off.globalIlluminationEnabled, isFalse);
    final on = composeLook(LookState()
      ..autoExposure = true
      ..dynamicGi = true);
    expect(on.autoExposureEnabled, isTrue);
    expect(on.autoExposureMinEv, -kAutoExposureRangeEv);
    expect(on.autoExposureMaxEv, kAutoExposureRangeEv);
    expect(on.globalIlluminationEnabled, isTrue);
    expect(on.globalIlluminationVolumeMode, IrradianceVolumeMode.component);
    expect(on.globalIlluminationVisibilityBias, kGiVisibilityBias);
  });
```

- [ ] **Step 2: Run to see them fail**

Run: `fvm flutter test test/hotel/look_test.dart`
Expected: compile errors for `volumetricFog`, `kVolumetricFogHeight` and the rest.

- [ ] **Step 3: Implement.** In `lib/hotel/look.dart`, below `kFogCutoffDistance`:

```dart
/// Auto exposure's reach either side of the sky's scheduled exposure, in EV
/// stops: enough to adapt between the room and the balcony without undoing
/// the sky feature's day/night schedule.
const double kAutoExposureRangeEv = 1.5;

/// Volumetric fog: exponential density at the sea (y = −90, ocean_feature's
/// kSeaLevel), falling off with height so the rooms 90 m up see about 7 % of
/// it (e^(−0.03 · 90) ≈ 0.067): mist over the sea, clear air on the balcony.
const double kVolumetricFogDensity = 0.012, kVolumetricFogFalloff = 0.03;
const double kVolumetricFogHeight = -90;

/// The fog's glow toward the sun.
const double kVolumetricSunInScatter = 0.6;

/// God rays while volumetric fog is on: thicker, longer shafts.
const double kVolumetricGodRaysDensity = 0.35,
    kVolumetricGodRaysIntensity = 1.2,
    kVolumetricGodRaysMaxDistance = 250;

/// Dynamic GI's leak guard: the depth-moment visibility test nearly at full
/// strength, with a bias (a fraction of the 1 m vertical probe spacing) under
/// the thinnest wall, the bathroom's 6 cm.
const double kGiVisibility = 0.9, kGiVisibilityBias = 0.05;
```

In `LookState`, below `sunShadows`:

```dart
  /// Task 5 (auto exposure), Task 7 (volumetric fog), Task 12 (dynamic GI).
  bool autoExposure = false, volumetricFog = false, dynamicGi = false;

  /// Multiplies the volumetric fog's density; the fog feature raises it with
  /// the weather.
  double volumetricFogThickness = 1.0;
```

In `composeLook`, add `final volumetric = s.volumetricFog;` after `final exposure = ...`. Then replace these existing arguments:

```dart
      fogEnabled: s.fog,
      fogDensity: s.fogDensity,
```

with:

```dart
      fogEnabled: s.fog || volumetric,
      fogDensity: volumetric ? kVolumetricFogDensity * s.volumetricFogThickness : s.fogDensity,
      fogHeight: volumetric ? kVolumetricFogHeight : 0.0,
      fogHeightFalloff: volumetric ? kVolumetricFogFalloff : 0.0,
      fogSunInScatter: volumetric ? kVolumetricSunInScatter : 0.0,
```

and replace

```dart
      godRaysEnabled: s.godRays,
      godRaysStepCount: 24,
      godRaysDensity: 0.18,
```

with:

```dart
      godRaysEnabled: s.godRays || volumetric,
      godRaysStepCount: 24,
      godRaysDensity: volumetric ? kVolumetricGodRaysDensity : 0.18,
      godRaysIntensity: volumetric ? kVolumetricGodRaysIntensity : 1.0,
      godRaysMaxDistance: volumetric ? kVolumetricGodRaysMaxDistance : 200.0,
      autoExposureEnabled: s.autoExposure,
      autoExposureMinEv: -kAutoExposureRangeEv,
      autoExposureMaxEv: kAutoExposureRangeEv,
      autoExposureSpeedUp: 3.0,
      autoExposureSpeedDown: 1.0,
      globalIlluminationEnabled: s.dynamicGi,
      globalIlluminationVolumeMode: IrradianceVolumeMode.component,
      globalIlluminationVisibility: kGiVisibility,
      globalIlluminationVisibilityBias: kGiVisibilityBias,
```

The fog values used when the flags are off (height 0, falloff 0, in-scatter 0, god-ray intensity 1.0, max distance 200) are the engine defaults. The look with every new flag off is therefore unchanged.

- [ ] **Step 4: Run the tests**

Run: `fvm flutter test test/hotel/look_test.dart`
Expected: all pass, the existing tests included.

- [ ] **Step 5: Commit**

```bash
git add lib/hotel/look.dart test/hotel/look_test.dart
git commit -m "feat(look): flags for auto exposure, volumetric fog and dynamic GI"
```

### Task 3: Occlusion hold, room-contents root, lamps bump the lighting revision

**Files:**
- Modify: `lib/features/occlusion_feature.dart`
- Modify: `lib/features/lamps_feature.dart`
- Modify: `test/features/lamps_feature_test.dart`

**Interfaces:**
- Consumes: `HotelContext.occlusionHolds` and `HotelContext.lightingRevision` (Task 1).
- Produces: `Node roomContentsRoot(Node root)` in `occlusion_feature.dart`: the node a room's furniture hangs under (room A: its root; room B: the `room` child under the x-mirror).

- [ ] **Step 1: Write the failing lamps test.** In `test/features/lamps_feature_test.dart`, add `import 'package:flutter/foundation.dart';` and this member of `_Context`:

```dart
  @override
  final ValueNotifier<int> lightingRevision = ValueNotifier(0);
```

and inside `main()`:

```dart
  test('switching any lamp or the bathroom light bumps the lighting revision', () async {
    final ctx = _Context();
    for (final room in RoomId.values) {
      final root = Node(name: room.name)
        ..add(Node(name: 'lamp_bedside'))
        ..add(Node(name: 'lamp_floor'))
        ..add(Node(name: 'bath_light'))
        ..add(Node(name: 'bath_switch'));
      ctx.rooms[room] = root;
    }
    await LampsFeature().mount(ctx);
    final taps = ctx.interactions.all.toList();
    expect(taps, hasLength(6));
    for (final tap in taps) {
      tap.onTap();
    }
    expect(ctx.lightingRevision.value, 6);
  });
```

- [ ] **Step 2: Run to see it fail**

Run: `fvm flutter test test/features/lamps_feature_test.dart`
Expected: FAIL, `Expected: <6> Actual: <0>`.

- [ ] **Step 3: Implement the lamps change.** In `lib/features/lamps_feature.dart`:
  - Add `import 'dart:ui' show VoidCallback;`.
  - Construct with `_Lamp(node, onSwitch: () => ctx.lightingRevision.value++)` and `_BathLight(lights[i], switches[i], onSwitch: () => ctx.lightingRevision.value++)`.
  - In both classes: take `{required this.onSwitch}` in the constructor, declare `final VoidCallback onSwitch;`, and in `onTap` call `onSwitch();` after `_apply();`.

```dart
  _Lamp(this.node, {required this.onSwitch}) {
    // ...unchanged...
    interaction = Interactable(
      node: node,
      label: 'Lamp on/off',
      onTap: () {
        _on = !_on;
        _apply();
        onSwitch();
      },
    );
    _apply();
  }

  final VoidCallback onSwitch;
```

Make the same change to `_BathLight(this.fixture, this.switchNode, {required this.onSwitch})`.

- [ ] **Step 4: Implement the occlusion hold and `roomContentsRoot`.** In `lib/features/occlusion_feature.dart`, replace `roomContents`:

```dart
/// The node a room's furniture and fixtures hang under: the root itself for
/// room A, the `room` child under room B's x-mirror. Features that add
/// nodes to a room add them here, so room B mirrors them for free and
/// occlusion culling still finds the room's contents.
Node roomContentsRoot(Node root) {
  var n = root;
  while (n.mesh == null && n.children.length == 1) {
    n = n.children.single;
  }
  return n;
}

/// The room's furniture and fixtures.
List<Node> roomContents(Node root) => roomContentsRoot(root).children;
```

and at the top of `OcclusionFeature.tick`:

```dart
    if (ctx.occlusionHolds > 0) {
      // A probe capture renders this frame: it must see the whole scene.
      _apply(const {}, const {}, const {});
      return;
    }
```

- [ ] **Step 5: Run everything**

Run: `fvm flutter analyze lib test && fvm flutter test`
Expected: no issues; all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/occlusion_feature.dart lib/features/lamps_feature.dart test/features/lamps_feature_test.dart
git commit -m "feat(occlusion): hold for probe captures; lamps bump the lighting revision"
```

### Task 4: Feature scaffolding, anti-aliasing modes, catalog and presets

After this task every new toggle appears on the Effects sheet and in the presets. The Wave B tasks then fill in their own skeleton files.

**Files:**
- Modify: `lib/features/render_features.dart` (AA group)
- Create skeletons: `lib/features/light_probes_feature.dart`, `lib/features/dynamic_gi_feature.dart`, `lib/features/auto_exposure_feature.dart`, `lib/features/static_shadows_feature.dart`, `lib/features/spot_lights_feature.dart`, `lib/features/area_lights_feature.dart`, `lib/features/volumetric_fog_feature.dart`
- Modify: `lib/hotel/feature_catalog.dart`, `lib/hotel/presets.dart`
- Create: `test/features/anti_aliasing_test.dart`
- Modify: `test/hotel/presets_test.dart`

**Interfaces:**
- Consumes: `exclusiveGroup` (Task 1).
- Produces: `const String kAaGroup = 'aa'`, `AntiAliasingMode aaAfterUnmount(AntiAliasingMode current, AntiAliasingMode mine)`, and `MsaaFeature`, `FxaaFeature`, `SmaaFeature`, `TaaFeature` (ids `msaa`, `fxaa`, `smaa`, `taa`).
- Produces the classes the Wave B tasks fill in (id, label, tier, defaultOn exactly as below): `LightProbesFeature`, `DynamicGiFeature`, `AutoExposureFeature`, `StaticShadowsFeature`, `SpotLightsFeature`, `AreaLightsFeature`, `VolumetricFogFeature`.
- Produces: `const Map<Preset, String?> kPresetAa`.

- [ ] **Step 1: Write the failing tests.** `test/features/anti_aliasing_test.dart`:

```dart
import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/features/render_features.dart';
import 'package:flutter_3d/hotel/feature.dart';
import 'package:flutter_3d/hotel/feature_registry.dart';
import 'package:flutter_3d/hotel/presets.dart';

class _Aa extends HotelFeature {
  _Aa(this.id);
  @override
  final String id;
  @override
  String get label => id;
  @override
  CostTier get tier => CostTier.cheap;
  @override
  bool get defaultOn => false;
  @override
  String? get exclusiveGroup => kAaGroup;
  @override
  Future<void> mount(Object? ctx) async {}
  @override
  void unmount(Object? ctx) {}
}

void main() {
  test('unmounting a mode turns AA off only if that mode is still in charge', () {
    expect(aaAfterUnmount(AntiAliasingMode.msaa, AntiAliasingMode.msaa), AntiAliasingMode.none);
    // The new mode mounted first (per-feature chains interleave): keep it.
    expect(aaAfterUnmount(AntiAliasingMode.fxaa, AntiAliasingMode.msaa), AntiAliasingMode.fxaa);
  });

  test('presets swap anti-aliasing modes cleanly', () async {
    final r = FeatureRegistry([for (final id in ['msaa', 'fxaa', 'smaa', 'taa']) _Aa(id)],
        mountContext: null);
    Set<String> on() => {for (final f in r.features) if (r.isMounted(f.id)) f.id};
    await applyPreset(r, Preset.high);
    expect(on(), {'msaa'});
    await applyPreset(r, Preset.medium);
    expect(on(), {'fxaa'});
    await applyPreset(r, Preset.low);
    expect(on(), <String>{});
    await applyPreset(r, Preset.high);
    expect(on(), {'msaa'});
  });
}
```

Replace `test/hotel/presets_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/features/render_features.dart';
import 'package:flutter_3d/hotel/presets.dart';
import 'package:flutter_3d/hotel/feature_catalog.dart';

const aaModes = {'msaa', 'fxaa', 'smaa', 'taa'};

void main() {
  test('each preset is a superset of the one below, outside the AA group', () {
    for (var i = 1; i < Preset.values.length; i++) {
      final hi = presetIds(Preset.values[i]).difference(aaModes);
      final lo = presetIds(Preset.values[i - 1]).difference(aaModes);
      expect(hi.containsAll(lo), true, reason: '${Preset.values[i]}');
    }
  });

  test('each preset turns on at most one anti-aliasing mode, its own', () {
    for (final p in Preset.values) {
      final aa = presetIds(p).intersection(aaModes);
      final mode = kPresetAa[p];
      expect(aa, mode == null ? isEmpty : {mode}, reason: '$p');
    }
  });

  test('every id in a preset exists and is toggleable', () {
    final toggleable = buildCatalog().where((f) => f.toggleable).map((f) => f.id).toSet();
    for (final p in Preset.values) {
      expect(toggleable.containsAll(presetIds(p)), true, reason: '$p');
    }
  });

  test('ultra enables every toggleable feature except the alternative AA modes', () {
    final toggleable = buildCatalog().where((f) => f.toggleable).map((f) => f.id).toSet();
    expect(presetIds(Preset.ultra), toggleable.difference({'fxaa', 'smaa', 'taa'}));
  });

  test('the anti-aliasing modes form one exclusive group', () {
    final aa = buildCatalog().where((f) => aaModes.contains(f.id)).toList();
    expect(aa.map((f) => f.id).toSet(), aaModes);
    for (final f in aa) {
      expect(f.exclusiveGroup, kAaGroup, reason: f.id);
    }
  });
}
```

- [ ] **Step 2: Run to see them fail**

Run: `fvm flutter test test/features/anti_aliasing_test.dart test/hotel/presets_test.dart`
Expected: compile errors (`kAaGroup`, `aaAfterUnmount`, `kPresetAa` aren't defined).

- [ ] **Step 3: Implement the AA group.** In `lib/features/render_features.dart`, replace `MsaaFeature` with:

```dart
/// The anti-aliasing modes are one exclusive group: switching one on
/// switches the others off (FeatureRegistry).
const String kAaGroup = 'aa';

/// The mode to leave behind when the feature that set [mine] unmounts: off,
/// unless another mode has already taken over. Per-feature reconcile chains
/// can mount the new mode before the old one unmounts.
AntiAliasingMode aaAfterUnmount(AntiAliasingMode current, AntiAliasingMode mine) =>
    current == mine ? AntiAliasingMode.none : current;

/// One anti-aliasing mode. The context starts at `none` (HotelContext), so
/// off really is off.
abstract class AaFeature extends HotelFeature {
  AaFeature(this.mode);
  final AntiAliasingMode mode;

  @override
  bool get defaultOn => false;
  @override
  String? get exclusiveGroup => kAaGroup;

  @override
  Future<void> mount(HotelContext ctx) async => ctx.scene.antiAliasingMode = mode;

  @override
  void unmount(HotelContext ctx) =>
      ctx.scene.antiAliasingMode = aaAfterUnmount(ctx.scene.antiAliasingMode, mode);
}

class MsaaFeature extends AaFeature {
  MsaaFeature() : super(AntiAliasingMode.msaa);
  @override
  String get id => 'msaa';
  @override
  String get label => 'MSAA anti-aliasing';
  @override
  CostTier get tier => CostTier.mid;
}

class FxaaFeature extends AaFeature {
  FxaaFeature() : super(AntiAliasingMode.fxaa);
  @override
  String get id => 'fxaa';
  @override
  String get label => 'FXAA anti-aliasing';
  @override
  CostTier get tier => CostTier.cheap;
}

class SmaaFeature extends AaFeature {
  SmaaFeature() : super(AntiAliasingMode.smaa);
  @override
  String get id => 'smaa';
  @override
  String get label => 'SMAA anti-aliasing';
  @override
  CostTier get tier => CostTier.mid;
}

class TaaFeature extends AaFeature {
  TaaFeature() : super(AntiAliasingMode.taa);
  @override
  String get id => 'taa';
  @override
  String get label => 'TAA anti-aliasing';
  @override
  CostTier get tier => CostTier.mid;
}
```

- [ ] **Step 4: Create the seven skeletons.** Each is complete and does nothing until its Wave B task replaces the file. Create them exactly as below, since the ids, labels, tiers and defaults are the contract.

`lib/features/light_probes_feature.dart`:

```dart
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

/// Baked light probes: each room's captured lighting as its ambient and
/// reflections. Task 11 builds it; until then it does nothing.
class LightProbesFeature extends HotelFeature {
  @override
  String get id => 'light_probes';
  @override
  String get label => 'Baked light probes (room ambient + reflections)';
  @override
  CostTier get tier => CostTier.cheap;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}
```

`lib/features/dynamic_gi_feature.dart`:

```dart
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

/// Dynamic GI, a live light-probe grid. Task 12 builds it; until then it
/// does nothing.
class DynamicGiFeature extends HotelFeature {
  @override
  String get id => 'dynamic_gi';
  @override
  String get label => 'Dynamic GI (Lumen-lite probe grid)';
  @override
  CostTier get tier => CostTier.expensive;
  @override
  bool get defaultOn => false;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}
```

`lib/features/auto_exposure_feature.dart`:

```dart
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

/// Auto exposure (eye adaptation). Task 5 builds it; until then it does
/// nothing.
class AutoExposureFeature extends HotelFeature {
  @override
  String get id => 'auto_exposure';
  @override
  String get label => 'Auto exposure (eye adaptation)';
  @override
  CostTier get tier => CostTier.cheap;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}
```

`lib/features/static_shadows_feature.dart`:

```dart
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

/// Cached static shadows. Task 6 builds it; until then it does nothing.
class StaticShadowsFeature extends HotelFeature {
  @override
  String get id => 'static_shadows';
  @override
  String get label => 'Cached static shadows';
  @override
  CostTier get tier => CostTier.free;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}
```

`lib/features/spot_lights_feature.dart`:

```dart
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

/// Reading spot lights. Task 10 builds it; until then it does nothing.
class SpotLightsFeature extends HotelFeature {
  @override
  String get id => 'spot_lights';
  @override
  String get label => 'Reading spot lights (shadowed)';
  @override
  CostTier get tier => CostTier.mid;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}
```

`lib/features/area_lights_feature.dart`:

```dart
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

/// Area lights (TV glow, window light). Task 8 builds it; until then it does
/// nothing.
class AreaLightsFeature extends HotelFeature {
  @override
  String get id => 'area_lights';
  @override
  String get label => 'Area lights (TV glow, window light)';
  @override
  CostTier get tier => CostTier.cheap;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}
```

`lib/features/volumetric_fog_feature.dart`:

```dart
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

/// Volumetric fog and light shafts. Task 7 builds it; until then it does
/// nothing.
class VolumetricFogFeature extends HotelFeature {
  @override
  String get id => 'volumetric_fog';
  @override
  String get label => 'Volumetric fog + light shafts (needs Sun shadows)';
  @override
  CostTier get tier => CostTier.expensive;
  @override
  bool get defaultOn => false;
  @override
  Future<void> mount(HotelContext ctx) async {}
  @override
  void unmount(HotelContext ctx) {}
}
```

- [ ] **Step 5: Register them.** In `lib/hotel/feature_catalog.dart`, add the imports (`light_probes_feature.dart`, `dynamic_gi_feature.dart`, `auto_exposure_feature.dart`, `static_shadows_feature.dart`, `spot_lights_feature.dart`, `area_lights_feature.dart`, `volumetric_fog_feature.dart`), then change the list's tail to:

```dart
      ScreensFeature(), BooksFeature(), InstancingFeature(), EntranceFeature(),
      LightProbesFeature(), DynamicGiFeature(), AutoExposureFeature(), StaticShadowsFeature(),
      FxaaFeature(), SmaaFeature(), TaaFeature(),
      SpotLightsFeature(), AreaLightsFeature(), VolumetricFogFeature(),
      OcclusionFeature(),
```

Leave `MsaaFeature()` where it is.

- [ ] **Step 6: Update the presets.** Replace the sets and `presetIds` in `lib/hotel/presets.dart`:

```dart
const _low = {'sky', 'ocean', 'tone_mapping', 'portal_culling', 'occlusion', 'instancing'};
const _medium = {
  ..._low, 'fog', 'shadows', 'lamps', 'water_fx',
  'light_probes', 'auto_exposure', 'static_shadows', 'area_lights',
};
const _high = {..._medium, 'bloom', 'ao', 'rain', 'lightning', 'spot_lights'};
const _ultra = {
  ..._high, 'god_rays', 'ssr', 'rain_glass', 'mirror', 'sea_reflection',
  'dynamic_gi', 'volumetric_fog',
};

/// Each tier's one anti-aliasing mode (the `aa` exclusive group), or none.
/// SMAA and TAA are manual picks.
const Map<Preset, String?> kPresetAa = {
  Preset.low: null,
  Preset.medium: 'fxaa',
  Preset.high: 'msaa',
  Preset.ultra: 'msaa',
};

/// Toggleable feature ids that are ON for [p]. Each tier is a superset of the
/// one below, apart from its anti-aliasing mode.
Set<String> presetIds(Preset p) {
  final base = switch (p) {
    Preset.low => _low,
    Preset.medium => _medium,
    Preset.high => _high,
    Preset.ultra => _ultra,
  };
  final aa = kPresetAa[p];
  return {...base, if (aa != null) aa};
}
```

- [ ] **Step 7: Run everything**

Run: `fvm flutter analyze lib test && fvm flutter test`
Expected: no issues; all pass. That includes `debug_tour_test` (`parsePreset`) and `presets_test`.

- [ ] **Step 8: Commit and merge Wave A**

```bash
git add lib/features/render_features.dart lib/features/*_feature.dart lib/hotel/feature_catalog.dart \
  lib/hotel/presets.dart test/features/anti_aliasing_test.dart test/hotel/presets_test.dart
git status --short   # only this task's files should be staged
git commit -m "feat(effects): FXAA/SMAA/TAA as an exclusive group; skeletons and presets for the lighting toggles"
```

Wave A is done: tell the coordinator `main` is ready for Wave B.

---

## Wave B: features (parallel; each agent owns only its task's files)

### Task 5: Auto exposure

**Files:**
- Replace: `lib/features/auto_exposure_feature.dart`
- Create: `test/features/auto_exposure_feature_test.dart`

**Interfaces:**
- Consumes: `LookState.autoExposure` and `kAutoExposureRangeEv` (Task 2), `HotelContext.applyLook()`, `ctx.scene.autoExposure.reset()` (engine).
- Produces: `bool isTeleport(Vector3 before, Vector3 after)` and `const double kTeleportDistance`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/features/auto_exposure_feature.dart';
import 'package:flutter_3d/hotel/hotel_context.dart';
import 'package:flutter_3d/hotel/look.dart';

class _Context extends Fake implements HotelContext {
  @override
  final LookState look = LookState();
  int applied = 0;
  @override
  void applyLook() => applied++;
}

void main() {
  test('a walking step is not a teleport; a tour jump is', () {
    expect(isTeleport(Vector3(-4, 1.6, 3), Vector3(-4, 1.6, 3.03)), isFalse);
    expect(isTeleport(Vector3(-4, 1.6, 3), Vector3(-6.8, 1.6, 0.55)), isTrue);
  });

  test('mount switches the look flag on, unmount off', () async {
    final ctx = _Context();
    final f = AutoExposureFeature();
    await f.mount(ctx);
    expect(ctx.look.autoExposure, isTrue);
    expect(ctx.applied, 1);
    f.unmount(ctx);
    expect(ctx.look.autoExposure, isFalse);
    expect(ctx.applied, 2);
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `fvm flutter test test/features/auto_exposure_feature_test.dart`
Expected: compile error, `isTeleport` isn't defined.

- [ ] **Step 3: Implement** (replace the skeleton)

```dart
import 'package:vector_math/vector_math.dart';
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

/// A camera jump longer than this in one frame is a teleport (a tour stop,
/// the perf probe): eye adaptation snaps to the new view instead of ramping
/// from the old one.
const double kTeleportDistance = 1.0;

bool isTeleport(Vector3 before, Vector3 after) => (after - before).length > kTeleportDistance;

/// Auto exposure (eye adaptation): the engine meters each frame and eases
/// the exposure within ±kAutoExposureRangeEv of the sky's schedule, so the
/// room brightens again after the bright balcony. The settings live in
/// composeLook.
class AutoExposureFeature extends HotelFeature {
  @override
  String get id => 'auto_exposure';
  @override
  String get label => 'Auto exposure (eye adaptation)';
  @override
  CostTier get tier => CostTier.cheap;

  Vector3? _lastEye;

  @override
  Future<void> mount(HotelContext ctx) async {
    ctx.look.autoExposure = true;
    ctx.applyLook();
    _lastEye = null; // the first tick snaps
  }

  @override
  void tick(HotelContext ctx, double dt) {
    final eye = ctx.camera.position;
    final last = _lastEye;
    if (last == null || isTeleport(last, eye)) ctx.scene.autoExposure.reset();
    _lastEye = eye.clone();
  }

  @override
  void unmount(HotelContext ctx) {
    ctx.look.autoExposure = false;
    ctx.applyLook();
    _lastEye = null;
  }
}
```

- [ ] **Step 4: Run the tests and the analyzer**

Run: `fvm flutter test test/features/auto_exposure_feature_test.dart && fvm flutter analyze lib test`
Expected: pass; no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/auto_exposure_feature.dart test/features/auto_exposure_feature_test.dart
git commit -m "feat(lighting): auto exposure toggle that snaps on teleports"
```

### Task 6: Cached static shadows

**Files:**
- Replace: `lib/features/static_shadows_feature.dart`
- Create: `test/features/static_shadows_test.dart`

**Interfaces:**
- Produces: `const Set<String> kShadowMovers` and `List<Node> markStaticShadows(Node root, {Set<String> movers})`.
- Note: the spec also names the facade. The ocean's nodes never cast shadows (`castsShadows = false` in `ocean_feature.dart`), so marking them would change nothing, and only the rooms are marked.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/features/static_shadows_feature.dart';

Node tree() => Node(name: 'room_a')
  ..add(Node(name: 'walls'))
  ..add(Node(name: 'bed'))
  ..add(Node(name: 'curtain_left'))
  ..add(Node(name: 'faucet_spout')..add(Node(name: 'faucet_lever')..add(Node(name: 'lever_tip'))))
  ..add(Node(name: 'bath_switch')..add(Node(name: 'bath_switch_rocker')));

Node named(Node n, String name) {
  Node? find(Node m) {
    if (m.name == name) return m;
    for (final c in m.children) {
      final hit = find(c);
      if (hit != null) return hit;
    }
    return null;
  }

  return find(n) ?? (throw StateError('no node $name'));
}

void main() {
  test('everything static is marked; movers and their subtrees stay dynamic', () {
    final root = tree();
    final marked = markStaticShadows(root);
    for (final name in ['room_a', 'walls', 'bed', 'faucet_spout', 'bath_switch']) {
      expect(named(root, name).shadowStatic, isTrue, reason: name);
    }
    for (final name in ['curtain_left', 'faucet_lever', 'lever_tip', 'bath_switch_rocker']) {
      expect(named(root, name).shadowStatic, isFalse, reason: name);
    }
    expect(marked, hasLength(5));
  });

  test('only nodes it changed are returned, so unmarking restores exactly', () {
    final root = tree();
    named(root, 'walls').shadowStatic = true; // already static: not ours
    final marked = markStaticShadows(root);
    for (final n in marked) {
      n.shadowStatic = false;
    }
    expect(named(root, 'walls').shadowStatic, isTrue);
    expect(named(root, 'bed').shadowStatic, isFalse);
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `fvm flutter test test/features/static_shadows_test.dart`
Expected: compile error, `markStaticShadows` isn't defined.

- [ ] **Step 3: Implement** (replace the skeleton)

```dart
import 'package:flutter_scene/scene.dart';
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

/// Room nodes that move while mounted, with everything under them: they stay
/// dynamic shadow casters. The door leaf moves to the scene root once the
/// door feature mounts, but is listed in case it hasn't yet.
const Set<String> kShadowMovers = {
  'door_connect', 'curtain_left', 'curtain_right', 'faucet_lever', 'bath_switch_rocker',
};

/// Marks [root]'s subtree as static shadow casters, skipping [movers] and
/// their subtrees. Returns only the nodes it changed, so unmarking them
/// restores exactly what was there.
List<Node> markStaticShadows(Node root, {Set<String> movers = kShadowMovers}) {
  final out = <Node>[];
  void walk(Node n) {
    if (movers.contains(n.name)) return;
    if (!n.shadowStatic) {
      n.shadowStatic = true;
      out.add(n);
    }
    for (final c in n.children) {
      walk(c);
    }
  }

  walk(root);
  return out;
}

/// Cached static shadows: walls and furniture render into cached sun
/// shadow-map tiles once (the engine re-renders them only when the sun or a
/// caster changes), and only the movers render every frame.
class StaticShadowsFeature extends HotelFeature {
  @override
  String get id => 'static_shadows';
  @override
  String get label => 'Cached static shadows';
  @override
  CostTier get tier => CostTier.free;

  final List<Node> _marked = [];

  @override
  Future<void> mount(HotelContext ctx) async {
    for (final room in ctx.rooms.values) {
      _marked.addAll(markStaticShadows(room));
    }
  }

  @override
  void unmount(HotelContext ctx) {
    for (final n in _marked) {
      n.shadowStatic = false;
    }
    _marked.clear();
  }
}
```

- [ ] **Step 4: Run the tests and the analyzer**

Run: `fvm flutter test test/features/static_shadows_test.dart && fvm flutter analyze lib test`
Expected: pass; no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/static_shadows_feature.dart test/features/static_shadows_test.dart
git commit -m "feat(lighting): cached static shadows for everything in the rooms that doesn't move"
```

### Task 7: Volumetric fog

**Files:**
- Replace: `lib/features/volumetric_fog_feature.dart`
- Create: `test/features/volumetric_fog_test.dart`

**Interfaces:**
- Consumes: `LookState.volumetricFog` and `LookState.volumetricFogThickness` (Task 2), `HotelContext.weather`.
- Produces: `double fogThickness(double weather)`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/features/volumetric_fog_feature.dart';
import 'package:flutter_3d/hotel/hotel_context.dart';
import 'package:flutter_3d/hotel/look.dart';

class _Context extends Fake implements HotelContext {
  @override
  final LookState look = LookState();
  @override
  double weather = 0;
  int applied = 0;
  @override
  void applyLook() => applied++;
}

void main() {
  test('rain thickens the mist: 1x clear, 2.5x in a full storm', () {
    expect(fogThickness(0), 1);
    expect(fogThickness(1), 2.5);
    expect(fogThickness(3), 2.5, reason: 'clamped');
  });

  test('mount, weather change, unmount', () async {
    final ctx = _Context();
    final f = VolumetricFogFeature();
    await f.mount(ctx);
    expect(ctx.look.volumetricFog, isTrue);
    final applied = ctx.applied;
    f.tick(ctx, 0.016);
    expect(ctx.applied, applied, reason: 'no re-apply while nothing changes');
    ctx.weather = 1;
    f.tick(ctx, 0.016);
    expect(ctx.look.volumetricFogThickness, 2.5);
    expect(ctx.applied, applied + 1);
    f.unmount(ctx);
    expect(ctx.look.volumetricFog, isFalse);
    expect(ctx.look.volumetricFogThickness, 1);
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `fvm flutter test test/features/volumetric_fog_test.dart`
Expected: compile error, `fogThickness` isn't defined.

- [ ] **Step 3: Implement** (replace the skeleton)

```dart
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

/// Rain thickens the mist: 1× clear, 2.5× in a full storm.
double fogThickness(double weather) => 1 + 1.5 * weather.clamp(0.0, 1.0);

/// Volumetric fog, engine-native: exponential height fog that is thick over
/// the sea and thin at the rooms, a glow toward the sun, and god-ray shafts
/// (the sun's volumetric shadows; they need Sun shadows on). The settings
/// live in composeLook.
class VolumetricFogFeature extends HotelFeature {
  @override
  String get id => 'volumetric_fog';
  @override
  String get label => 'Volumetric fog + light shafts (needs Sun shadows)';
  @override
  CostTier get tier => CostTier.expensive;
  @override
  bool get defaultOn => false;

  @override
  Future<void> mount(HotelContext ctx) async {
    ctx.look
      ..volumetricFog = true
      ..volumetricFogThickness = fogThickness(ctx.weather);
    ctx.applyLook();
  }

  @override
  void tick(HotelContext ctx, double dt) {
    final t = fogThickness(ctx.weather);
    if ((t - ctx.look.volumetricFogThickness).abs() < 0.02) return;
    ctx.look.volumetricFogThickness = t;
    ctx.applyLook();
  }

  @override
  void unmount(HotelContext ctx) {
    ctx.look
      ..volumetricFog = false
      ..volumetricFogThickness = 1.0;
    ctx.applyLook();
  }
}
```

- [ ] **Step 4: Run the tests and the analyzer**

Run: `fvm flutter test test/features/volumetric_fog_test.dart && fvm flutter analyze lib test`
Expected: pass; no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/volumetric_fog_feature.dart test/features/volumetric_fog_test.dart
git commit -m "feat(atmosphere): volumetric height fog with sun glow and shafts, thicker in rain"
```

### Task 8: Area lights (TV glow, window skylight)

**Files:**
- Replace: `lib/features/area_lights_feature.dart`
- Create: `test/features/area_lights_test.dart`

**Interfaces:**
- Consumes: `roomContentsRoot` (Task 3), `skyAt(double hours).skyBrightness` (`sky_feature.dart`, 0.012 at night up to 1 by day), `windowX0` and `windowX1` (`placeholder_rooms.dart`), `HotelContext.nodesNamed`, `.rooms`, `.timeOfDay`, `.weather`.
- Produces: `double windowLightIntensity(double brightness, double weather)` and `Matrix4 windowLightTransform()`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/features/area_lights_feature.dart';
import 'package:flutter_3d/hotel/hotel_context.dart';
import 'package:flutter_3d/math/floor_plan.dart';

class _Context extends Fake implements HotelContext {
  @override
  final Map<RoomId, Node> rooms = {};
  @override
  final ValueNotifier<double> timeOfDay = ValueNotifier(15);
  @override
  double weather = 0;
  @override
  List<Node> nodesNamed(String name) {
    final out = <Node>[];
    void walk(Node n) {
      if (n.name == name) out.add(n);
      for (final c in n.children) {
        walk(c);
      }
    }

    for (final r in rooms.values) {
      walk(r);
    }
    return out;
  }
}

/// Room A at identity; room B a `room` child under an x-mirror, as the
/// rooms feature builds them. Each contents node has more than one child,
/// like the real rooms, so `roomContentsRoot` stops there.
_Context rooms() {
  Node contents(String name) => Node(name: name)
    ..add(Node(name: 'tv_screen'))
    ..add(Node(name: 'bed'));
  final ctx = _Context();
  ctx.rooms[RoomId.a] = contents('room_a');
  ctx.rooms[RoomId.b] = Node(name: 'room_b', localTransform: Matrix4.diagonal3Values(-1, 1, 1))
    ..add(contents('room'));
  return ctx;
}

void main() {
  test('night is dim, storms dim the day', () {
    expect(windowLightIntensity(0.012, 0), lessThan(windowLightIntensity(1, 0) * 0.05));
    expect(windowLightIntensity(1, 1), closeTo(windowLightIntensity(1, 0) * 0.4, 1e-9));
  });

  test('window lights sit in each window and shine into their own room', () async {
    final ctx = rooms();
    final f = AreaLightsFeature();
    await f.mount(ctx);
    final windows = ctx.nodesNamed('window_light');
    expect(windows, hasLength(2));
    for (final w in windows) {
      final m = w.globalTransform;
      final pos = m.getTranslation();
      expect(pos.z, closeTo(FloorPlan.roomDepth - 0.02, 1e-6));
      final facing = (m.getRotation() * Vector3(0, 0, 1)) as Vector3;
      expect(facing.z, lessThan(-0.99), reason: 'emits along local +Z, turned to face into the room');
    }
    expect(windows.map((w) => w.globalTransform.getTranslation().x.sign).toSet(), {-1.0, 1.0});
    expect(ctx.nodesNamed('tv_glow'), hasLength(2));
    f.unmount(ctx);
    expect(ctx.nodesNamed('window_light'), isEmpty);
    expect(ctx.nodesNamed('tv_glow'), isEmpty);
  });

  test('the window light follows the time of day', () async {
    final ctx = rooms();
    final f = AreaLightsFeature();
    await f.mount(ctx);
    RectAreaLight light() =>
        ctx.nodesNamed('window_light').first.getComponent<RectAreaLightComponent>()!.light;
    final day = light().intensity;
    expect(day, greaterThan(0));
    ctx.timeOfDay.value = 23;
    f.tick(ctx, 0.016);
    expect(light().intensity, lessThan(day * 0.05));
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `fvm flutter test test/features/area_lights_test.dart`
Expected: compile error, `windowLightIntensity` isn't defined.

- [ ] **Step 3: Implement** (replace the skeleton)

```dart
import 'dart:math' as math;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import '../math/floor_plan.dart';
import 'occlusion_feature.dart' show roomContentsRoot;
import 'placeholder_rooms.dart' show windowX0, windowX1;
import 'sky_feature.dart' show skyAt;

/// The TV's glow: a cool panel the size of the screen (1.2 × 0.675 m).
const double kTvGlowIntensity = 1.5, kTvGlowRange = 4;
final Vector3 kTvGlowColor = Vector3(0.75, 0.85, 1.0);

/// The window's "skylight": a panel filling the opening, as bright as the
/// sky (full by day, about 1 % at night), dimmed by storm cloud.
const double kWindowLightDay = 3.0, kWindowLightRange = 6, kWindowTop = 2.4;
final Vector3 kWindowLightColor = Vector3(0.8, 0.88, 1.0);

/// The window light's intensity for a sky [brightness] (`skyAt().skyBrightness`,
/// 0.012 at night up to 1 by day) and [weather] (0 clear .. 1 storm).
double windowLightIntensity(double brightness, double weather) =>
    kWindowLightDay * brightness.clamp(0.0, 1.0) * (1 - 0.6 * weather.clamp(0.0, 1.0));

/// Room A's window light: in the opening, just inside the glass, turned to
/// face into the room (a rect light emits along its local +Z).
Matrix4 windowLightTransform() => Matrix4.compose(
      Vector3((windowX0 + windowX1) / 2, kWindowTop / 2, FloorPlan.roomDepth - 0.02),
      Quaternion.axisAngle(Vector3(0, 1, 0), math.pi),
      Vector3.all(1),
    );

/// Area lights: a soft glow off each TV screen, and a sky-bright panel in
/// each window, a cheap stand-in for daylight bouncing in. They cast no
/// shadows. Both hang under the rooms' contents, so room B's are mirrored.
class AreaLightsFeature extends HotelFeature {
  @override
  String get id => 'area_lights';
  @override
  String get label => 'Area lights (TV glow, window light)';
  @override
  CostTier get tier => CostTier.cheap;

  final List<Node> _nodes = [];
  final List<RectAreaLight> _windows = [];

  @override
  Future<void> mount(HotelContext ctx) async {
    for (final screen in ctx.nodesNamed('tv_screen')) {
      final glow = Node(name: 'tv_glow', localTransform: Matrix4.translationValues(0, 0, 0.01))
        ..castsShadows = false
        ..raycastable = false
        ..addComponent(RectAreaLightComponent(RectAreaLight(
          color: kTvGlowColor.clone(),
          intensity: kTvGlowIntensity,
          width: 1.2,
          height: 0.675,
          range: kTvGlowRange,
        )));
      screen.add(glow);
      _nodes.add(glow);
    }
    for (final room in ctx.rooms.values) {
      final light = RectAreaLight(
        color: kWindowLightColor.clone(),
        width: windowX1 - windowX0,
        height: kWindowTop,
        range: kWindowLightRange,
      );
      final node = Node(name: 'window_light', localTransform: windowLightTransform())
        ..castsShadows = false
        ..raycastable = false
        ..addComponent(RectAreaLightComponent(light));
      roomContentsRoot(room).add(node);
      _nodes.add(node);
      _windows.add(light);
    }
    tick(ctx, 0);
  }

  @override
  void tick(HotelContext ctx, double dt) {
    final intensity = windowLightIntensity(skyAt(ctx.timeOfDay.value).skyBrightness, ctx.weather);
    for (final light in _windows) {
      light.intensity = intensity;
    }
  }

  @override
  void unmount(HotelContext ctx) {
    for (final n in _nodes) {
      n.parent?.remove(n);
    }
    _nodes.clear();
    _windows.clear();
  }
}
```

- [ ] **Step 4: Run the tests and the analyzer**

Run: `fvm flutter test test/features/area_lights_test.dart && fvm flutter analyze lib test`
Expected: pass; no issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/area_lights_feature.dart test/features/area_lights_test.dart
git commit -m "feat(lighting): area lights, a TV glow and a window skylight that follows the sky"
```

### Task 9: Reading-light fixtures in the room spec

**Files:**
- Modify: `lib/features/placeholder_rooms.dart` (in `_fixtures()`)
- Create: `test/features/reading_lights_test.dart`

**Interfaces:**
- Produces room nodes `reading_light_left` and `reading_light_right`. Each is at `(−8, 1.45, z)` in room-A space, with z 3.3 and 5.3. Each has parts (a brass wall plate and arm) and one child `reading_light_shade`, at local `(0.27, −0.13, 0)`, a fabric cone. Task 10 hangs its spot light at local `(0.27, −0.14, 0)`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/features/placeholder_rooms.dart';
import 'package:flutter_3d/math/floor_plan.dart';

/// World bounds (room A space) of every part under the node named [name].
List<Aabb3> boundsUnder(String name) {
  final out = <Aabb3>[];
  void walk(RoomNode n, Matrix4 parent, bool inside) {
    final m = parent * n.localTransform;
    final hit = inside || n.name == name;
    if (hit) {
      for (final p in n.parts) {
        out.add(Aabb3.copy(p.bounds)..transform(m));
      }
    }
    for (final c in n.children) {
      walk(c, m, hit);
    }
  }

  walk(roomASpec(), Matrix4.identity(), false);
  return out;
}

Aabb3 hull(List<Aabb3> boxes) =>
    boxes.skip(1).fold(Aabb3.copy(boxes.first), (a, b) => a..hull(b));

void main() {
  for (final name in ['reading_light_left', 'reading_light_right']) {
    test('$name hangs on the outer wall above the headboard', () {
      final parts = boundsUnder(name);
      expect(parts, isNotEmpty);
      final b = hull(parts);
      expect(b.min.x, greaterThanOrEqualTo(-FloorPlan.roomWidth - 1e-6), reason: 'not in the wall');
      expect(b.max.x, lessThan(-7.4), reason: 'behind the headboard (x = −7.4)');
      expect(b.min.y, greaterThan(1.3), reason: 'above the headboard (1.35 m) and heads');
      expect(b.max.y, lessThan(1.5), reason: 'below the art (from 1.5 m)');
    });
  }

  test('the fixtures clear the art, the bedside table and its lamp', () {
    final lights = [...boundsUnder('reading_light_left'), ...boundsUnder('reading_light_right')];
    for (final other in ['art_bed', 'bedside_table', 'lamp_bedside']) {
      for (final a in lights) {
        for (final b in boundsUnder(other)) {
          expect(a.intersectsWithAabb3(b), isFalse, reason: 'touches $other');
        }
      }
    }
  });

  test('each has a shade child for the spot feature to light', () {
    expect(boundsUnder('reading_light_shade'), hasLength(2));
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `fvm flutter test test/features/reading_lights_test.dart`
Expected: FAIL (`parts` is empty).

- [ ] **Step 3: Implement.** In `lib/features/placeholder_rooms.dart`, inside `_fixtures()`'s returned list, add after the `_lamp('lamp_floor', ...)` entry:

```dart
    // Reading lights over the bed (the spot-lights feature lights them): a
    // brass plate on the outer wall, an arm, and a cone shade over each side
    // of the headboard, clear of the art above it (z 3.5..5.1, from 1.5 m).
    for (final (name, z) in [('reading_light_left', 3.3), ('reading_light_right', 5.3)])
      RoomNode(name, at: Vector3(-FloorPlan.roomWidth, 1.45, z), parts: [
        BoxPart(Vector3(0, -0.06, -0.04), Vector3(0.012, 0.03, 0.04), _brass), // wall plate
        BoxPart(Vector3(0.012, -0.008, -0.008), Vector3(0.27, 0.008, 0.008), _brass), // arm
      ], children: [
        RoomNode('reading_light_shade', at: Vector3(0.27, -0.13, 0), parts: [
          CylinderPart(Vector3.zero(),
              bottomRadius: 0.07, topRadius: 0.03, height: 0.12, finish: _shadeFabric),
        ]),
      ]),
```

The plate reaches 1.39–1.48 m, the arm 1.442–1.458 m, and the shade 1.32–1.44 m. That's all above 1.3 m, below the art at 1.5 m, and at x ≤ −7.66.

- [ ] **Step 4: Run the new test and the room tests**

Run: `fvm flutter test test/features/reading_lights_test.dart test/features/placeholder_rooms_test.dart test/features/bedding_test.dart && fvm flutter analyze lib test`
Expected: pass; no issues. If a `placeholder_rooms_test` case counts fixtures or names, update its expectation to include the two new fixtures and say so in your report.

- [ ] **Step 5: Commit**

```bash
git add lib/features/placeholder_rooms.dart test/features/reading_lights_test.dart
git commit -m "feat(rooms): brass reading lights over each bed"
```

### Task 10: Reading spot lights (after Task 9)

**Files:**
- Replace: `lib/features/spot_lights_feature.dart`
- Create: `test/features/spot_lights_test.dart`

**Interfaces:**
- Consumes: the fixtures from Task 9, `HotelContext.nodesNamed`, `.interactions`, and `.lightingRevision` (Task 1).
- Produces: `Vector3 readingLightAim()` and the constants `kReadingLightIntensity`, `kReadingLightRange`, `kReadingLightInner`, `kReadingLightOuter`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/features/interaction_registry.dart';
import 'package:flutter_3d/features/spot_lights_feature.dart';
import 'package:flutter_3d/hotel/hotel_context.dart';
import 'package:flutter_3d/math/floor_plan.dart';

class _Context extends Fake implements HotelContext {
  @override
  final Map<RoomId, Node> rooms = {};
  @override
  final InteractionRegistry interactions = InteractionRegistry();
  @override
  final ValueNotifier<int> lightingRevision = ValueNotifier(0);
  @override
  List<Node> nodesNamed(String name) {
    final out = <Node>[];
    void walk(Node n) {
      if (n.name == name) out.add(n);
      for (final c in n.children) {
        walk(c);
      }
    }

    for (final id in RoomId.values) {
      final r = rooms[id];
      if (r != null) walk(r);
    }
    return out;
  }
}

Node fixtures() => Node(name: 'room')
  ..add(Node(name: 'reading_light_left')..add(Node(name: 'reading_light_shade')))
  ..add(Node(name: 'reading_light_right')..add(Node(name: 'reading_light_shade')));

_Context rooms() => _Context()
  ..rooms[RoomId.a] = (Node(name: 'room_a')..add(fixtures()))
  ..rooms[RoomId.b] = (Node(name: 'room_b', localTransform: Matrix4.diagonal3Values(-1, 1, 1))
    ..add(fixtures()));

SpotLightComponent spot(Node fixture) => fixture.children
    .firstWhere((c) => c.name == 'reading_light_source')
    .getComponent<SpotLightComponent>()!;

void main() {
  test('four shadowed reading lights, each aimed into its own room', () async {
    final ctx = rooms();
    await SpotLightsFeature().mount(ctx);
    final a = ctx.nodesNamed('reading_light_left').first;
    final b = ctx.nodesNamed('reading_light_left').last;
    expect(spot(a).light.castsShadow, isTrue);
    expect(spot(a).worldDirection.y, lessThan(0), reason: 'down at the pillows');
    expect(spot(a).worldDirection.x, greaterThan(0), reason: 'room A: away from the x = −8 wall');
    expect(spot(b).worldDirection.x, lessThan(0), reason: 'room B mirrored: away from x = +8');
    expect(ctx.interactions.all, hasLength(4));
  });

  test('a tap switches one light and bumps the lighting revision', () async {
    final ctx = rooms();
    await SpotLightsFeature().mount(ctx);
    final tap = ctx.interactions.all.first;
    final light = spot(tap.node).light;
    expect(light.intensity, kReadingLightIntensity);
    tap.onTap();
    expect(light.intensity, 0);
    expect(ctx.lightingRevision.value, 1);
  });

  test('unmount removes the lights and the taps', () async {
    final ctx = rooms();
    final f = SpotLightsFeature();
    await f.mount(ctx);
    f.unmount(ctx);
    expect(ctx.nodesNamed('reading_light_source'), isEmpty);
    expect(ctx.interactions.all, isEmpty);
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `fvm flutter test test/features/spot_lights_test.dart`
Expected: FAIL, since the skeleton adds no lights.

- [ ] **Step 3: Implement** (replace the skeleton)

```dart
import 'dart:ui' show VoidCallback;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import 'interaction_registry.dart';

/// Warm reading light: a tight cone onto the pillows.
const double kReadingLightIntensity = 6, kReadingLightRange = 3;

/// Cone half-angles in radians: about 17° full brightness, fading out by 34°.
const double kReadingLightInner = 0.3, kReadingLightOuter = 0.6;

/// Down and out from the wall toward the pillows, in the fixture's frame
/// (room A's +X; room B's mirror flips it for free).
Vector3 readingLightAim() => Vector3(0.55, -1, 0)..normalize();

final Vector4 _shadeGlow = Vector4(3, 2.4, 1.7, 1);

class _ReadingLight {
  _ReadingLight(this.fixture, {required this.onSwitch}) {
    for (final c in fixture.children) {
      if (c.name != 'reading_light_shade') continue;
      for (final p in c.mesh?.primitives ?? const <MeshPrimitive>[]) {
        final m = p.material;
        if (m is PhysicallyBasedMaterial) _shades[m] = m.emissiveFactor.clone();
      }
    }
    lightNode.addComponent(SpotLightComponent(light));
    fixture.add(lightNode);
    interaction = Interactable(
      node: fixture,
      label: 'Reading light on/off',
      onTap: () {
        _on = !_on;
        _apply();
        onSwitch();
      },
    );
    _apply();
  }

  final Node fixture;
  final VoidCallback onSwitch;
  final SpotLight light = SpotLight(
    color: Vector3(1, .82, .6),
    intensity: kReadingLightIntensity,
    range: kReadingLightRange,
    direction: readingLightAim(),
    innerConeAngle: kReadingLightInner,
    outerConeAngle: kReadingLightOuter,
    castsShadow: true,
  );

  /// Just under the shade (Task 9 puts it at local (0.27, −0.13, 0)).
  final Node lightNode = Node(
    name: 'reading_light_source',
    localTransform: Matrix4.translationValues(0.27, -0.14, 0),
  )
    ..castsShadows = false
    ..raycastable = false;
  final Map<PhysicallyBasedMaterial, Vector4> _shades = {};
  late final Interactable interaction;
  bool _on = true;

  void _apply() {
    light.intensity = _on ? kReadingLightIntensity : 0;
    for (final e in _shades.entries) {
      e.key.emissiveFactor = _on ? _shadeGlow.clone() : e.value.clone();
    }
  }

  void dispose() {
    fixture.remove(lightNode);
    for (final e in _shades.entries) {
      e.key.emissiveFactor = e.value;
    }
    _shades.clear();
  }
}

/// Reading spot lights: a shadow-casting cone from each brass reading light
/// over the beds, tappable on and off. Default-on because it owns the taps.
class SpotLightsFeature extends HotelFeature {
  @override
  String get id => 'spot_lights';
  @override
  String get label => 'Reading spot lights (shadowed)';
  @override
  CostTier get tier => CostTier.mid;

  final List<_ReadingLight> _lights = [];

  @override
  Future<void> mount(HotelContext ctx) async {
    for (final fixture in [
      ...ctx.nodesNamed('reading_light_left'),
      ...ctx.nodesNamed('reading_light_right'),
    ]) {
      final l = _ReadingLight(fixture, onSwitch: () => ctx.lightingRevision.value++);
      _lights.add(l);
      ctx.interactions.register(l.interaction);
    }
  }

  @override
  void unmount(HotelContext ctx) {
    for (final l in _lights) {
      ctx.interactions.unregister(l.interaction);
      l.dispose();
    }
    _lights.clear();
  }
}
```

- [ ] **Step 4: Run the tests and the analyzer**

Run: `fvm flutter test test/features/spot_lights_test.dart && fvm flutter analyze lib test`
Expected: pass; no issues. If `worldDirection` isn't exposed on `SpotLightComponent` under that name, read `lib/src/components/spot_light_component.dart` in the pub cache and use its getter, and note it in your report.

- [ ] **Step 5: Commit**

```bash
git add lib/features/spot_lights_feature.dart test/features/spot_lights_test.dart
git commit -m "feat(lighting): shadowed reading spot lights over the beds, tappable"
```

### Task 11: Baked light probes (room ambient + reflections)

**Files:**
- Create: `lib/math/light_probes.dart` (pure)
- Replace: `lib/features/light_probes_feature.dart`
- Create: `test/math/light_probes_test.dart`

**Interfaces:**
- Consumes: `SettleTimer` (Task 1), `HotelContext.occlusionHolds` and `.lightingRevision` (Task 1), `roomContentsRoot` (Task 3), `cellOf`/`Cell` (`lib/math/occlusion.dart`, tests only), `ReflectionProbeComponent`, `Scene.baseEnvironment`, `Scene.environment`, `SkyEnvironment.invalidate()`.
- Produces: `typedef ProbeBox`, `List<ProbeBox> roomProbeBoxes()`, `class LightingSignature`, `class CaptureQueue`, `const Set<String> kSkyLitOutdoors`.

- [ ] **Step 1: Write the failing tests** (`test/math/light_probes_test.dart`)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/math/floor_plan.dart';
import 'package:flutter_3d/math/light_probes.dart';
import 'package:flutter_3d/math/occlusion.dart';

bool inside(ProbeBox b, Vector3 p) =>
    (p.x - b.center.x).abs() <= b.halfExtents.x &&
    (p.y - b.center.y).abs() <= b.halfExtents.y &&
    (p.z - b.center.z).abs() <= b.halfExtents.z;

void main() {
  final boxes = roomProbeBoxes();
  final bedroom = boxes.firstWhere((b) => b.priority == 10);
  final bath = boxes.firstWhere((b) => b.priority == 20);

  test('the bedroom box covers the room; the bathroom box, its cell, wins inside it', () {
    for (final p in [Vector3(-7.9, 0.1, 5.9), Vector3(-0.1, 2.7, 0.1), Vector3(-4, 1.6, 3)]) {
      expect(inside(bedroom, p), isTrue, reason: '$p');
    }
    for (final p in [Vector3(-6.8, 1.6, 0.55), Vector3(-7.9, 0.1, 0.1), Vector3(-5.3, 2.7, 2.5)]) {
      expect(inside(bath, p), isTrue, reason: '$p');
      expect(cellOf(p), Cell.bathA, reason: '$p');
    }
    expect(inside(bath, Vector3(-4, 1.6, 1.5)), isFalse, reason: 'the bedroom by the desk');
    expect(bath.priority, greaterThan(bedroom.priority));
  });

  test('the balcony is outside every box: it stays sky-lit', () {
    final balcony = Vector3(-3, FloorPlan.eyeHeight, 7.3);
    expect(boxes.any((b) => inside(b, balcony)), isFalse);
  });

  group('LightingSignature', () {
    final sky = Object();
    final base = LightingSignature(timeOfDay: 15, weather: 0, sky: sky, revision: 0);
    test('time, a switch or a new sky is a change', () {
      expect(LightingSignature(timeOfDay: 16, weather: 0, sky: sky, revision: 0).differsFrom(base), isTrue);
      expect(LightingSignature(timeOfDay: 15, weather: 0, sky: sky, revision: 1).differsFrom(base), isTrue);
      expect(LightingSignature(timeOfDay: 15, weather: 0, sky: Object(), revision: 0).differsFrom(base), isTrue);
      expect(LightingSignature(timeOfDay: 15, weather: 0, sky: sky, revision: 0).differsFrom(base), isFalse);
    });
    test('slowly building rain counts once it has moved 0.05 in total', () {
      var last = base;
      var changes = 0;
      for (var w = 0.01; w <= 0.2; w += 0.01) {
        final now = LightingSignature(timeOfDay: 15, weather: w, sky: sky, revision: 0);
        if (now.differsFrom(last)) {
          changes++;
          last = now; // the feature keeps the signature it last re-captured for
        }
      }
      expect(changes, greaterThanOrEqualTo(3));
    });
  });

  group('CaptureQueue', () {
    test('one probe per frame behind a hold, released after the last', () {
      final q = CaptureQueue(4)..start();
      final steps = [for (var i = 0; i < 5; i++) q.step()];
      expect([for (final s in steps) s.capture], [0, 1, 2, 3, null]);
      expect([for (final s in steps) s.hold], [true, true, true, true, false]);
      expect(q.busy, isFalse);
    });
    test('cancel mid-pass releases the hold at once', () {
      final q = CaptureQueue(4)..start();
      q.step();
      q.cancel();
      final s = q.step();
      expect(s.capture, isNull);
      expect(s.hold, isFalse);
    });
    test('restarting mid-pass starts over', () {
      final q = CaptureQueue(4)..start();
      q.step();
      q.step();
      q.start();
      expect(q.step().capture, 0);
    });
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `fvm flutter test test/math/light_probes_test.dart`
Expected: compile error, `light_probes.dart` doesn't exist.

- [ ] **Step 3: Implement the pure part** (`lib/math/light_probes.dart`)

```dart
import 'package:vector_math/vector_math.dart';
import 'floor_plan.dart';

/// A reflection probe's box in room A's frame: centre, half-extents, and the
/// priority that decides which box wins where they overlap.
typedef ProbeBox = ({Vector3 center, Vector3 halfExtents, double priority});

/// Room A's probe boxes, floor to ceiling: the whole bedroom footprint, and
/// the bathroom cell at a higher priority so it wins inside itself. Room B
/// gets the same boxes mirrored through its parent.
List<ProbeBox> roomProbeBoxes() {
  const h = FloorPlan.ceiling / 2;
  return [
    (
      center: Vector3(-FloorPlan.roomWidth / 2, h, FloorPlan.roomDepth / 2),
      halfExtents: Vector3(FloorPlan.roomWidth / 2, h, FloorPlan.roomDepth / 2),
      priority: 10.0,
    ),
    (
      center: Vector3((-FloorPlan.roomWidth + FloorPlan.bathX1) / 2, h, FloorPlan.bathZ1 / 2),
      halfExtents: Vector3((FloorPlan.bathX1 + FloorPlan.roomWidth) / 2, h, FloorPlan.bathZ1 / 2),
      priority: 20.0,
    ),
  ];
}

/// What the probes' captured lighting depends on. A change means re-capture
/// once things settle.
class LightingSignature {
  LightingSignature({
    required this.timeOfDay,
    required this.weather,
    required this.sky,
    required this.revision,
  });

  final double timeOfDay, weather;

  /// The sky's environment object: a new one means the sky was rebuilt.
  final Object? sky;

  /// `HotelContext.lightingRevision`: bumped by light switches.
  final int revision;

  /// Whether the lighting changed enough since [before] (the signature last
  /// re-captured for) to re-capture: any time or switch change, a new sky,
  /// or weather that has moved more than 0.05 in total.
  bool differsFrom(LightingSignature before) =>
      timeOfDay != before.timeOfDay ||
      revision != before.revision ||
      !identical(sky, before.sky) ||
      (weather - before.weather).abs() > 0.05;
}

/// Re-captures [count] probes, one per frame. [step] says which probe to
/// capture this frame (null for none) and whether occlusion must be held for
/// this frame's render.
class CaptureQueue {
  CaptureQueue(this.count);

  final int count;
  int _next = -1;

  bool get busy => _next >= 0;

  /// Starts (or restarts) a pass over every probe.
  void start() => _next = 0;

  /// Stops the pass; the next [step] releases the hold.
  void cancel() => _next = -1;

  ({int? capture, bool hold}) step() {
    if (_next < 0 || _next >= count) {
      _next = -1;
      return (capture: null, hold: false);
    }
    return (capture: _next++, hold: true);
  }
}
```

- [ ] **Step 4: Run the pure tests**

Run: `fvm flutter test test/math/light_probes_test.dart`
Expected: pass.

- [ ] **Step 5: Implement the feature** (replace the skeleton)

```dart
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import '../math/light_probes.dart';
import '../math/schedulers.dart';
import 'occlusion_feature.dart' show roomContentsRoot;

/// Outdoor scene-root nodes that must stay lit by the sky. The engine applies
/// a room probe to the whole frame by camera position, so without this the
/// sea would reflect the bedroom.
const Set<String> kSkyLitOutdoors = {
  'sea', 'sea_horizon_0', 'sea_horizon_1', 'sea_horizon_2', 'beach', 'shore',
  'hotel_facade', 'beach_palms', 'beach_umbrellas',
};

const int kProbeFaceResolution = 128;

Iterable<Material> _materialsOf(Node n) sync* {
  for (final p in n.mesh?.primitives ?? const <MeshPrimitive>[]) {
    yield p.material;
  }
  final batch = n.getComponent<InstancedMeshComponent>();
  if (batch != null) yield batch.instancedMesh.material;
}

void _setEnvironment(Material m, EnvironmentMap? env) {
  if (m is PhysicallyBasedMaterial) m.environment = env;
  if (m is PreprocessedMaterial) m.environment = env;
}

/// Baked light probes: each bedroom and bathroom captures its own lighting
/// (a 6-face snapshot) as its ambient light and box-corrected reflections.
/// It re-captures 0.5 s after the time, lights, weather or sky settle, one
/// probe per frame, holding occlusion culling off so each capture sees the
/// whole room.
class LightProbesFeature extends HotelFeature {
  @override
  String get id => 'light_probes';
  @override
  String get label => 'Baked light probes (room ambient + reflections)';
  @override
  CostTier get tier => CostTier.cheap;

  final List<Node> _nodes = [];
  final List<ReflectionProbeComponent> _probes = [];
  final SettleTimer _settle = SettleTimer();
  CaptureQueue _queue = CaptureQueue(0);
  bool _holding = false;
  LightingSignature? _last;
  EnvironmentSettings? _base;
  final Set<Material> _pinned = {};

  LightingSignature _signature(HotelContext ctx) => LightingSignature(
        timeOfDay: ctx.timeOfDay.value,
        weather: ctx.weather,
        sky: ctx.look.skyEnvironment,
        revision: ctx.lightingRevision.value,
      );

  @override
  Future<void> mount(HotelContext ctx) async {
    for (final room in ctx.rooms.values) {
      for (final box in roomProbeBoxes()) {
        final probe = ReflectionProbeComponent(
          extents: box.halfExtents.clone(),
          blendDistance: 0.3,
          priority: box.priority,
          faceResolution: kProbeFaceResolution,
          captureOnActivate: false, // captured behind an occlusion hold instead
        );
        final node = Node(name: 'light_probe', localTransform: Matrix4.translation(box.center))
          ..addComponent(probe);
        roomContentsRoot(room).add(node);
        _nodes.add(node);
        _probes.add(probe);
      }
    }
    _queue = CaptureQueue(_probes.length)..start();
    _last = _signature(ctx);
  }

  @override
  void tick(HotelContext ctx, double dt) {
    final now = _signature(ctx);
    final last = _last;
    if (last == null || now.differsFrom(last)) {
      _last = now;
      _settle.markDirty();
    }
    if (_settle.tick(dt)) _queue.start();
    final step = _queue.step();
    _setHold(ctx, step.hold);
    final i = step.capture;
    if (i != null) _probes[i].requestCapture();
    _followSky(ctx);
  }

  void _setHold(HotelContext ctx, bool hold) {
    if (hold == _holding) return;
    ctx.occlusionHolds += hold ? 1 : -1;
    _holding = hold;
  }

  /// Keeps a base-environment snapshot of the sky (the engine refreshes its
  /// `environment` on every sky re-bake) and pins the outdoor materials to it.
  void _followSky(HotelContext ctx) {
    final sky = ctx.look.skyEnvironment;
    if (sky == null) {
      // Sky switched off: a stale snapshot would keep lighting the scene.
      _unpin();
      if (_base != null) ctx.scene.baseEnvironment = null;
      _base = null;
      return;
    }
    var base = _base;
    if (base == null || !identical(base.skyEnvironment, sky)) {
      base = _base = EnvironmentSettings(skyEnvironment: sky, environment: ctx.scene.environment);
      ctx.scene.baseEnvironment = base;
      sky.invalidate(); // re-bake now, so the snapshot holds this sky's light
    }
    final env = base.environment;
    final current = <Material>{
      for (final n in ctx.scene.root.children)
        if (kSkyLitOutdoors.contains(n.name)) ..._materialsOf(n),
    };
    for (final m in _pinned.difference(current)) {
      _setEnvironment(m, null);
    }
    for (final m in current) {
      _setEnvironment(m, env);
    }
    _pinned
      ..clear()
      ..addAll(current);
  }

  void _unpin() {
    for (final m in _pinned) {
      _setEnvironment(m, null);
    }
    _pinned.clear();
  }

  @override
  void unmount(HotelContext ctx) {
    _queue.cancel();
    _setHold(ctx, false);
    for (final n in _nodes) {
      n.parent?.remove(n);
    }
    _nodes.clear();
    _probes.clear();
    _unpin();
    final base = _base;
    if (base != null) {
      // Leave the sky's light in place of whichever probe was in charge.
      final env = base.environment;
      if (env != null) ctx.scene.environment = env;
      ctx.scene.baseEnvironment = null;
    }
    _base = null;
    _last = null;
  }
}
```

- [ ] **Step 6: Run the tests and the analyzer**

Run: `fvm flutter test && fvm flutter analyze lib test`
Expected: pass; no issues. If a name differs in the engine (for example `EnvironmentSettings`' constructor parameters, or `PreprocessedMaterial.environment`), read the pub-cache source (`~/.pub-cache/hosted/pub.dev/flutter_scene-0.23.0/lib/src/`) and use the real name. Say so in your report.

- [ ] **Step 7: Smoke-run on a simulator nobody else is using.** Boot one with `xcrun simctl boot <udid>`, then run `fvm flutter run --enable-flutter-gpu -d <udid>`. In the Effects sheet, switch **Baked light probes** on and off and check:
  - the bedroom gets a little darker and warmer than the balcony;
  - glossy surfaces (parquet, brass, tiles) reflect the room;
  - the sea, seen from the window, doesn't reflect the room;
  - switching it off returns the look to exactly what it was.

  Take screenshots with `xcrun simctl io <udid> screenshot`. Report what you saw.

- [ ] **Step 8: Commit**

```bash
git add lib/math/light_probes.dart lib/features/light_probes_feature.dart test/math/light_probes_test.dart
git commit -m "feat(lighting): baked per-room light probes that re-capture once lighting settles"
```

### Task 12: Dynamic GI (Lumen-lite)

**Files:**
- Replace: `lib/features/dynamic_gi_feature.dart`
- Create: `test/features/dynamic_gi_test.dart`

**Interfaces:**
- Consumes: `LookState.dynamicGi`, `kGiVisibilityBias` (Task 2), `IrradianceVolumeComponent`.
- Produces: `final Vector3 kGiCenter, kGiHalfExtents, kGiResolution`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/features/dynamic_gi_feature.dart';
import 'package:flutter_3d/hotel/look.dart';
import 'package:flutter_3d/math/floor_plan.dart';

void main() {
  final lo = kGiCenter - kGiHalfExtents, hi = kGiCenter + kGiHalfExtents;

  test('the grid covers both rooms and balconies, floor to ceiling', () {
    const rail = FloorPlan.roomDepth + FloorPlan.balconyDepth;
    expect(lo.x, lessThanOrEqualTo(-FloorPlan.roomWidth));
    expect(hi.x, greaterThanOrEqualTo(FloorPlan.roomWidth));
    expect(lo.z, lessThanOrEqualTo(0));
    expect(hi.z, greaterThanOrEqualTo(rail));
    expect(lo.y, lessThanOrEqualTo(0));
    expect(hi.y, greaterThanOrEqualTo(FloorPlan.ceiling));
  });

  test('probes about every 1.5 m or closer, and a leak bias under the thinnest wall', () {
    final spacing = Vector3(
      2 * kGiHalfExtents.x / (kGiResolution.x - 1),
      2 * kGiHalfExtents.y / (kGiResolution.y - 1),
      2 * kGiHalfExtents.z / (kGiResolution.z - 1),
    );
    for (final s in [spacing.x, spacing.y, spacing.z]) {
      expect(s, lessThanOrEqualTo(1.6));
    }
    final smallest = [spacing.x, spacing.y, spacing.z].reduce((a, b) => a < b ? a : b);
    expect(kGiVisibilityBias * smallest, lessThan(0.06), reason: 'the 6 cm bathroom wall');
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `fvm flutter test test/features/dynamic_gi_test.dart`
Expected: compile error, `kGiCenter` isn't defined.

- [ ] **Step 3: Implement** (replace the skeleton)

```dart
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import '../math/floor_plan.dart';

const double _depth = FloorPlan.roomDepth + FloorPlan.balconyDepth + FloorPlan.wallT;

/// The live probe grid's box: both rooms and balconies, floor to ceiling.
final Vector3 kGiCenter = Vector3(0, FloorPlan.ceiling / 2, _depth / 2);
final Vector3 kGiHalfExtents =
    Vector3(FloorPlan.roomWidth + FloorPlan.wallT, FloorPlan.ceiling / 2 + 0.1, _depth / 2);

/// 12 × 4 × 7 probes: about 1.5, 1.0 and 1.3 m apart.
final Vector3 kGiResolution = Vector3(12, 4, 7);

/// Dynamic GI ("Lumen-lite"): the engine's irradiance field, a light-probe
/// grid fed from each rendered frame and converging over a few frames, so
/// bounce light follows the sun, lamps and reading lights. With the baked
/// light probes on, this owns the diffuse term and the probes keep the
/// reflections. The settings live in composeLook.
class DynamicGiFeature extends HotelFeature {
  @override
  String get id => 'dynamic_gi';
  @override
  String get label => 'Dynamic GI (Lumen-lite probe grid)';
  @override
  CostTier get tier => CostTier.expensive;
  @override
  bool get defaultOn => false;

  Node? _volume;

  @override
  Future<void> mount(HotelContext ctx) async {
    final volume = _volume = Node(name: 'gi_volume', localTransform: Matrix4.translation(kGiCenter))
      ..addComponent(IrradianceVolumeComponent(
        extents: kGiHalfExtents.clone(),
        resolution: kGiResolution.clone(),
      ));
    ctx.scene.add(volume);
    ctx.look.dynamicGi = true;
    ctx.applyLook();
  }

  @override
  void unmount(HotelContext ctx) {
    final volume = _volume;
    if (volume != null) ctx.scene.remove(volume);
    _volume = null;
    ctx.look.dynamicGi = false;
    ctx.applyLook();
  }
}
```

- [ ] **Step 4: Run the tests and the analyzer**

Run: `fvm flutter test test/features/dynamic_gi_test.dart && fvm flutter analyze lib test`
Expected: pass; no issues.

- [ ] **Step 5: Smoke-run** on a free simulator. Switch **Dynamic GI** on, wait a few seconds for it to converge, then look into a corner and at the ceiling near the window. There should be soft bounce light and no bright patches bleeding through walls. Screenshot and report, noting any leaks through the bathroom walls.

- [ ] **Step 6: Commit**

```bash
git add lib/features/dynamic_gi_feature.dart test/features/dynamic_gi_test.dart
git commit -m "feat(lighting): dynamic GI, a live light-probe grid over both rooms"
```

---

## Wave C: verification and tuning (one agent, after Wave B is merged)

### Task 13: Screenshot A/B for every toggle, tuning, learnings

**Files:**
- Create: `tool/ab_capture.sh`, `tool/pair_diff.py`
- Modify (tuning only, if the screenshots call for it): the constants in `lib/hotel/look.dart`, `lib/features/area_lights_feature.dart`, `lib/features/spot_lights_feature.dart` and `lib/features/dynamic_gi_feature.dart`
- Modify: `learning.md`

**Interfaces:**
- Consumes: the perf probe (`lib/hotel/perf_probe.dart`). `--dart-define=HOTEL_PERF=true --dart-define=HOTEL_PERF_AB=<id>` holds each of the 12 stops with feature `<id>` off, then on. It prints `hotel perf: hold <stop> [<id> off|on]` when a pose has settled, and `hotel perf: done` at the end.

- [ ] **Step 1: Add the capture script** (`tool/ab_capture.sh`, `chmod +x`)

```bash
#!/bin/zsh
# Usage: tool/ab_capture.sh <simulator-udid> <feature-id> <out-dir> [preset]
# Screenshots every perf-probe hold: each stop with <feature-id> off, then on.
dev=$1; id=$2; out=$3; preset=${4:-ultra}; log=$out/run.log
mkdir -p $out; rm -f $out/*.png
fvm flutter run -d $dev --enable-flutter-gpu --dart-define=HOTEL_PERF=true \
  --dart-define=HOTEL_PERF_AB=$id --dart-define=HOTEL_PRESET=$preset \
  --pid-file $out/app.pid > $log 2>&1 &
seen=0; i=0
while ! grep -q 'hotel perf: done' $log 2>/dev/null; do
  n=$(grep -c 'hotel perf: hold' $log 2>/dev/null)
  if [ "$n" -gt "$seen" ]; then
    seen=$n; i=$((i+1)); sleep 1.2
    name=$(grep 'hotel perf: hold' $log | tail -1 | sed 's/.*hold //; s/[^A-Za-z0-9]\{1,\}/_/g')
    xcrun simctl io $dev screenshot "$out/$(printf %02d $i)-$name.png" >/dev/null 2>&1
  fi
  sleep 0.3
done
kill $(cat $out/app.pid) 2>/dev/null
echo "captured $i screenshots in $out"
```

- [ ] **Step 2: Add the diff script** (`tool/pair_diff.py`; needs Pillow and numpy, so use a throwaway venv: `python3 -m venv /tmp/abenv && /tmp/abenv/bin/pip install pillow numpy`)

```python
"""Diffs each (<id> off, <id> on) screenshot pair from tool/ab_capture.sh.

Usage: python tool/pair_diff.py <out-dir> <feature-id>
Prints, per stop: mean |ΔRGB|, the % of pixels that changed by more than 24,
and the changed region. The HUD (top-left) is masked: its numbers change
every frame.
"""
import glob, os, sys
import numpy as np
from PIL import Image

d, fid = sys.argv[1], sys.argv[2]
files = sorted(glob.glob(os.path.join(d, '*.png')))
for off in [f for f in files if f'{fid}_off' in f]:
    on = [f for f in files if f[len(d) + 4:] == off[len(d) + 4:].replace(f'{fid}_off', f'{fid}_on')]
    if not on:
        print('missing pair for', off)
        continue
    a = np.asarray(Image.open(off).convert('RGB')).astype(int)
    b = np.asarray(Image.open(on[0]).convert('RGB')).astype(int)
    diff = np.abs(a - b).max(axis=2)
    h, w = diff.shape
    diff[: int(h * 0.16), : int(w * 0.5)] = 0
    ys, xs = np.nonzero(diff > 24)
    where = f'rows {ys.min()}-{ys.max()} cols {xs.min()}-{xs.max()}' if len(ys) else ''
    print(f'{os.path.basename(off)[3:]:<60} mean {diff.mean():5.2f}  >24: {(diff > 24).mean() * 100:5.2f}%  {where}')
```

- [ ] **Step 3: Capture every toggle.** Use a simulator that no other session is using, and check with `xcrun simctl list devices booted` plus `ps` for a running `Runner`. For each id in `light_probes dynamic_gi auto_exposure static_shadows fxaa smaa taa spot_lights area_lights volumetric_fog`:

Run: `tool/ab_capture.sh <udid> <id> /tmp/ab/<id> && /tmp/abenv/bin/python tool/pair_diff.py /tmp/ab/<id> <id>`

| Toggle | Expected |
|---|---|
| `light_probes` | Changes indoors (darker room ambient, glossy surfaces reflecting the room). The balcony stop's sea is unchanged. |
| `dynamic_gi` | Softer bounce light in corners. No bright leaks through walls, bathroom included. |
| `auto_exposure` | The room is slightly brighter, the balcony slightly darker. The first frame after each stop isn't still ramping, since teleports snap. |
| `static_shadows` | **Identical images** (a pure performance change). Any difference is a stale shadow and a bug. |
| `fxaa`, `smaa`, `taa` | Softened edges only (compare 3× crops of an edge). With `taa`, check the rain stop for particle ghosting; if it ghosts, record it and keep TAA out of presets. |
| `spot_lights` | The bed and pillows are lit warmly, with a shadow of the headboard. |
| `area_lights` | A soft TV glow at the TV stop. By day the window side of the room is brighter; at 21:00–22:00 the window light is nearly nothing. |
| `volumetric_fog` | Mist over the sea from the window and balcony stops, a glow toward the sun, and shafts only where sunlight comes through gaps. The rooms themselves stay clear. |

- [ ] **Step 4: Prove occlusion is still invisible with probes on**

Run: `tool/ab_capture.sh <udid> occlusion /tmp/ab/occlusion ultra && /tmp/abenv/bin/python tool/pair_diff.py /tmp/ab/occlusion occlusion`
Expected: every stop reads `mean 0.00 >24: 0.00%`, apart from the simulator status bar (the top rows) and the rain stop, where lightning is random. If a room stop differs, a probe captured with occlusion still hiding things: check that `occlusionHolds` is above zero during captures.

- [ ] **Step 5: Tune.** Adjust only the constants named under Files, and re-run the affected toggle after each change:
  - fog density and falloff;
  - window-light and TV-glow intensities;
  - reading-light intensity and cone;
  - `kGiVisibility` and `kGiVisibilityBias`.

  Commit each tuning change with the before/after numbers in the message.

- [ ] **Step 6: Prices, if a device is free.** Run a profile sweep and paste the `hotel perf:` lines into your report:

```
fvm flutter run --profile -d <device> --enable-flutter-gpu --dart-define=HOTEL_PERF=true \
  --dart-define=HOTEL_PERF_SWEEP=true
```

If no device is free, say so; don't use the shared Mac's numbers as prices.

- [ ] **Step 7: Learnings.** Append entries to `learning.md` in its existing format for everything non-obvious that you and the Wave B reports found.

- [ ] **Step 8: Run everything, then commit**

```bash
fvm flutter analyze lib test && fvm flutter test
git add tool/ab_capture.sh tool/pair_diff.py learning.md lib/hotel/look.dart \
  lib/features/area_lights_feature.dart lib/features/spot_lights_feature.dart lib/features/dynamic_gi_feature.dart
git commit -m "chore(lighting): A/B capture tools, tuning and learnings for the lighting toggles"
```
