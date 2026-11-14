# flutter_scene 0.24 Scene Effects Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Apply material hooks, coverage/glow, selective draws/shadows, distortion and custom reflections as default scene enhancements with comparisons.
**Architecture:** Scoped material bindings and bounded state models integrate through existing scene rigs/features. Custom bathroom targets register offscreen views and participate in occlusion; existing scene tools measure them.
**Tech Stack:** Flutter 3.47.2, Dart 3.13.2, flutter_scene 0.24.0.
**Spec:** ../specs/2026-10-06-flutter-scene-0.24-scene-effects-design.md.
**Status:** Draft, depends on Phase 1.

## Global Constraints

- Apply the controls and effects specs' constraints/default values.
- No new dependencies; shaders declare highp; failed material builds cannot retain old shaders unnoticed.
- Real Scene/material/geometry binding is GPU runtime work; pure models and compileFmat remain testable.
- Optional comparison choices restore authored materials/meshes/state using existing ownership rules.
- New visual effects are default-on only in the specified modes/presets.
- Prewarm new materials before measuring; no claim that a new effect is free.

## Review Focus

1. A new material still responds to real lights and shadows once without double attenuation (Task 1).
2. Alpha coverage and additive cards on non-MSAA/GLES preserve edges and occlusion (Task 2).
3. Colour/depth selectors choose identical distributed instance subsets (Task 3).
4. A repeated strike pulse or a behind-camera strike cannot distort the wrong location (Task 4).
5. Room B, resized targets and objects behind the screen camera reflect correctly without disabling page input (Task 5).

### Task 1: Custom cloth and custom-indirect firepit materials

**Files:** create assets/materials/cloth_hooks.fmat, campfire_stone.fmat,
lib/features/cloth_lighting_feature.dart, lib/island/super_ultra/stone_lighting.dart,
test/materials/lighting_hooks_test.dart, test/render/material_binding_policy_test.dart;
modify hotel feature_catalog.dart/presets.dart/hotel_context.dart,
lib/features/placeholder_rooms.dart, rooms_feature.dart, super_ultra_rig.dart, island_scene.dart
and relevant Effects controls.

**Interfaces:**
- BeddingMaterialRole {none, jacquardPillow, woolThrow} tags Finish metadata.
  BeddingMaterialTarget carries bed node, primitive indices and original materials/textures.
- ClothLightingFeature id cloth_lighting, active in Hotel Ultra; clones/swaps the
  tagged bed primitives and retains original meshes/materials for restoration.
- StoneLighting bindings target the imported campfire_stones node/material stone
  under the placed campfire parent; a pure lighting
  value object supplies upper/lower sky colour and ambient multiplier.
- Comparison modes ClothLightingMode {standard, hooks} and StoneIndirectMode
  {engine, custom}; defaults hooks/custom in their relevant modes.

- [ ] **Step 1: Write compile and binding-policy tests.** Compiled cloth declares
  Light/Ambient/Composite; stone declares environment_lighting false and Light/Composite.
  Both use highp, correct premultiplied HDR output, texture parameters and no duplicate
  shadow multiplication. Pure binding policy restores a superseded original target
  once, handles room remount and does not alter unrelated surfaces.
  Assert only _pillowJacquard/_throwWool finishes are tagged; sleeping linen is untouched.
- [ ] **Step 2: Run failures then implement shaders from the engine hook contracts.**
  Copy the established hook signatures, not invented structs. Cloth uses wrap 0.2,
  existing rough texture shading and engine indirect. Stone implements the spec's
  controlled ambient gradient. Compare output while holding exposure fixed.
- [ ] **Step 3: Implement bindings and material-source updates.** Hotel binds existing
  photo/normal sources. Publish target indices from the room builder's byFinish groups
  through HotelContext; do not search for nonexistent pillow nodes. Retain sampler
  ownership when Phase 3 changes texture types. The exact imported stone target
  receives the scoped stone material; clone/swap mounted meshes.
  New defaults enter/leave with the quality mode and presets; add baseline toggles.
- [ ] **Step 4: Verify and commit.** Compile tests + binding tests + analyze.
  Rebuild and inspect shader logs. On Metal and GLES/Vulkan, compare day/night direct
  light, pillow shadows, fire response and roughness. Prewarm both variants.
  Record evidence and commit as feat(materials): cloth hooks and custom firepit indirect.

### Task 2: Additive core glow, grass coverage and local render order

**Files:** create assets/materials/additive_glow.fmat, grass_coverage.fmat,
lib/island/super_ultra/transparency_order.dart,
test/materials/coverage_glow_test.dart, test/island/super_ultra/transparency_order_test.dart;
modify super_ultra_fire.dart, super_ultra_rig.dart, Effects controls.

