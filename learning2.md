# flutter_scene 0.23.0 → 0.24.0: what changed, what we did, what we learned

Written 2026-10-06 on branch `flutter-scene-0.24` (HEAD `4c155cf`). Companion to `learning.md`, which keeps the per-task entries in full. This file is the 0.23 vs 0.24 comparison.

**How to read the evidence labels**

| Label | Meaning |
|---|---|
| **Source** | Read from the 0.24.0 changelog or package source in `~/.pub-cache/hosted/pub.dev/flutter_scene-0.24.0/`. Not run by us. |
| **Observed (macOS)** | Seen in a macOS debug run, frames captured through the widget inspector. |
| **Observed (iPhone)** | Seen on the iPhone 17 Pro Max, **debug build**. |
| **Not observed** | Written down but not seen by anyone yet. |

The iOS simulator returns all-black screenshots on this machine, so none of the visual evidence comes from it.

**What this file does not contain: a 0.23 vs 0.24 performance comparison.** No frame-rate or GPU-time number was captured on 0.23 in this work, and every 0.24 number we have is from a debug build. Representative numbers need a profile or release build on a device, which you run yourself.

---

## 1. Differences that change behaviour (0.23 → 0.24)

### 1.1 Frame pacing changes what "fps" means

| | 0.23 | 0.24 |
|---|---|---|
| GPU behind | UI thread blocks waiting on the GPU (the `semaphore_wait_trap` seen in `learning.md`). | `Scene.maxGpuFramesInFlight` (default 1) re-presents the previous image instead of blocking. `Scene.pacedFrameCount` counts held frames. **Source** |
| Flutter fps vs scene fps | Same thing. | Different. Flutter keeps producing frames while the scene re-draws its old image. |
| Draw counter | None. The HUD walked the graph to count meshes and could not see `InstancedMesh`. `perf_probe.dart` re-derived draws by hand. | `Scene.renderStats` with draws, instances, vertices, culled and batches per pass. **Source** |

**Learned the hard way (Observed, Task 3):**
- `renderStats.frameCount` **also counts paced frames**, because pacing happens after `beginFrame`. On the simulator the HUD counters read `flutter=644 fc=643 paced=320`.
- `renderStats.latest` is an **empty frame** (no views, 0 draws) whenever the frame was paced.
- So scene fps is `frameCount - pacedFrameCount` over time, and draws come from the newest recent frame that has an on-screen view. Both are in `lib/ui/hud.dart` (`renderedFrameCount`, `lastOnScreenFrame`) and feed `SceneFrameMeter`.
- Reading `frameCount` straight would have shown the Flutter rate, which is the number 0.24's pacing makes meaningless.

The plan's constraint text said "from `renderStats.frameCount`". The implementation deviates on purpose (ledger ruling), and the docs task should describe it.

**On the iPhone (debug build, readouts only, no conclusions):** the island HUD showed 20–41 scene fps and the Effects sheet 62–64 flutter fps beside 21–26 scene fps; Home Demo showed 32–38 scene fps beside 96–119 flutter fps. The gap between the two rates is the pacing at work. It is not a regression figure.

### 1.2 Fragment precision (silent, Source)

- 0.24 compiles material fragments at `mediump`. On Mali, Adreno and the web that is half precision (10-bit mantissa, max 65504). Metal ignores the qualifier, so it never shows on iOS or macOS.
- Our 10 `.fmat` files compute world positions, wave phases, hashes and caustic coordinates, so each now opens its fragment body with `precision highp float;`. `test/materials/fmat_precision_test.dart` enforces it for every file in `assets/materials/`, including the one added later (`decal_ground.fmat`).
- **Not observed:** the bug itself. It needs a real Mali or Adreno GPU, and none of our runs used one.

### 1.3 Material system

| Topic | 0.23 workaround | 0.24 | Result here |
|---|---|---|---|
| `engine_inputs: [scene_color]` | Needed a **lit** shading model, so rain glass and heat haze were "lit with albedo, specular and roughness zeroed". | Unlit `.fmat` may declare `scene_color`. **Source**, checked by compile test. | Both are now `unlit`; refracted colour goes straight into `base_color`. |
| Scene-colour captures | Every reader got its own full-screen copy. | `scene_color_reach:` lets non-overlapping readers share one capture; `Scene.sceneColorCaptureBatches` caps captures per frame. | `rain_glass` reach 0.1, `heat_haze` reach 0.2. |
| Vertex stage | No model transform, so `page_curl` rebuilt a basis from the tangent and `heat_haze` required a translation-only node. | `vertex.model_transform`. | Both rewritten; the haze may now sit under a rotated or scaled parent. |
| `planar_reflection` | Lit only. | **Still lit only** (parser rejects unlit). | `mirror.fmat` and `ocean.fmat` stay lit. |
| Material swap on a mounted node | `node.mesh = mesh.clone()`. | Unchanged; `refreshMaterials()` is still `@internal`. | Workaround kept. |
| New `.fmat` picked up by the build hook | Needed `.dart_tool/hooks_runner` deleted. | Claimed fixed. | **Observed (macOS, one run):** adding `decal_ground.fmat` loaded without clearing the cache, and the log had neither `No generated` nor `keeping the previous shaders`. |

