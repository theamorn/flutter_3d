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

## Real taps without a tap tool: `handlePointerEvent` through the VM service (Task 11, 2026-09-26)
- **Found:** `evaluate` (see the Task 10 entry) can inject real pointer events: `WidgetsBinding.instance.handlePointerEvent(PointerDownEvent(pointer: 901, position: c))` followed by a `PointerUpEvent`. They go through hit testing and the gesture arena exactly like a finger. A centre tap on the look pad's half of the screen still reached the tap-to-interact layer underneath: the pan recogniser rejected it on up. Use `WidgetsBinding`, not `GestureBinding`, because the latter isn't in a `material.dart` library's scope. Positions are logical pixels (the iPhone 17 Pro is 402 × 874). Library ids in `evaluate`'s `targetId` change on every hot restart (re-grep `getIsolate`), and so does the isolate id (`getVM`).
- **Why it matters:** you can verify taps, sheets and buttons end to end on the simulator, with a negative control (a tap on a non-interactive mesh prints nothing).
- **Do:** check a tap by counting a `debugPrint` in the run log before and after. Beware: someone clicking the Simulator window adds taps you didn't send.
- **Talk?** no

## flutter_scene's PhysicalSkySource: black at dusk, white at exposure 1, constant sun (Task 12, 2026-09-26)
- **Found:** (1) With the physical sky baked into the IBL, exposure 1.0 clips the whole room to white; 0.35 reads well at 15:00 (turbidity 3; the default 10 is hazy, near-white). (2) `flutter_scene_sky_physical.frag` computes `inscatter ∝ (energy · (1 − e^−elevation))^1.5` with no ambient floor. A 15°-up sky sample fell ~80× from 15:00 to 17:30 and was exactly 0 from 17:45, so the kit's own recipe (`DayNightCycleComponent` driving `skySource.sunDirection`) gives a black screen at dusk and all night, and `environmentIntensity` can't brighten a black IBL. (3) `PhysicalSkySource.sunLightColor/sunLightIntensity` are constants (daylight, 3·energy), so a plain `SunLight(sky)` keeps lighting at full strength from below the horizon. (4) `DayNightCycleComponent.sunDirection` / `evaluateLighting()` are pure and work unmounted; its `sunLightNode` fights a `SunLight` binding, which owns `Scene.directionalLight`.
- **Why it matters:** the time slider looks broken without this (white noon, black 17:45 to 06:15).
- **Do:** bind `SunLight(sky)` and override its `color`/`intensity` from `evaluateLighting()`. Never render the sky's sun below ~30°: keep its heading, lift its elevation, and let a full moon (−sun) take over at the horizon. Solve `energy = brightness^(2/3) · g_ref / g(y)` so the rendered sky follows a schedule you choose (1 by day, 0.012 at night) wherever the body stands. Log-ease exposure 0.35 → 2.5 over the same span. All of it is pure maths in `skyAt()` and pinned by `sky_test.dart`.
- **Talk?** yes — "the engine's own day/night recipe goes black at 17:45; the fix was reading the sky shader and inverting its brightness formula".

## "What is that pixel?" Ask the engine: raycast through it via the VM service (Task 13, 2026-09-26)
- **Found:** a pale band in a look-down screenshot looked like mis-coloured sand. `camera.screenPointToRay(Offset(px/3, py/3), Size(402, 874))` + `scene.raycast(...)` inside `evaluate` named each pixel's node and hit point: it was the chrome top rail 0.5 m from the eye. Add `where: (n) => n.name != 'railing_glass'` to see what's behind glass. Long results come back truncated at 128 characters; re-read them with `getObject(objectId, count: 2000)`.
- **Also found:** `evaluate` can run at a safepoint in the middle of a paint (`ResolvePass.execute`). A synchronous `ValueNotifier` write there rebuilds the slider during paint and throws, and the listener after it (the sky) never runs, which left exposure stale. Setting a notifier to its current value doesn't notify at all.
- **Do:** make every state mutation in `evaluate` inside `Future(() { ... })` (or `Future.delayed`), and read state synchronously. Identify pixels by raycast before tuning materials or light.
- **Talk?** no

