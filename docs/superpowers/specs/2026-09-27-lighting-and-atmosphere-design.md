# Lighting and atmosphere: probes, GI, exposure, AA, lights, volumetric fog

Date: 2026-09-27 · Engine: flutter_scene 0.23.0 (the latest on pub.dev)

## Intent

**Asked for:** light-probe GI and reflection probes, auto exposure, cheaper
frames (cached static shadows, FXAA/SMAA/TAA), more lighting variety (spot
reading lights, area lights), plus Lumen-style dynamic GI, baked lighting
"that helps with performance", light probes, and volumetric fog and shadows.
Every one of them must be a toggle.

**Decided with the user:**
- Volumetric fog is engine-native (height fog + sun in-scatter + god-ray
  shafts), not a custom ray-marched shader.
- Baked lighting re-bakes itself 0.5 s after the time of day, lamps or
  weather settle, keeping the old result until the new one is ready.
- Baked lighting is per-room captured probes (see "Why not a baked probe
  grid"), which also makes it the reflection-probe feature: one toggle.

**Assumed:** the phone is the target; every toggle shows a visible
difference and sits in the Low/Medium/High/Ultra presets; the cheap baked
path lands in the cheaper tiers and the dynamic path in Ultra.

**Success:** each toggle switches on and off cleanly (nothing left behind),
changes the image in a way screenshots show, and has a measured cost on the
perf probe's sweep once a device is available. Occlusion culling stays
invisible with every new feature on.

## What exists and what can't be built

| Technique | Answer |
|---|---|
| Ray tracing | Not possible: Flutter GPU exposes raster pipelines only (no RT, no compute). Screen-space reflections, god rays and planar reflections are the ray-marched stand-ins already in the app. |
| Lumen (dynamic GI) | The engine's irradiance field: a live light-probe grid fed from each rendered frame. "Dynamic GI" below. |
| Baked lighting | The engine's probe-grid bake is unwired in 0.23 (`Scene.bakeIrradianceField` returns an `IrradianceFieldBake`, but nothing reads `IrradianceVolumeComponent.bake`, and `bakeOnly` only freezes injection). Materials accept lightmaps, but there is no lightmapper. So baking is per-room captured probes. |
| Light probes | Both the captured room probes (baked) and the dynamic grid are light probes. |
| Volumetric fog / shadows | Engine-native: exponential height fog with sun in-scatter, plus god rays (shadow-map ray march = the sun's volumetric shadows). Lamps don't scatter in the fog. |

## The toggles

| Id | Effects-sheet label | Tier | Default on | Presets |
|---|---|---|---|---|
| `light_probes` | Baked light probes (room ambient + reflections) | cheap | yes | medium+ |
| `dynamic_gi` | Dynamic GI (Lumen-lite probe grid) | expensive | no | ultra |
| `auto_exposure` | Auto exposure (eye adaptation) | cheap | yes | medium+ |
| `static_shadows` | Cached static shadows | free | yes | medium+ |
| `msaa` (existing) | MSAA anti-aliasing | mid | no | high, ultra |
| `fxaa` | FXAA anti-aliasing | cheap | no | medium |
| `smaa` | SMAA anti-aliasing | mid | no | manual |
| `taa` | TAA anti-aliasing | mid | no | manual |
| `spot_lights` | Reading spot lights (shadowed) | mid | yes | high+ |
| `area_lights` | Area lights (TV glow, window light) | cheap | yes | medium+ |
| `volumetric_fog` | Volumetric fog + light shafts (needs Sun shadows) | expensive | no | ultra |

`spot_lights` owns the reading lights' tap-to-switch, so it is default-on
(learning: "A tap owned by a default-off feature silently doesn't exist").

**Presets:** each tier stays a superset of the one below *except* in the
anti-aliasing group, where each tier names at most one mode (medium FXAA,
high and ultra MSAA). Ultra enables every toggleable feature except the
alternative AA modes (`fxaa`, `smaa`, `taa`). `presets_test` changes to say
exactly this.

## Shared infrastructure

1. **Exclusive groups.** `HotelFeature` gains `String? get exclusiveGroup`
   (null by default). `FeatureRegistry.setEnabled(id, true)` first switches
   off every other wanted feature in the same group. The four AA features
   share group `aa`.
2. **AA ownership.** The AA features share one base: mount sets
   `scene.antiAliasingMode` to its mode; unmount sets `none` only if the
   mode is still its own. Per-feature reconcile chains can interleave (the
   new mode mounts before the old unmounts), and this keeps the new mode.
3. **Settle timer** (`math/schedulers.dart`, pure): `markDirty()` restarts a
   quiet period; `tick(dt)` returns true once, when 0.5 s have passed with
   no new dirt. Unlike `RebakeThrottle`, it never fires while changes keep
   coming.
4. **Lighting revision.** `HotelContext.lightingRevision`
   (`ValueNotifier<int>`), bumped by the lamps and reading-light switches.
   The probe feature also marks itself dirty when the time of day changes,
   the weather moves by more than 0.05, or the sky's environment object is
   replaced.
5. **Occlusion hold.** `HotelContext.occlusionHolds` (an int). While it is
   above zero, `OcclusionFeature` shows everything it had hidden. The
   feature ticks last, so a hold taken in a tick is in force for that
   frame's render.
6. **Look flags.** `LookState` gains `autoExposure`, `volumetricFog`, and
   `dynamicGi`; `composeLook` (still the only `EnvironmentSettings`
   literal) turns them into engine settings. `look_test` pins the mapping.

## Features

### Baked light probes (`light_probes`)
- Four `ReflectionProbeComponent` nodes, children of each room's root so
  room B's are mirrored for free: one bedroom box covering the room's
  footprint and height (priority 10), and one bathroom box covering the
  bathroom cell (priority 20, so it wins inside it). Blend distance 0.3 m.
  The balconies lie outside every box and stay sky-lit.
- Face resolution 128. `captureOnActivate` stays on for the first capture.
- **Outdoor materials keep the sky.** The engine applies a probe to the
  whole frame by camera position, so every outdoor material (sea, horizon,
  beach, shore, facade, palms, umbrellas) gets its per-material
  `environment` pinned to the sky's current environment. It is read from a
  `Scene.baseEnvironment` snapshot holding the sky environment; the engine
  refreshes that snapshot's `environment` on every sky re-bake. Without the
  pin, the sea would reflect the bedroom. The pin is removed when the
  feature unmounts.
- **Re-capture:** the settle timer fires → take an occlusion hold →
  `requestCapture()` on one probe per frame → release the hold after the
  last capture frame. The previous capture stays bound until each new one
  lands.

### Dynamic GI (`dynamic_gi`)
- One `IrradianceVolumeComponent` node centred on both rooms and balconies,
  centre (0, 1.4, 3.96), half-extents (8.2, 1.5, 4.0), resolution
  (12, 4, 7): about 1.4 m spacing. Global illumination is on in `composeLook`
  with `volumeMode: component`.
- With `light_probes` on, the grid owns the diffuse term inside its volume
  and the probes keep the reflections. That's the engine's documented
  split, so nothing is lit twice.
- Injection only learns from the rendered frame; occluded objects are
  behind walls anyway, so no hold is needed.
- Visibility settings are tuned against wall leaks (the 12 cm walls should
  block; the 6 cm bathroom walls may leak a little) by screenshot A/B.

### Auto exposure (`auto_exposure`)
- `composeLook`: `autoExposureEnabled`, strength 0.55, EV range ±1.5 so the
  sky's authored exposure schedule stays the base, speed up 3 and speed
  down 1 (eyes adapt faster to brightness).
- Teleports snap: if the camera moves more than 1 m in one tick (tour stops,
  the perf probe), the feature calls `scene.autoExposure.reset()`.

### Cached static shadows (`static_shadows`)
- Sets `shadowStatic = true` on every mesh node in both rooms, and on the
  facade, except the movers and their subtrees: `door_connect`,
  `curtain_left`, `curtain_right`, `faucet_lever`, `bath_switch_rocker`.
  Restored to false on unmount; re-applied when the rooms remount. The
  sun's `cacheStaticShadows` is already on by default.
- The selection is a pure function over names, unit-tested.

### Anti-aliasing (`msaa`, `fxaa`, `smaa`, `taa`)
- See shared infrastructure 1–2. `smaa` and `taa` are manual picks. TAA is
  checked for ghosting on rain and water particles before it goes into any
  preset.

### Reading spot lights (`spot_lights`)
- **New fixtures in the room spec:** `reading_light_left` and
  `reading_light_right`, on the outer wall (x = −8) above each side of the
  headboard, at 1.6 m, at z ≈ 3.3 and 5.3. Each is a brass wall plate, a
  25 cm arm and a small cone shade aimed at the pillows. They sit clear of
  the bed collider and the bedside lamp. They exist whether or not the
  feature is on.
- The feature adds a `SpotLightComponent` per fixture (warm white, range
  3 m, cones about 20° inner and 35° outer, `castsShadow: true`), lights the
  shade emissive, and registers a tap to switch each one on and off,
  bumping `lightingRevision`.
- **Cost caveat:** spot shadow tiles share the sun's tile resolution
  (2048). If the sweep shows this is heavy, only the camera room's spots
  cast shadows.

### Area lights (`area_lights`)
- **TV glow:** a `RectAreaLightComponent` on each `tv_screen` node
  (1.2 × 0.675 m, emitting into the room), a cool white at low intensity.
- **Window light:** a rect area light filling each window opening
  (2.8 × 2.4 m, facing into the room). Its colour and intensity follow the
  sky's brightness schedule, scaled down by weather, and it is dark at
  night: a "skylight" bounce stand-in. Area lights cast no shadows.
- Both are children of the room roots, so room B is mirrored for free.

### Volumetric fog (`volumetric_fog`)
- `composeLook`, when the flag is on:
  - fog is enabled (whatever the plain `fog` toggle says), exponential,
    density about 0.012 at sea level;
  - `fogHeight` −90 (the sea) with `fogHeightFalloff` about 0.03, so the
    rooms, 90 m up, see about 7% of that density: mist over the sea, clear
    air on the balcony;
  - sun in-scatter on (about 0.6, exponent 8);
  - god rays forced on with thicker settings (density about 0.35,
    intensity about 1.2, max distance 250 m) for the shafts.
- Rain raises the density with `ctx.weather`. The fog cutoff (895 m) stays,
  so the sun and moon discs remain clear.
- Without Sun shadows the shafts are skipped by the engine; the label says
  so.

## Verification

- **Unit (GPU-free):** settle timer; registry exclusive groups with fake
  features; preset rules; `composeLook` flags (volumetric fog, auto
  exposure, dynamic GI); static-shadow selection skips movers; probe boxes
  nest and cover their cells; reading-light fixture parts sit inside the
  room and clear of colliders; teleport detection.
- **Visual:** the perf probe's `HOTEL_PERF_AB=<id>` mode, with the
  screenshot script, gives off/on pairs at the 12 stops for every new
  toggle. Each must change the image where expected and nowhere else. The
  occlusion off/on pairs must still match with `light_probes` on, which
  proves captures see the whole room.
- **Performance:** the new features join the sweep; costs are measured on a
  device when one is available (the Mac is shared with other sessions).

## Risks

- **Dynamic GI:** light may leak through thin walls. Tune visibility; if the
  bathroom walls leak visibly, document it or keep dynamic GI out of the
  bathroom.
- **Probe re-capture:** it costs 6 renders × 4 probes, spread one probe per
  frame; there may be a visible frame-time bump after each change.
- **`Scene.baseEnvironment`:** setting it changes the engine's environment
  blending path. Check that the sky still re-bakes and that the look is
  unchanged with the feature off.
- **TAA:** it may ghost on particles.
- **Spot light shadows:** shadow tiles at the sun's resolution may be heavy
  (see the fallback above).

## Out of scope

Ray tracing, custom ray-marched fog, lamp light scattering in fog,
lightmaps, and patching the engine's grid bake. The last is worth
reporting upstream to flutter_scene.
