# flutter_scene 0.24 Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Make rendering policy explicit and expose the new inspection tools without corrupting normal scene state.
**Architecture:** GPU-free policy/state models feed small Scene adapters and shared widgets. Existing hotel feature reconciliation retains ownership; island X-ray and advanced inspection share one debug owner.
**Tech Stack:** Flutter 3.47.2, Dart 3.13.2, flutter_scene 0.24.0.
**Spec:** ../specs/2026-10-06-flutter-scene-0.24-controls-design.md.
**Status:** Draft; plan only. Read the master follow-up plan before execution.

## Global Constraints

- All constraints from the spec apply, including no new dependencies and hardware-only performance claims.
- Run fvm flutter test for the owning pure/widget/shader files; run analyze after a task's edits.
- Tests do not construct Scene, Geometry, HotelPage or IslandSceneScreen.
- Existing mounted-material swaps, TickerMode and honest scene-fps calculation remain.
- Default Auto means scaleAndTier, target 60, bounds 0.6–1.0. Separate captures means explicit 8.
- Unavailable runtime checks remain pending; a setter being correct does not prove the picture.

## Review Focus

1. Auto/fixed/Auto races cannot reset the latest owner; AA teardown cannot reset scale/captures (Task 1).
2. Disabling X-ray after a two-channel wipe clears splitView and both overlay sets (Task 2).
3. Hidden/not-ready capture and depth-probe requests complete with a visible error (Task 3).
4. Pasted malformed/older capture JSON does not crash the app (Task 3).
5. Mirrored page turns retain readable text and hit-test behavior with zero overlay gap (Task 4).

## File map

Create lib/render/{quality_policy.dart,quality_apply.dart,smaa_profile.dart,
debug_comparison.dart,scene_tools.dart,capture_summary.dart},
lib/ui/{render_controls.dart,scene_tools_sheet.dart},
lib/math/book_layer_layout.dart.
Keep scene-specific wiring in hotel_context.dart, render_features.dart, presets.dart,
island_scene.dart and the two demo widgets. Engine work belongs in adapters, not widgets.

---

### Task 1: Explicit quality/capture policy and SMAA controls

**Files:** create lib/render/quality_policy.dart, quality_apply.dart, smaa_profile.dart,
lib/ui/render_controls.dart; modify lib/hotel/render_scale_control.dart,
hotel_context.dart, presets.dart, feature_catalog.dart, lib/features/render_features.dart,
lib/ui/effects_sheet.dart, lib/island/island_scene.dart, scene_app.dart,
super_ultra/super_ultra_effects.dart; tests in test/render and existing render/preset tests.
New tests: test/render/quality_policy_test.dart, quality_selection_control_test.dart,
smaa_profile_test.dart and test/ui/render_controls_test.dart.

**Interfaces:**
- Produces AdaptiveMode, AaChoice, CapturePolicy and ResolvedQualityPolicy.
- resolveQualityPolicy({required double fixedScale, required AdaptiveMode adaptiveMode,
  required AaChoice aa, required CapturePolicy captures}) returns a value object with
  baseScale, adaptive, adaptiveTiers, targetFps, minScale, maxScale, aa and captureCap.
- applyQualityPolicy(Scene scene, ResolvedQualityPolicy policy) maps the value to engine fields.
- GPU-free QualitySelectionControl exposes claimScale(owner, scale, mode)/releaseScale(owner),
  claimAa(owner, aa)/releaseAa(owner), claimCaptures(owner, policy)/releaseCaptures(owner).
  Its snapshot feeds the resolver; stale release is a no-op in each independent domain.
  Existing RenderScaleControl remains an adapter for the scale/adaptation domain.
- SmaaProfile {balanced, fast, sharp}; SmaaProfileValues has threshold, search,
  diagonal and corner; resolveSmaaProfile(profile) and applySmaaProfile(Scene, values).
- Shared RenderControls takes current values, effective readout strings and callbacks;
  it neither constructs nor retains a Scene.

- [ ] **Step 1: Write policy and ownership regression tests.** Assert fixed 0.85 disables
  adaptation; scaleOnly sets adaptive true/adaptiveTiers false/base 1; scaleAndTier sets
  both true; all adaptive choices use 60/0.6/1.0. Separate resolves 8, Shared 1, tier null.
  Test rapid scale handoffs and independent AA/capture handoffs. Releasing an AA
  owner must preserve the current scale/captures; stale releases affect no domain.
  Test invalid/nonfinite fixed scales and reject them before touching the engine.
- [ ] **Step 2: Run the new tests and confirm missing policy/ownership behavior fails.**
  Command: fvm flutter test test/render/quality_policy_test.dart
  test/render/quality_selection_control_test.dart test/features/render_scale_test.dart.