**Not observed by eye on the simulator or macOS for Task 4:** rain-glass refraction, heat-haze facing and the page-curl direction, until the device run. **Observed (iPhone):** rain streaks on a grey sky (not black), the haze above the fire from four azimuths, and a page curl captured mid-turn. A side-by-side with the 0.23 look was not done.

### 1.4 Look changes without an error (Source unless noted)

| Change | What we did | What we saw |
|---|---|---|
| IBL multiscatter fix: rough and partly metallic surfaces get darker. | Nothing. The call on whether to re-grade is yours. | No before/after captured. |
| Bloom rewritten; `scatter` weights wider mips; `fireflySuppression` on by default. | Tried turning suppression off for the lightning bolt. **Not added.** | **Observed (macOS):** 6 held strikes, on vs off, differed by 0.1–3% in near-white pixels and looked the same by eye. The engine default (on) stays. |
| `WidgetComponent` display-referred by default. | Both Pokédex pages pass `displayReferred: false`. | **Observed (macOS):** with `false`, page luminance was 141 at 15:00 and 244 at 22:00 (default: 252.8 at both). The plan expected the pages to **dim** at night. They did not: they follow auto exposure, so the page is dull grey at 15:00 with the window in frame and brighter at night. **Needs your judgement on a device.** The pages were showing "Couldn't load" (no PokeAPI data) when measured. |
| `hint: default_black` samples black instead of white. | Nothing; the rigs bind their textures at build. | Not observed. |
| Reversed depth and fitted near plane on Metal. | `findCoplanarOverlaps` list recorded for Task 10. | **Observed (macOS):** the hotel reports 5 overlap rows (11, 9 or 10 overlaps depending on state); the island reports none. See `docs/superpowers/notes/2026-10-06-coplanar-overlaps.md`. |

### 1.5 Fixes that arrive with no code change (Source only)