## Bloom threshold is compared before exposure (Task 14, 2026-09-26)
- **Found:** `flutter_scene_bloom_threshold.frag` thresholds un-premultiplied linear HDR radiance, and exposure is applied later in `ResolvePass`. With the sky's day exposure of 0.35, `bloomThreshold: 1.0` bloomed everything brighter than 0.35 on screen: 87% of pixels changed and the room went hazy.
- **Why it matters:** any look that lowers exposure (a physical sky) makes bloom wash out the frame, and it reads as "bloom is broken".
- **Do:** set the threshold in display terms, `bloomThreshold: 1.0 / exposure` (done in `composeLook`, pinned by `look_test`). After the fix only the bright window blooms (35% of pixels, mean Δ 7.9 instead of 24.7).
- **Talk?** yes. One line of maths separates "cinematic glow" from "fog of doom".

## Measuring an effect toggle on a simulator someone else is using (Task 14, 2026-09-26)
- **Found:** the user was driving the joystick and look pad while I A/B'd effects, so frame diffs mixed camera motion with the effect (a 94% "SSR" diff was mostly a head turn).
- **Do:** make the toggle in the same `evaluate` via `Future.delayed(1.2 s)`, screenshot before and after, and read `camera.position`/`target` before and after. Keep a pair only if the pose is identical. You can pin a view by writing `ctx.playerXZ`/`ctx.playerYaw` directly (they're mutable). Diff with a grid mean |ΔRGB| and exclude the HUD box (its numbers change every frame).
- **Talk?** no

## "MSAA off" isn't off by default, and sun shadows vanish under a sky IBL (Task 15, 2026-09-26)
- **Found:** (1) `Scene.antiAliasingMode` defaults to `auto`, which resolves to MSAA where offscreen MSAA is supported (it is on the iOS simulator). A default-off msaa feature that has never mounted therefore leaves MSAA on. (2) A `SkyEnvironment` IBL has no occlusion, so the sun's shadow only removes the sun's small direct term, and a room under a ceiling reads as lit as the sunny balcony. `SunLight.shadowAmbientStrength` (0 by default) also darkens the IBL in shadow. The A/B chose 0.5: at 0 the shadows barely show, and 0.8 is moody-dark. (3) A new `SunLight` (the sky remounted) comes back with the engine defaults (1024 map, 4 cascades, 150 m), so a shadows toggle has to re-apply its settings to whatever sun appears. (4) God rays march the shadow map and only show where sunlight streams through gaps into shade. In this south-facing room at 15:00 they changed ≤ 2% of pixels, even at 4× intensity.
- **Do:** set `AntiAliasingMode.none` when the context is created, and let the feature own the mode. Configure shadows via `SunShadows.sync()` every frame (an identity check). Keep the shadow range tight (25 m) so 2 cascades × 2048 cover the rooms. Judge MSAA on a 3× crop of an edge: whole-frame diffs barely register it.
- **Talk?** yes. "Shadows on" did nothing visible until the ambient term went in.

## A shared door cannot remain below a culled room (Task 17, 2026-09-26)
- **Found:** flutter_scene raycasting and rendering both skip a node when any ancestor has `visible = false`. The connecting leaf was authored below Room A, so portal culling hid it from Room B even though the leaf itself stayed visible.
- **Why it matters:** a closed door in Room B would disappear and stop being pickable, leaving a collision barrier with no visible door.
- **Do:** move the shared leaf to `Scene.root` after Rooms mounts. Clone its `globalTransform` before detaching, then assign that world transform after reparenting; the engine recalculates the needed local transform. Portal visibility must follow the current hinge angle, not the requested open/close target, so the far room remains drawn until the leaf seats at angle zero.
- **Talk?** yes

## Scene construction also needs Impeller in widget tests (Task 29, 2026-09-26)
- **Found:** `Scene()` itself requests `GpuContext` and throws in `flutter test`; a widget test cannot create a `HotelContext(Scene())` just to exercise a feature overlay.
- **Why it matters:** the GPU boundary starts before geometry. Tests of booking controls and quote maths can run in Flutter's test runner, while the feature's live scene integration needs a device run.
- **Do:** keep entrance distance and quote calculations in pure files, test the booking route without `HotelScene`, and record the scene transition as unverified when no simulator run is authorized.

## Built-in particle shapes only emit +Y; a mirrored room never needs to care (Task 19, 2026-09-26)
- **Found:** every built-in `EmitterShape` (`ConeEmitterShape`, `SphereEmitterShape`, `PointEmitterShape`, `BoxEmitterShape`) samples its unit emission direction about local +Y — `ConeEmitterShape` has no `direction`/axis parameter, unlike `Point`/`Box`. To make a faucet or shower head point down there is no "pointing down" constructor argument; you either rotate the emitter's node 180° or write a tiny `EmitterShape` wrapper that negates the inner shape's sampled `velY`/`posY`. The wrapper is the better fit here: it is pure Dart, testable in `flutter_test` by stepping the system and reading `ParticleStorage`, and needs no extra child node. Also: `ConeEmitterShape(angle: 0, radius: r)` *is* a disc emitter (area-uniform XZ disc positions, dead-straight +Y direction, zero spread) — there is no separate `DiskEmitterShape`.
- **Why it matters:** the brief's "check how `ParticleEmitterComponent` treats a negative-determinant parent" turns out to be a non-issue for this task specifically because every shape here is radially symmetric in local X/Z and only emits along Y. Room B's `scale.x = -1` parent only ever flips X, so a stream that only ever has a Y (and radially-symmetric XZ) component renders identically in both rooms with zero room-specific code. This would *not* hold for an asymmetric effect (e.g. a shape with a fixed lateral bias) — that case would need the emitter's own local basis re-derived under the mirror, or verifying in-engine that `ParticleEmitterComponent`'s `modelTransform` (passed whole to the vertex shader per `billboard_geometry.dart`'s `bind()`) carries the flip through correctly for position and `i_velocity` (it does, since both are matrix-multiplied by the same `modelTransform` — no special-casing was found or needed in the component or geometry source).
- **Do:** for a straight-down/up stream, wrap the shape with a Y-flip rather than rotating a node; only reach for a rotation (or investigate the mirrored-transform path further) if the emitter's shape has a lateral direction bias.
- **Talk?** no

## `ParticleEmitterComponent.system` is `final`; use `paused` to gate a burst-only spawner (Task 19, 2026-09-26)
- **Found:** `Spawner.rate` is mutable (`double`, not `final`), so a steady-rate stream toggles cleanly with `spawner.rate = 0 / value`. `Spawner.bursts` is `List<ParticleBurst>` built once and unmodifiable, and burst times are absolute on the system's own clock (`ParticleSystem.time`) — there is no rate-equivalent to gate a burst-only effect on/off, and `ParticleEmitterComponent.system` is `final` so you cannot swap in a freshly built system to re-arm one either.
- **Why it matters:** a naive port of "set rate 0 ↔ value" for a burst-based splash effect doesn't compile (final field) and doesn't work (bursts ignore rate).
- **Do:** for a burst-driven effect, gate it with `ParticleEmitterComponent.paused` instead. Pausing skips `system.step()` entirely, which freezes `_systemTime` too, so a repeating `ParticleBurst(interval: ..., cycles: null)` just resumes on the same cadence when unpaused — and it's also the cheapest possible "off" (no CPU stepping at all), better than a driven-to-zero rate whose system still steps every frame.

## A CPU `ParticleSystem` is a plain Dart object; the app wires it to render (Task 20, 2026-09-26)
- **Found:** `ParticleSystem` (shape/spawner/modules/storage) has zero scene-graph or GPU dependency — it's pure Dart, so `createRainSystem()`/`createSplashSystem()` construct and `.step()` it directly in `flutter test`, matching the Addendum's "particle systems... ARE testable" rule. Rendering it is a separate, optional step: wrap it in a `ParticleEmitterComponent(system: ...)`, attach that to a `Node`, and `Node.addComponent` already runs `component.update(dt)` (which calls `system.step(dt)`) every frame once the node is live in `ctx.scene` — no manual per-frame `system.step()` call needed in the feature's own `tick`.
- **Why it matters:** a naive implementation would double-step the system (once in `tick`, once via the component), running it 2x speed. Also, a literal `> 0.02` threshold on `ctx.look.fogDensity` (range 0.004..0.016, span 0.012) can never fire — the brief's "only call `applyLook()` when the value changes by more than 0.02" throttle only makes sense against the *driver* (`ctx.weather`, 0..1), not the derived `fogDensity`/`weatherExposureScale` outputs.
- **Do:** let the component step the system; the feature's `tick` only sets `spawner.rate` and daylight tint, and gates `applyLook()` on `|weather - lastAppliedWeather| > 0.02`. For "outside only" placement, keep the emitter box in the node's local space and add the node's world offset only when converting to/from the test's expected world coordinates (`rainEmitterY`/`rainEmitterZ`/`splashEmitterZ` are exactly that offset, exported so tests can undo it).
- **Talk?** no