- [ ] **Step 3: Implement the policy models and adapters.** Map 8 to the exported
  maxSceneColorCaptureBatches constant in the adapter; keep the pure model GPU-free.
  Extend RenderScaleControl to own scale plus adaptation mode, using the shared
  QualitySelectionControl. AA and capture features use separate domain ownership.
  Register aa_auto in the hotel AA group. Hotel Ultra selects Auto scale + Auto AA.
  Add tier-following captures to the island picker; make Separate truly explicit.
  Apply Auto defaults in island Ultra/Super Ultra without leaving fixed-scale state behind.
  Expose the island Effects entry in Ultra; show only mode-applicable rows.
- [ ] **Step 4: Add SMAA profile tests and shared controls.** Assert balanced
  (0.1,16,8,25), fast (0.15,8,0,25), sharp (0.05,32,16,25); corner bounds 0–100.
  Widget tests use callbacks/stubs, check disabled controls outside effective SMAA,
  and check Reset updates policy and selected profiles. Implement the spec's values.
- [ ] **Step 5: Wire effective renderer readouts and the new defaults.** Show
  effectiveRenderQualityTier, effectiveAntiAliasingMode, effectiveSceneColorCaptureBatches,
  base scale times adaptiveRenderScale, scene fps and Flutter fps. Preserve explicit
  AA/capture overrides across tier transitions; update preset coverage exceptions intentionally.
- [ ] **Step 6: Verify and commit.** Targeted tests plus fvm flutter analyze lib test.
  On a GPU, perform Auto/fixed/Auto quickly in hotel and all island mode transitions.
  Drive a heavy view until tier changes; confirm Separate remains 8 and Shared remains 1.
  Confirm explicit SMAA retains its profile and compare wood/grass/pillow edges.
  Record observations, then commit as feat(render): explicit adaptive policy and SMAA controls.

### Task 2: Shared scene tools and two-channel debug views

**Files:** create lib/render/debug_comparison.dart, lib/render/scene_tools.dart,
lib/ui/scene_tools_sheet.dart, test/render/debug_comparison_test.dart,
test/ui/scene_tools_sheet_test.dart; modify lib/island/xray.dart, island_scene.dart,
scene_app.dart, lib/ui/hotel_page.dart. Task 3 extends these files.

**Interfaces:**
- DebugComparisonState carries enabled, leftId, rightId, split, animatedWipe,
  gain, rangeMin/rangeMax and left/right overlay choices; default disabled.
- SceneToolsController({required Scene scene, required Camera Function() camera,
  required bool Function() visible}); debug state is observable.
- applyDebugComparison(Scene, DebugComparisonState) owns all scene.debug fields.
- IslandScene.setXray maps its legacy quick cycle to the same owner.
- SceneToolsSheet consumes controller state and registry descriptors. Tests supply a
  presentation model/callbacks without constructing the engine controller.

- [ ] **Step 1: Write pure state tests.** Roughness/metallic IDs remain distinct;
  split clamps to 0–1; nonfinite/gain/range inputs are rejected; disabling produces
  left/right off, no split and no overlays. A normal-left comparison differs from
  a two-channel comparison. Test quality/hide reset and quick-cycle ownership.
- [ ] **Step 2: Run tests to witness failure, then implement the state and adapter.**
  Use DebugViewRegistry.entries/byId for IDs; unsupported pasted/saved IDs revert
  to none with a visible selection note. Apply splitView only when a split is active.
- [ ] **Step 3: Add widget tests and controls.** Pick left/right channels, wireframe
  on either side, gain/range, manual slider and animated wipe. Show engine labels
  grouped by registry group. Test Off/Reset restoring all choices and inspector UI
  scrolling without moving the camera.
- [ ] **Step 4: Connect both demos and disable active debug output on scene hide.**
  Keep a single owner. Do not make setXray clear overlays maintained elsewhere.
  Retain selected IDs for reopening but restore the normal scene until explicitly re-enabled.
- [ ] **Step 5: Verify and commit.** On GPU compare roughness/metallic, UV checker,
  object/material identities and validation; test right/left channel directions,
  mode switches, hidden tabs and old four-tap X-ray behavior.
  Run targeted tests and analyze; record known sea/base-colour behavior independently.
  Commit as feat(debug): shared scene inspector and two-channel comparisons.

### Task 3: Render captures, shader inspection and depth probes

**Files:** extend lib/render/scene_tools.dart and lib/ui/scene_tools_sheet.dart;
create lib/render/capture_summary.dart, test/render/capture_summary_test.dart,
test/render/scene_tools_operations_test.dart; modify the demo-widget disposal paths.

