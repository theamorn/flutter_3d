# Learnings — Hotel 3D Tour

Append-only log of non-obvious findings from building this app with flutter_scene 0.23.0.
Read it before starting a task; add to it before committing one. Format:

## <short title> (Task N, YYYY-MM-DD)
- **Found:**
- **Why it matters:**
- **Do:**
- **Talk?** yes/no

## Plan's engine names differ from flutter_scene 0.23.0 (Task 2, 2026-09-26)
- **Found:** `ToneMappingMode` has no `none` (members: pbrNeutral, aces, reinhard, linear, agx); GTAO is `AmbientOcclusionMethod.groundTruth`, not `gtao`; `EnvironmentSettings.sunLight` is a `SunLight?` (a binding that aims a directional light at a sky's sun), not a `DirectionalLight?`; `SceneView.onTick` is `(Duration elapsed, double deltaSeconds)`.
- **Why it matters:** the plan's `look.dart` / `hotel_page.dart` snippets don't compile as written.
- **Do:** "tone mapping off" = `ToneMappingMode.linear` (documented as "no tone curve"). `LookState.sunLight` is `SunLight?` — Task 12 should build `SunLight(sky, castsShadow: ...)` from the same sky source as `Skybox`/`SkyEnvironment`.
- **Talk?** no

## Passing a dynamic null to a typed parameter casts at the call site (Task 2, 2026-09-26)
- **Found:** `f.mount(mountContext as dynamic)` with `mount(HotelContext ctx)` throws `type 'Null' is not a subtype of type 'HotelContext'` even when the override widens the parameter to `Object?` — Dart inserts the implicit downcast at the call site, using the static signature.
- **Why it matters:** the plan's registry tests fail with the plan's code.
- **Do:** dispatch dynamically (`final dynamic feature = f; feature.mount(ctx)`), so the runtime override's own parameter type is what's checked.
- **Talk?** no

## A Stack of zero-sized overlay stubs collapses to 0x0 and hides the whole UI (Task 2, 2026-09-26)
- **Found:** the page `Stack` had only `Positioned` children plus `SizedBox.shrink()` overlay stubs. A Stack sizes to its non-positioned children, so it became 0x0: black screen, no HUD/buttons, and the engine logged "Flutter Scene rendered a blank frame (zero draw calls). The draw region is zero-sized".
- **Why it matters:** looks exactly like a GPU/Impeller failure; it isn't.
- **Do:** `Stack(fit: StackFit.expand, ...)` for the page. When the engine says "draw region is zero-sized", check layout constraints first. Feature overlays (Tasks 10/11/24/29) get full-screen tight constraints; position their content inside.
- **Talk?** yes — the engine's blank-frame diagnostic pointed straight at a Flutter layout bug.

## Geometry needs Impeller: no mesh-building in unit tests; no public triangle count (Task 2, 2026-09-26)
- **Found:** constructing `CuboidGeometry` in `flutter test` throws "Flutter GPU requires the Impeller rendering backend". `MeshGeometry` has no `triangleCount` (that's on `GeometryBuilder`); the index count is only on the `@internal` `cpuMeshData`. There's no render-stats API.
- **Why it matters:** anything that builds meshes can only be verified by running the app.
- **Do:** HUD mesh/triangle counts walk `scene.root` (visible nodes only) and read `geometry.extractMeshData().triangleCount` once per geometry, cached in an `Expando`. Keep GPU-free maths in `lib/math` so it stays testable.
- **Talk?** no

## Emoji render as "?" boxes on the iOS 26.5 simulator (Task 2, 2026-09-26)
- **Found:** 🎛 🕑 🌧 ☀️ in `Text` widgets show as boxed "?" on the iPhone 17 Pro simulator (iOS 26.5, Impeller/Metal). Latin text is fine.
- **Why it matters:** the Effects button, time label and weather toggle look broken on the simulator.
- **Do:** unverified on a physical device. If it reproduces there, swap them for Material `Icons` (tune, schedule, water_drop / wb_sunny).
- **Talk?** no
