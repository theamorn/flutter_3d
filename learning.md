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

## vector_math (non-_64) vectors are float32 — 1e-9 tolerances fail (Task 4, 2026-09-26)
- **Found:** `package:vector_math/vector_math.dart` stores `Vector2/3` in `Float32List`, so `Vector2(0, 1.4).y == 1.399999976158142`. The plan's `closeTo(kWalkSpeed, 1e-9)` failed by 2.4e-8.
- **Why it matters:** any test asserting a computed Vector component to 1e-9 fails unless the value is exactly representable (0, 1, −2, …).
- **Do:** use `1e-6` tolerances for anything that passes through a `Vector2`/`Vector3`. Plain `double` maths (yaw, pitch, schedulers) keeps full precision.
- **Talk?** no

## flutter_scene's view basis: facing +Z, screen-RIGHT is +X (plan Tasks 4/5 were mirrored) (Final review, 2026-09-26)
- **Found:** `camera.dart` `_matrix4LookAt` builds `right = up.cross(forward)` and `up = forward.cross(right)`, and the projection doesn't flip x. So with +Y up and facing +Z, world +X is on the right of the screen. The plan's Task 4/5 maths assumed right = −X (`fwd.cross(up)`, `right = (-fwd.y, fwd.x)`, `yaw - dx`), so taps picked the mirror-image point, strafe-right went left, and drag-right turned left. This contradicts the plan; the code now follows the engine.
- **Why it matters:** a mirrored pick ray hits nothing, or the wrong object, on the other half of the screen (Review Focus 5). Anything "inverse of Task 5" (Task 24's `projectToScreen`) inherits the mirror.
- **Do:** `right = up.cross(fwd)`, `camUp = fwd.cross(right)`; strafe right = `(fwd.y, -fwd.x)`; drag right = `yaw + dx·k`. Prefer the engine's own `camera.screenPointToRay(offset, size)` and `camera.worldToScreen(point, size)`. They're pure maths and run in `flutter test` with no GPU, so pin hand-rolled projection against them (see `picking_test.dart`, `fp_movement_test.dart`).
- **Talk?** yes — "the plan's maths was confidently mirrored; a 10-line test against the engine's own projection caught it".

## Hand-built faces: the viewer's right is n × up, and winding can be unit-tested (Task 9, 2026-09-26)
- **Found:** with flutter_scene's view basis (right = up × forward), a viewer in front of a face with outward normal n sees n × up as screen-right. A quad listed top-left, top-right, bottom-right, bottom-left from that viewer's point of view is front-facing when wound (tl, tr, br), (tl, br, bl). My first quads used the textbook right-handed "right" (up × n) and came out back-facing; a UV-mapped screen built that way would also be mirrored. `buildCuboidArrays` (the engine's own box generator) isn't exported, so hand-built boxes have to get this right themselves.
- **Why it matters:** a back-facing quad is invisible from the front (trap 13). Any hand-written face generator (screens, glass, mirrors, book pages) has to agree with the engine's handedness.
- **Do:** build vertex arrays as `MeshData` (pure CPU, runs in `flutter test`), then use `MeshGeometry.fromMeshData` on the GPU side. To pin winding, compare your normals with `MeshData.build(positions:, indices:)` (normals omitted). The engine derives those from the winding (e1 × e2), so a dot product < 0 means the triangle is inside out. See `placeholder_rooms_test.dart`.
- **Talk?** yes. It's the same handedness surprise as the picking maths, this time caught by a unit test before it reached the screen.

## No tap tool? Drive input through the VM service's `evaluate` (Task 10, 2026-09-26)
- **Found:** the simulator has no tap or drag tool, and the app has no flutter_driver extension. The Dart MCP `vm_service` tool can connect to the `ws://…/ws` URI that `flutter run` prints. Then `callMethod evaluate` with `targetId` = the library id (found in `getIsolate` → libraries, e.g. `package:flutter_3d/features/player_feature.dart`) runs an expression inside the live app: `PlayerFeature.stick.value = const Offset(0, 1)` walks forward, and `PlayerFeature.pendingLook = const Offset(314.16, 0)` turns 90° right. A statement block works when wrapped in an IIFE: `(){ …; return 0; }()`.
- **Why it matters:** you can check the joystick/look wiring, collisions and camera on the device with no temporary code to revert.
- **Do:** keep input in static notifiers (as `PlayerFeature` does) so it can be driven this way. `getIsolate` output is ~200 KB, so grep it for the library id rather than reading it.
- **Talk?** no