None of these were exercised on a real Android or Mali device.
- Unchanged light textures are no longer re-uploaded; froxel clustering replaces the per-object light cap.
- Unlit materials drew nothing on Impeller Vulkan (this would have hidden the Pokédex pages on a real Android phone). Fixed.
- GLES MSAA→other anti-aliasing depth bug, iOS 26+ lit-plus-directional-shadow crash (#436), Vulkan cached-shadow crash, Mali/Adreno shadow striping. Fixed.
- No `discard` on opaque materials (early-Z and HSR stay on).
- Sliced `warmUp`, wall-clock `onTick` deltas, static `InstancedMesh` kept on the GPU, one shadow cascade rendered per frame.
- Normals use the inverse-transpose (non-uniform scale lights correctly).
- Shadow atlas caps shadowed spots and points at 4 each, with `shadowCasterOverflowCount` to report it. **Observed (iPhone):** `shadowCasterOverflowCount` was 0 at 10:30, 21:30 and 01:30, with fire shadows on and off.

### 1.6 Still broken in 0.24 (workarounds kept)

Material swap via `mesh.clone()`; `skyAt()` sun/moon handling; the `WidgetComponent` lookAt-then-mirror trick; pausing with `TickerMode` rather than `SceneView(autoTick:)`; analytic rain collision proxies; lit `mirror` and `ocean`; the Kenney `.glb` pruning rules. All **Source**: the 0.24 files that matter are unchanged.

---

## 2. New 0.24 features we adopted, and what each showed

| Feature | Where | Evidence |
|---|---|---|
| **Point-light shadows** | Campfire in Ultra and Super Ultra; menu switch `Campfire shadows`. | **Observed (macOS):** HUD draws 200 → 278 with it on (cost to price on a device, not a frame-rate result). **Observed (iPhone):** one framing 217 → 144 draws with it off; ground lighting behind palm trunks breaks up with shadows on. **Not observed:** a clean shadow on the character (camera too close, ground black at night). |
| **Surface debug views** (`Scene.debug`) | 🔍 X-ray button: wireframe, normals, base colour wipes. | **Observed (macOS and iPhone):** four real taps cycle the modes; the **debug channel is on the right** of the split, the lit image on the left, and the debug side skips fog and tone curve. In the **base-colour wipe the sea and sky render black on both macOS and the iPhone**. Cause not investigated. |
| **Box decals** | Scorch ring and 12 footprints in Super Ultra. | **Observed (macOS):** ring conforms to dirt and grass edge, no z-fighting, 12-node pool held over a 7.5 m walk. **Observed (iPhone):** `visiblePrints` 0 → 3 → 6 → 9 → 12, back to 0 about 8 s after the last step, none while standing. **Not observed on the iPhone:** footprints on grass, or the ring distinct from the fire-pit geometry. First draw compiles `decal_ground` mid-frame (356 ms on macOS) and is not preloaded. |
| **Adaptive render scale** | `Auto` pick: target 60 fps, floor 0.6, ceiling 1.0. | **Observed (iPhone):** adaptive true; readout "64 flutter fps · 21 scene fps · 85%". Fixed 85% stays the default so measurements stay reproducible. |
| **`SceneView(maxFrameRate:)`** | `Uncapped` / `60 fps` pick. | **Observed:** the value reaches the `SceneView`. **Not observed:** any effect on frame rate. |
| **`sceneColorCaptureBatches`** | `Separate` / `Shared` pick. | **Observed (iPhone):** 1 when Shared, null otherwise; sea intact in the framings reached. **Not observed:** the case this was feared to break, the sea vanishing behind the heat haze when they overlap. |
| **GPU pacing depth** | `1 frame` / `2 frames` pick (island), `gpu_pacing_2` feature (hotel). | **Observed (iPhone):** `maxGpuFramesInFlight` becomes 2. Effect on rate not measured. |
| **`releaseTransientRenderTargets()`** | Called once when `AppShell` hides a 3D tab. | **Observed (macOS):** 369 MB released once per Island→Home hide, three hides gave three lines. **Observed (iPhone):** 1055.0 MB (Island→Home), 607.1 MB (Island→Home Demo), 370.8 MB (leaving Home Demo); each hide logged once; the island rendered again within 1.5 s with no "multiple tickers" error or red screen. Whether the switch hitches cannot be seen from screenshots. |

---

## 3. Things the plan assumed that turned out wrong

1. **"`renderStats.frameCount` counts frames the scene rendered."** It counts paced frames too (see 1.1).
2. **"Set `campfireLight.castsShadow` at the top of `_applyEnvironmentSettings`."** That function runs during `load()` before the campfire exists, so the island crashed on load with `LateInitializationError`. Fixed with a `_campfireBuilt` flag and a helper the light's builder also calls.
3. **"Pages dim with the room at 22:00 with `displayReferred: false`."** They follow auto exposure instead (see 1.4).
4. **"Footprint test: 3 m at 0.5 m strides gives 6 prints."** Only with a 3 cm first step (`firstStep`); otherwise 5.
5. **"App-shell test expects `[island, island]`."** The callback fires on every hide, and `releaseHiddenTab` is what ignores Home, so the test expects `[home, island, home, island]`.
6. **"The simulator is where agents verify looks."** On this machine it returns all-black screenshots. Real frames came from macOS (and later the iPhone) through the widget inspector: `ext.flutter.inspector.screenshot`, after `getRootWidget` for a `valueId`.

## 4. Tooling notes worth keeping

- **Driving a Flutter button over the VM service:** `WidgetsBinding.instance.handlePointerEvent` with **mouse-kind** events and real timestamps (`PointerDownEvent` then `PointerUpEvent` about 60 ms later, a fresh `pointer` id per tap). Touch-kind events with zero timestamps leave stuck pointers.
- **A covered macOS window stops presenting frames**, so a screenshot can be an old frame. Keep the window frontmost.
- **Disk:** a physical-device iOS build filled the data volume once and every tool call, including the shell, began failing with `ENOSPC`. Check free space before a device build.
- After visiting Home Demo, one iPhone inspector screenshot came back 1320x1972 with the app in the left ~70% and white on the right. It looks like a capture quirk, not an app bug.

## 5. Open items and what is not done

**Not started:** Hotel lane (Task 9: light radii, bath-light point shadow, spot shadow budget, `warmUp`/`preload`, GI probe view, `render_scale_auto`; Task 10: z-fighting fixes using the overlap list) and Task 11 (docs). So **the hotel does not yet use the 0.24 features** the spec lists for it; it only has Task 1–4 changes (highp materials, unlit rain glass, honest HUD, `gpu_pacing_2`).

**Open questions, none blocking:**
- Base-colour X-ray wipe shows the sea black on every platform tried. Why?
- Pokédex pages read dull grey at 15:00. Is that acceptable on a device, or does the view need a different exposure?
- Does `Shared` scene copies hide the sea when the haze overlaps it? (Not exercised.)
- Auto render scale leaves `adaptiveTiers` at its default, so Auto plus Separate copies may quietly behave like Shared on a slow device. (Review note, not tested.)
- First Super Ultra draw has a one-off decal pipeline compile. Preload it?
- Mali/Adreno precision, Android emulator tour and the Android anti-aliasing picker: not run in this work.

**Left for you:** every performance comparison between 0.23 and 0.24 (profile or release build on a device), the re-grade decision after the IBL and bloom changes, and the call on the Pokédex page brightness.

## 6. Where the detail lives

- Per-task findings with commands: `learning.md` (entries titled "flutter_scene 0.24 upgrade, Task N").
- Design and the full changelog-vs-source tables: `docs/superpowers/specs/2026-10-06-flutter-scene-0.24-design.md`.
- Plan with ticked steps and notes on what was not observed: `docs/superpowers/plans/2026-10-06-flutter-scene-0.24.md`.
- Coplanar overlap list: `docs/superpowers/notes/2026-10-06-coplanar-overlaps.md`.
- iPhone run: `.superpowers/sdd/2026-10-06-flutter-scene-0.24/device-verify-report.md` (git-ignored scratch).