**Interfaces:**
- TransparencyOrderValues defines local core=-20/haze=-10/smoke=0. The engine sorts
  ascending within a pass; the adapter cannot reorder across passes.
- GrassCoverageMode {covered, original} defaults covered; core-glow comparison uses
  the previous sprite versus the replacement card, never both simultaneously.

- [ ] **Step 1: Write shader/ordering assertions.** Glow compiles as additive with
  depth_write false; grass as opaque/alpha_to_coverage true with highp and retained
  vertex/world-wave uniforms. Verify selected local ordering contains no duplicate
  ranks and baseline reset restores authored values.
- [ ] **Step 2: Run failures then implement the new materials.** Radial card matches
  existing core brightness; coverage uses narrow UV edge/tip alpha ramps on current
  blade geometry. Preserve rain/wind and colour controls. No broad texture conversion.
- [ ] **Step 3: Replace the core and bind the coverage material by default.**
  Keep camera-facing orientation and real geometry depth occlusion. Apply renderOrder
  only to the scoped fire stack; save authored state and restore on mode/reset changes.
  A captured frame determines whether glow was available to the haze's scene snapshot.
- [ ] **Step 4: Verify and commit.** Test covered/original in MSAA, SMAA and off;
  compare near/far grass, night fire and objects crossing the haze. Verify no duplicate
  glow, no hard square/black border and no forced smoke through foreground geometry.
  Targeted tests + shader logs + analyze; commit as feat(island): covered grass and ordered additive glow.

### Task 3: Distributed grass draw selectors and shadow caster channels

**Files:** create lib/island/super_ultra/grass_draw_policy.dart,
lib/render/shadow_channels.dart, test/island/super_ultra/grass_draw_policy_test.dart,
test/render/shadow_channels_test.dart; modify super_ultra_rig.dart,
lamps_feature.dart, spot_lights_feature.dart, owning fixture builders, presets/Effects.

**Interfaces:**
- GPU-free QualityLevel {low, medium, high} is declared in grass_draw_policy.dart.
- grassDrawCount({required int total, required QualityLevel level}) yields
  total, ceil(total*0.75), ceil(total*0.5) for high/medium/low.
- A seeded prefix-permutation generator orders the existing instance transforms once.
- grassSelector(MeshDrawContext) returns MeshDrawSelection for colour and depth using
  the same count; it never retains the mutable engine context.
- kOrdinaryLightChannel=0x01, kFixtureSelfShadowChannel=0x02,
  kFixtureExcludedCasterMask=0xFD; direct-light mask remains 0xFF.

- [ ] **Step 1: Write selection/mask tests.** Totals 0,1,13,2048 never overflow;
  low<=medium<=high; colour and depth agree; permutation contains every original
  index exactly once and early prefixes occupy the whole planted region.
  Assert ordinary walls/pillows intersect the cast mask; fixture pieces do not;
  both intersect direct-light mask. Include room B and remount/reset ownership.
- [ ] **Step 2: Run failures and implement pure policies.** Convert Scene effective
  tier to the project's enum at the adapter, not inside the pure generator.
- [ ] **Step 3: Wire default selectors and verified fixture masks.** Keep grass
  shadows off as currently authored. Record exact source-enclosing fixture parts;
  apply node masks to every eligible descendant and per-light caster masks only.
  Expose full grass density and include-fixture-shadow comparisons.
- [ ] **Step 4: Verify and commit.** Capture colour/depth selected counts, check
  spatial distribution at all tiers, then compare fixture exclusions with direct
  lamps still on. Hotel floor/door/pillow shadows and atlas budget must survive.
  Document clustering implications of nondefault node/light masks and measure cost.
  Targeted tests + analyze; commit as feat(render): grass selections and scoped shadow channels.

### Task 4: Bounded lightning shockwaves

**Files:** create lib/render/shockwave_pool.dart, shockwave_apply.dart,
test/render/shockwave_pool_test.dart; modify island super_ultra/lightning.dart,
super_ultra_rig.dart, island_scene.dart and hotel lightning_feature.dart,
feature_catalog.dart/presets.dart, relevant Effects controls.

**Interfaces:**
- StrikeId({required int generation, required int number}) identifies a scheduler
  generation and its strike number; StrikeEvent carries it and a worldPosition snapshot.
  Increment generation on scheduler replacement, number on each new strike.
- Each lightning scheduler accepts an optional onStrike(StrikeEvent) callback and
  emits once when the strike is created, before brightness-envelope oscillations.
- ShockwavePool.trigger(id, centerX, centerY), update(dt), clear(), samples getter;
  capacity4/lifetime0.65/radius0..0.6/thickness0.06/strength0.008/chromatic0.15.
