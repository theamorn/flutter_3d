# flutter_scene 0.24.0: upgrade the demo and use what it adds

Date: 2026-10-06 · Flutter 3.47.2 (fvm) · flutter_scene 0.23.0 → **0.24.0**

## Intent

**Asked for:** read `learning.md`, `docs/island/06-island-scene.md` and the hotel plan, then work out:
- what 0.24.0 lets us improve in the current scenes;
- what it adds that is new;
- which of the things that didn't work before it fixes.

Then plan the update so other agents can carry it out.

**Decided with the user:**
- Upgrade to 0.24.0 on a branch made from `main`. The user compares before and after; the plan has no baseline-capture task.
- The beach demo in https://x.com/algebrandon/status/2099481040540897553 is **not** built. Its FFT ocean spectrum, shallow-water surf solver and optics-table water colour don't exist in flutter_scene 0.24.0 or in any of the author's public repos. Adopt them when the package ships them.
- Other agents execute the plan. Tasks are grouped so independent ones can run in parallel.

**Assumed:**
- `Scene.maxGpuFramesInFlight` stays at the engine default of 1. The effects menus offer 2 as a measuring choice.
- The fixed render-scale picks stay the defaults. Adaptive quality is an extra, opt-in choice, so measured numbers stay reproducible.
- Device measurement is done by the user. Agents work on the iOS simulator and the Android emulator.

**Success:**
- `pubspec.yaml` resolves `flutter_scene 0.24.0`.
- `fvm flutter analyze lib test` shows no new issues, and `fvm flutter test` passes.
- Both demos load and render on the iOS simulator. Super Ultra also renders on the Android emulator.
- Every on-screen frame rate counts frames the **scene** actually rendered, not Flutter frames, and the HUD shows real draw counts.
- The workarounds that 0.24.0 makes unnecessary are removed. The ones it doesn't fix stay, with a comment saying why.
- The new features listed under "New features" each have a switch, so their cost can be measured.

## What 0.24.0 changes for this repo

The source of truth is the 0.24.0 `CHANGELOG.md` and source in the pub cache, `~/.pub-cache/hosted/pub.dev/flutter_scene-0.24.0/`. Everything below was checked against that source, not only the changelog.

### Fixed in 0.24.0: things that didn't work before