**Interfaces:**
- capture({bool withImages=false}) -> Future<CaptureSummary>.
- probeDepth() -> Future<DepthProbeSummary>; exportJson() -> String.
- CaptureSummary.fromEngineJson(Map<String,Object?>) and toJson() are GPU-free.
- OperationState {idle, running, complete, failed}; a pure coordinator accepts injected
  capture/probe futures and a visibility predicate, so races/errors can be tested.
- Controller.dispose unregisters the capture gate and discards its one retained result.

- [ ] **Step 1: Add failure and round-trip tests.** Test hidden/not-ready refusal,
  timeout, repeated tap while busy, disposed completion, malformed JSON and export/import
  preserving draw counts, node/shader names, skipped reasons and optional PNG fields.
  No GPU objects occur in test fixtures.
- [ ] **Step 2: Run failing tests and implement the coordinator and summary.**
  Prevent duplicate per-scene requests and late notifications. Global capture-enable
  ownership is reference-counted across the two demo controllers.
- [ ] **Step 3: Implement real engine operations.** captureRenderGraph viewIndex 0,
  timeout 5 s; metadata-only default; images use 128px thumbnails, no full-resolution.
  Depth probe uses actual active camera, 480x270/minPixels4. Distinguish operation
  unavailable/error/empty success; don't force hidden tabs to render.
- [ ] **Step 4: Add shader details, Copy JSON and pasted import UI.**
  Use ShaderReflection.loadAll and identity lookups. Handle unavailable backends.
  RenderGraphCaptureResult.fromJsonString validates engine capture documents; keep
  imported metadata separate from live capture bindings. Export clipboard only.
  Clear the previous capture's references before installing the next.
- [ ] **Step 5: Verify and commit.** GPU-capture each scene, compare counter summaries
  with the capture frame rather than an earlier HUD sample, export/import once,
  test a hidden-tab timeout and two concurrent scene owners. Confirm no capture or
  depth overlay pass appears while tools are idle; label capture CPU costs accurately.
  Targeted tests + analyze; commit as feat(debug): capture export and shader inspection.

### Task 4: Book depth layers and structural overlap audit

**Files:** create lib/math/book_layer_layout.dart and its test; modify
lib/features/books_feature.dart, assets/materials/page_curl.fmat,
test/features/books_feature_test.dart,
test/materials/retired_workarounds_test.dart,
docs/superpowers/notes/2026-10-06-coplanar-overlaps.md.
Only verified structural remedies may touch ocean_feature.dart, placeholder_rooms.dart
or instancing_feature.dart; document each separately.

**Interfaces:**
- BookLayerLayout has coverFrontZ, stationaryZ, curlRestZ and layer constants 0/1/2.
  factory fromCoverFront(double z) makes both overlay bases coplanar with z.
- Page materials are explicitly passed UnlitMaterials with displayReferred=false,
  depthLayer=1; curling .fmat uses depth_layer 2.

- [ ] **Step 1: Write layout/compile tests.** For arbitrary frontZ, both page bases
  equal it; physical cover thickness and dismissal plane are independent. Compile
  page_curl and check its layer=2, unlit status, model-transform path and highp body.
  Existing page-orientation and page-turn tests remain exercised.
- [ ] **Step 2: Run failing tests and implement layer ownership.** Supply custom
  materials through WidgetComponent constructor; set their own displayReferred field.
  Remove only the stationary/curl rest anti-flicker offsets. Keep mirror transforms,
  real animated displacement and the dismissal backdrop plane.
- [ ] **Step 3: Reproduce old overlap rows using the depth probe from Task 3.**
  Use both rooms, plain and tour-mounted states. Capture affected pixels and pose;
  do not classify a mathematical overlap as a visible depth fight by itself.
  Resolve demonstrably duplicate/coplanar structural geometry at its owner; never
  mask it with arbitrary depthLayer values. Intentional/absent fights remain explained.
- [ ] **Step 4: Verify visual and interaction behavior.** Physical GPU, close/far
  book views and room B; open, turn both directions, retry data loading and close.
  Confirm cover/page/curl order at rest and throughout turns. Update all five overlap
  rows with before/after classification and explicitly retain unknown results.
- [ ] **Step 5: Verify and commit.** Owning pure/shader tests + analyze; full test once
  Phase 1 is integrated. Record hardware checks and remaining rows in the phase report.
  Commit as fix(render): layered book pages and evidenced overlap remedies.

## Handoff

Leave hardware acceptance pending if unavailable. Phase 2 consumes the shared quality
policy, debug/capture controllers and the richer effective-setting readout.