- ShockwaveSample contains centerX/Y, radius, thickness, strength, chromaticAberration;
  at normalized age t, radius=0.6*t and strength=0.008*(1-t)^2. Only a last-accepted
  ID watermark is retained for deduplication; clear resets it. No unbounded ID set.
- Engine adapter projects each new event with active Camera/projectToScreenUv and
  actual viewport, then drops invisible/behind-camera events.

- [ ] **Step 1: Add pure tests.** Duplicate ids produce one pulse; pulses expire,
  capacity evicts oldest; all envelope values finite; pause/hide clears; an offscreen
  strike does not get an edge-clamped pulse. Test a new generation reusing a strike
  number after remount, rejection of older generations, and clear resetting the watermark.
- [ ] **Step 2: Run failures then implement the pool and event interfaces.**
  Preserve existing storm scheduling/brightness and callback disposal. Carry a
  world-space position, not only the island's normalized strike direction.
- [ ] **Step 3: Apply pulses on the scene tick and expose comparisons.**
  Register default hotel High/Ultra and island Super Ultra storm behavior.
  Preview creates one centered pulse; effect off, hidden tab, rain off and quality
  changes clear the pool and disable screenDistortion.
- [ ] **Step 4: Verify and commit.** Observe a deterministic preview and natural
  strikes, centre alignment under camera movement, repeated envelope peaks and
  UI overlays unaffected. Capture pass appears only while pulses live.
  Targeted tests + analyze + GPU checks; commit as feat(weather): short bounded lightning distortion.

### Task 5: Custom linear-HDR bathroom mirrors

**Files:** create assets/materials/mirror_capture.fmat,
lib/features/custom_mirror_feature.dart, lib/math/mirror_capture_layout.dart,
test/math/mirror_capture_layout_test.dart, test/features/custom_mirror_policy_test.dart,
test/materials/custom_mirror_test.dart; modify reflection_features.dart,
occlusion_feature.dart, hotel_context.dart, feature_catalog.dart, presets.dart.

**Interfaces:**
- MirrorFeature id mirror and CustomMirrorFeature id mirror_custom share
  exclusiveGroup bathroom_reflection; Ultra selects mirror_custom.
- CustomMirrorFeature owns each binding's RenderTexture, offscreen RenderView, listener,
  saved material/layers, and latest completed texture/capture VP pairing.
- HotelContext registers active auxiliary reflection cameras for occlusion visibility
  union; unregister is idempotent and owner-aware.
- computeMirrorTargetSize(width,height) preserves aspect, max512/min64.
- computeMirrorPlane(matrix, localNormal) uses inverse transpose and rejects singular
  unsupported transforms explicitly rather than reflecting in an arbitrary plane.

- [ ] **Step 1: Write math/ownership/shader tests.** Room A/B planes reflect points
  into matching handed views; viewport sizing clamps without zero targets; same
  target is reused at same dimensions. Backend toggles and late unmount preserve
  the latest owner. Shader uses its own sampler/capture matrix, linear output,
  no built-in planar_reflection input and a safe first-frame fallback.
- [ ] **Step 2: Run failing tests then implement camera/target bindings.**
  Public PlanarReflectionCamera takes active camera, transformed plane, clipBias0.001.
  Attach linearColor targets via Scene.views. .fmat raw sampler parameters rebind
  to the target's latest completed texture and its corresponding view-projection.
  Never retain an initial target-ring texture or a future frame's matrix.
- [ ] **Step 3: Integrate visibility/occlusion and exclusive backend selection.**
  Register camera unions only for active captures; preserve interactive screen-view
  routing. Dedicated receiver layer 1<<5 prevents feedback; original layers restored
  on disable. Dormant capture views are removed from Scene.views and targets/listeners
  are released using their public lifecycle, including resize and room remount.
- [ ] **Step 4: Add capture diagnostics and previous-reflector comparison.**
  A callback/label reports active captures and their dimensions. Offscreen-view
  stats validate exactly one submission per active custom mirror; no built-in
  reflector simultaneously remains attached to that receiver.
- [ ] **Step 5: Verify and commit.** Both bathrooms, daytime/night, mirrored room,
  object behind screen camera, portrait/landscape resize and rapid custom/built-in
  switching. Compare exposure once, clipping, shadow occlusion and book widget input.
  Targeted tests + analyze + full suite once Phase 2 integrates; capture frame evidence.
  Commit as feat(hotel): custom HDR mirror captures with correct lifecycle.

## Handoff

All five tasks record device evidence and a comparison setting. Phase 3 changes room
TextureSource ownership and camera projections; custom-material and reflection adapters
must accommodate those public interfaces.