| Before (where it's recorded) | 0.24.0 | Our action |
|---|---|---|
| No draw counter. The HUD counts "meshes" by walking the graph and can't see `InstancedMesh` (06 "Draw calls"; learning Task 2 and Task 26). `perf_probe.dart` re-derives draws by hand (`countView`). | `Scene.renderStats`: `latest.views[i].counters.{draws, instances, vertices, culled, batches}`, per pass, with CPU times. Always on. | The HUD and probes read it. Label it "draws". |
| UI time was the UI thread blocked in `semaphore_wait_trap` waiting on the GPU (learning "UI time is mostly waiting for the GPU"). | `Scene.maxGpuFramesInFlight` (default 1) presents the previous image instead of stalling. `Scene.pacedFrameCount` counts held frames. | Count scene frames; see the next section. |
| The punctual-light upload cost 15–29% of the hotel's GPU waits. | Unchanged light textures are no longer re-uploaded; froxel clustering replaces the per-object light cap. | Nothing to do; it's a free win. |
| Bloom was 40–52% of the hotel's waits, and stamped a grid of square copies around highlights. | Bloom rewritten: mip averaging, B-spline resolve, `BloomSettings.fireflySuppression`, `BloomSettings.highlight`. A NaN now maps to black. | Look check (Task 2). |
| `.fmat` vertex stages had no model transform, so `page_curl` uses a tangent-basis hack and `heat_haze` assumes a translation-only node (learning Task 25). | `vertex.model_transform` | Rewrite both (Task 4). |
| `engine_inputs` needed a lit model, so `rain_glass` and `heat_haze` are "lit with albedo and specular zeroed" (learning Task 21). | Unlit `.fmat`s may declare `scene_color`. **`planar_reflection` still needs lit** (`fmat_parser.dart`). | `rain_glass` and `heat_haze` become unlit. `mirror` and `ocean` stay lit. |
| Every `scene_color` reader gets its own full-screen copy (learning Task 21; 06 "Anti-aliasing"). | `.fmat scene_color_reach` lets readers that don't overlap share one capture. `Scene.sceneColorCaptureBatches` caps how many captures a frame opens. | Add reach to `rain_glass` and `heat_haze`. Make capture sharing an island choice. |
| Shadow atlas past 8192 px made the next room black (learning "Spot shadows share the sun's atlas"). | The atlas caps shadowed spots and points at 4 each. `Scene.shadowCasterOverflowCount` and `Scene.isShadowCasterGranted` report it. `SpotLight.shadowFieldOfView` narrows a tile. | Log overflow; tighten the reading lights (Task 9). |
| The build-hook cache ignored new sources until `.dart_tool/hooks_runner` was deleted (06 seagull trap 1, finding 6). | Outputs rebuild when flutter_scene changes, and when a source is added or removed in a subdirectory. | Delete the cache once for the upgrade (Task 1). Record whether the fix holds. |
| A `.fmat` that fails to compile looked like "no effect" (06 finding 10). | `FmatCompileException.diagnostics` with line numbers. | Keep grepping the build output for `keeping the previous shaders`. |
| Non-uniform scale lit wrong (traps.md). | Normals use the inverse-transpose. | Free. Room B's `scale.x = -1` is unaffected. |
| On GLES, switching anti-aliasing from MSAA drew far surfaces over near ones. | Fixed. | Free. This is the island's anti-aliasing picker on Android. |
| Unlit `.fmat`s drew nothing on Impeller Vulkan. | Fixed. | `page_curl.fmat` (the Pokédex pages) would have been invisible on a real Android phone. |
| iOS 26+ crash with a lit material plus directional shadows (#436); Vulkan crash with cached static shadows; shadow striping on Mali and Adreno. | Fixed. | Free. These are device paths we never verified. |
| Opaque materials used `discard`, which disables early-Z and HSR on mobile. | No `discard` on opaque. | Free. |
| GLES pipeline-compile stalls; `onTick` deltas alternating under GPU load; static `InstancedMesh` copied every frame; every cascade re-rendered when the sun moved. | Sliced `warmUp`; wall-clock deltas; static instances kept on the GPU; one cascade per frame. | Free. Add `warmUp` and `preload` to the hotel (Task 9). |

### Still broken in 0.24.0: keep the workaround

| Workaround | Evidence in the 0.24.0 source |
|---|---|
| Swap a mounted node's material by assigning `node.mesh = mesh.clone()`. | `MeshComponent.refreshMaterials()` is still `@internal`. |
| `skyAt()`: solve the sky energy, lift the sun, let the moon take over. | `PhysicalSkySource.sunLightColor` is still a constant, and `flutter_scene_sky_physical.frag` is byte-identical. |
| `WidgetComponent` pages: `lookAt` along the view, then mirror in x. | Only `displayReferred` changed in `widget_component.dart`. |
| Pause with `TickerMode`, never with `SceneView(autoTick:)`. | `_SceneViewState` is still a `SingleTickerProviderStateMixin`. |
| Rain collision uses analytic proxies. | `raycast.dart` still has `TODO(raycast)` for instanced meshes and a BVH. |
| `mirror.fmat` and `ocean.fmat` stay lit. | The parser still rejects `planar_reflection` on unlit. |
| Kenney `.glb` pruning, embedded textures, metallic 0, no `KHR_materials_unlit`, portal culling. | Not in the changelog; assume unchanged. |

### Changes that alter the look or the numbers without an error

1. **Fragment precision.**
   - What changed: material fragment shaders now open with `precision mediump float;` (`shaders/PRECISION.md`), and a `.fmat` body inherits it. On Mali, Adreno and the web, an unqualified float is half precision: a 10-bit mantissa, max 65504.
   - Why it matters here: none of our 10 `.fmat`s declares `highp`, and they compute world positions, wave phases from `time`, hashes, star cells and caustic coordinates.
   - Why the usual checks miss it: Metal ignores precision, and the emulator's GL very likely runs fp32, so neither shows the bug.
   - **Decision:** open every material's fragment body with `precision highp float;` (PRECISION.md's documented opt-out). Relax to mediump only after a device measurement says it pays.
2. **Frame rate.** With pacing, Flutter frames keep arriving while the scene re-presents its last image. So the `FrameTiming` frame count in `hud.dart`, `perf_probe.dart`, `SCENE_FRAME_STATS`, `SCENE_ABLATION` and the island effects readout would overstate the scene's frame rate.
   - **Decision:** every readout reports *scene fps*: the change in `scene.renderStats.frameCount` over wall time. Each readout also shows the Flutter fps and the held-frame count beside it.
3. **IBL multiscatter fix.** Rough surfaces get darker, and partly metallic ones darkest. That covers every Kenney prop and the hotel's walls and fabrics. The user judges whether to re-grade.
4. **Bloom.**
   - `scatter` now weights the wider mips, so the island's 0.4, 0.72 and 0.8 and the hotel's look read differently.
   - `fireflySuppression`, on by default, dims isolated extreme pixels. It can thin the 1–2 px lightning bolt, the stars and the sea glints.
   - **Decision:** turn suppression off for Super Ultra if the bolt loses its glow (Task 2).
5. **`WidgetComponent` is display-referred by default.** The Pokédex pages skip exposure, tone mapping and fog. At 22:00, with exposure around 2.5, they read as self-lit.
   - **Decision:** pages are paper, so pass `displayReferred: false`.
   - Task 2 confirms by eye at 15:00 and 22:00.
6. **`hint: default_black` now samples black,** where it used to sample white. This affects `island_ground.fmat` `masks`, and `foam_texture` in both `ocean.fmat` and `ocean_simple.fmat`. Each is bound when its rig is built (Task 1 checks this), so only a draw before binding changes, and black is the right default for masks and foam.
7. **Reversed depth and a fitted near plane are on by default on Metal.** The 1–5 mm offsets in `books_feature.dart` and `placeholder_rooms.dart` may no longer be needed, or may fight differently. Debug builds print `findCoplanarOverlaps` once a scene settles. Task 10 acts on that list.

## Design

### Measurement (`lib/ui/scene_frame_meter.dart`, new, pure)

A `SceneFrameMeter` takes `(timestampMicros, sceneFrames, pacedFrames)` samples and reports, over a sliding 2 s window:
- `sceneFps`: frames the scene rendered per second;
- `pacedPerSecond`: frames the pacing held per second.

It has no Flutter or GPU dependencies, so it is unit-tested. The callers feed it from `scene.renderStats.frameCount`, `scene.pacedFrameCount` and a wall clock.
- `Hud` shows: `scene fps / flutter fps`, UI and GPU ms (unchanged), and draws, instances and triangles for the on-screen view from `renderStats.latest`.
  - The on-screen view is the first view whose `offscreen` is false.
  - Triangles: `vertices` isn't triangles, so keep the existing triangle walk, which is cached.
- `perf_probe.dart` and the island's frame stats and ablation add `scene fps` and `paced` to each line. `countView` is replaced by `renderStats` draws.
- The pacing depth (1 or 2) is a choice in both effects menus.

### Island

- **Campfire shadows.** `campfireLight.castsShadow = true` while Ultra or Super Ultra is on, with:
  - `radius` 0.25 m for a soft penumbra and wider glints;
  - `shadowMapResolution` 512;
  - `shadowNear` 0.1.

  A new `SuperUltraEffect.fireShadows` switch, grouped with lighting, turns it off. In Normal mode it stays off.
- **X-ray.**
  - Controls: a `🔍` button in Ultra and Super Ultra cycles through `off → wireframe wipe → normals → base colour → off`.
  - Rendering: it drives `scene.debug`. `view` is a `DebugView` for the channel, with `overlays` holding `DebugOverlay.wireframe`. `split` moves back and forth from 0.15 to 0.85 over 4 s, so a wipe crosses the island.
  - Logic: the state and the split timing are a pure class in `lib/island/xray.dart`.
- **Decals** (Super Ultra only).
  - A scorch ring under the campfire.
  - Up to 12 footprints laid behind the walking player, every 0.55 m of travel, fading out over 8 s.
  - One `decal_ground.fmat`, modelled on flutter_scene's own decal test fixture: unlit, alpha blend, `culling: front`, `depth_test: always`, `engine_inputs: [scene_depth]`. A `kind` parameter selects scorch or footprint. Each `DecalNode` needs its own material instance.
  - The placement maths is pure, in `lib/island/super_ultra/footprints.dart`.
- **Quality choices.**
  - **Render scale `Auto`:** `scene.renderQuality.adaptive = true`, `targetFrameRate = 60`, `minRenderScale = 0.6`, `maxRenderScale = 1.0`. The readout shows `scene.adaptiveRenderScale`.
  - **Frame-rate cap:** `Uncapped` or `60 fps`, via `SceneView(maxFrameRate:)`.
  - **Scene copies:** `Separate` (null) or `Shared` (`scene.sceneColorCaptureBatches = 1`), as a measuring choice. Shared may show the sea missing behind the heat haze. The menu line says so.
- **Hidden-tab memory.** When `AppShell` hides the island or hotel tab, it calls `releaseTransientRenderTargets()` once. They reallocate on the next frame that needs them.

### Hotel

- **Light sizes.** Physical sizes set `radius` on the bath and bedside `PointLight`s (0.06 m) and the reading `SpotLight` (0.03 m).
- **Bath light point shadow:** `castsShadow = true`, 512 px, `shadowNear` 0.05. It's a new default-off feature, `bath_shadow`, at cost tier `mid`, in the `ultra` preset only.
- **Spot shadow budget.** Each reading light gets a `shadowFieldOfView` of the outer cone minus 10°. The feature logs `scene.shadowCasterOverflowCount` whenever it changes (debug builds).
- **Startup.**
  - `HotelScene.start()` awaits `Scene.preload(physicalMaterials: true, smaa: true)` in place of `initializeStaticResources()`.
  - `SceneView(warmUp: true)`.
  - A failed start shows the error text instead of a black page.
- **Z-fighting.** Replace each mm offset that `findCoplanarOverlaps` names with `material.depthLayer = 1` on the overlay surface and no offset.
- **GI debug.** The Effects sheet's dynamic GI row gets a "show probes" switch. It draws `scene.globalIlluminationProbeGrid` (origin, spacing, counts) as small unlit cubes.
- **`Auto` render scale:** a new exclusive render-scale feature, `render_scale_auto`. It is in no preset.

### Out of scope

- The beach demo's FFT ocean, shallow-water surf zone and optics-table colour.
- Orthographic cameras, spatial audio, ETC1S texture encoding and `MaterialGroup`. These are optional follow-ups.
- A lightning screen-distortion shockwave (optional follow-up).
- Device measurement, which the user does.

## Verification

- `fvm flutter analyze lib test`: no new issues. `fvm flutter test`: all pass, including the new tests named in the plan.
- The build output never contains `keeping the previous shaders`.
- iOS simulator, debug:
  - `--dart-define=SCENE_TOUR_MODES=true` and `SCENE_RAIN=true SCENE_LIGHTNING_HOLD=2` render every stop in every mode.
  - `tool/capture_tour.sh` renders all 12 hotel stops.
- Android emulator: the Super Ultra tour renders at all 6 stops, and the anti-aliasing picker switches MSAA → SMAA with correct depth.
- Not verifiable without hardware (recorded as unverified):
  - the mediump fix on a real Mali or Adreno GPU;
  - every frame-rate number.
