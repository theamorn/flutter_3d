# flutter_scene 0.24 Assets and Cameras Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Adopt a real ETC1S room-texture pipeline and an orthographic overview, then validate every new default on hardware.
**Architecture:** One pure asset manifest drives build-time encoding and runtime load paths. Camera projection changes use the existing node/controller, and final evidence records all three phases.
**Tech Stack:** Flutter 3.47.2, Dart 3.13.2, flutter_scene 0.24.0.
**Spec:** ../specs/2026-10-06-flutter-scene-0.24-assets-cameras-design.md.
**Status:** Draft; final integration depends on Phases 1 and 2.

## Global Constraints

- Apply all three specs' constraints. Planning does not execute commands below.
- Source images/licenses stay in the repo; default app assets contain their cooked outputs.
- Opaque room colour images use ETC1S quality192; normal maps use universal normal encoding.
- Do not re-encode embedded GLB textures through an API the package does not expose.
- loadTexture returns TextureSource, not Texture2D; claims and samplers have explicit ownership.
- Ortho overview defaults in island Normal/Ultra; Super Ultra cinematic entry remains perspective.
- All performance evidence is hardware profile/release, identical paired conditions, outside capture windows.

## Review Focus

1. Missing cooked registry/path must identify the asset rather than silently whiten a room (Task 1).
2. Concurrent room load/dispose balances shared texture claims and hot reload keeps sampler bindings current (Task 1).
3. Orthographic rays target the tapped island point within the actual tab-bar viewport (Task 2).
4. Mode switches preserve independent zooms and one ticker/controller (Task 2).
5. Profile comparisons do not confuse Flutter frame pacing, changed resolution or capture overhead with a speedup (Task 3).

### Task 1: ETC1S room colour textures with correct runtime ownership

**Files:** create lib/assets/texture_manifest.dart,
test/assets/texture_manifest_test.dart, test/features/room_texture_claims_test.dart,
tool/inspect_room_textures.dart; modify hook/build.dart, pubspec.yaml,
lib/features/room_textures.dart, rooms_feature.dart and Phase-2 cloth binding.
A GPU-free loading coordinator belongs in lib/assets/texture_claims.dart.

**Interfaces:**
- RoomTextureManifest lists exact source paths, content category and encoding choice.
  It uses only Dart core types; the build hook maps entries to engine encoding enums.
- RoomTextures.color/normal return TextureSource?; RoomTextures.load keeps one source
  claim for each successful distinct load and exposes dispose() for those claims.
- TextureClaims coordinator takes injected load/release callbacks for pure tests.
- loadTexture(sourcePath, sampling: ...) loads cooked output through the registry.
- ROOM_TEXTURES_RAW is a documented build comparison choice, not a default live duplication.

- [ ] **Step 1: Write manifest and claim tests.** Every used TextureRef colour and
  optional normal path appears exactly once; normal paths never choose ETC1S.
  Duplicate room requests share the batch; partial failure releases successful claims;
  final disposal releases each claim once. Missing registry/source error contains
  the path. Test delayed completions after disposal and failed retry.
- [ ] **Step 2: Run failures then implement the pure manifest/claims coordinator.**
  Use the actual TextureRef inventory, including hasNormal=false entries.
  Expose a testable manifest-validation function checking unexpected/missing sources.
- [ ] **Step 3: Add buildTextures to the hook.** Supply manifest paths, per-source
  TextureContent and TextureEncoding overrides; colour quality192, normal universal.
  Align input dimensions with alignForCompression true and log generated sizes.
  Keep current buildScenes/buildMaterials. Avoid generating normal mip chains as sRGB.
- [ ] **Step 4: Migrate RoomTextures and its lifecycle.** Use source-path loadTexture;
  retain reloadable TextureSource wrappers for PBR slots. Raw .fmat samplers in cloth
  bindings compare sampledTexture identity in the cloth feature tick and call setTexture
  with its matching sampler when changed; TextureSource has no addListener API.
  Balance load/release claims
  at the owning room-texture session; no release while a live material still samples it.
  Scene start errors report required texture failures instead of silent plain-color fallback.
- [ ] **Step 5: Trim default asset inclusion and add inspection tooling.**
  Search all raw asset-path users first; remove full room JPG bundling only after
  each is routed through cooked output. Retain generated texture manifest/assets.
  Implement tool output for source/generated/bundled bytes and backend formats.
  Document reproducible raw-comparison builds without leaving both whole datasets shipped.
- [ ] **Step 6: Verify and commit.** Targeted tests, analyze, rebuild and inspect
  manifest outputs/logs; load both rooms on iPhone and Android. Compare wood/textiles/
  grout and normal-map glancing response at unchanged UV scale. Verify native versus
  rgba fallback and measured load/memory rather than assuming iOS block compression.
  Mark ETC1S visual acceptance pending until observed; override failing colour candidates
  to universal with evidence. Commit as feat(assets): cooked ETC1S room colour textures.

### Task 2: Orthographic island overview with valid picking

**Files:** create lib/island/camera_projection_policy.dart,
test/island/camera_projection_policy_test.dart, test/island/orthographic_picking_test.dart;
modify island_scene.dart, scene_app.dart and existing camera/input tests.
Use existing CameraComponent and OrbitCameraController.

**Interfaces:**
- IslandCameraMode adds orthographic; perspective orbit and overTheShoulder remain.
- ProjectionState stores independent perspective distance/FOV and orthographic size/zoom.
- computeOrthographicExtent(boundsWidth,boundsDepth,aspect,margin=1.15) is pure and
  excludes ocean/backdrop bounds. Reject nonfinite or zero dimensions.
- setCameraMode reuses current controller/node and applies OrthographicProjection
  with near0.05/far400; default policy chooses ortho in Normal/Ultra, cinematic orbit
  in Super Ultra until the user explicitly selects otherwise.

- [ ] **Step 1: Write fit/transition tests.** Portrait and landscape contain the
  authored island bounds plus 15% margin; invalid sizes do not create NaNs.
  Switching twice recovers each stored zoom. Explicit camera choice survives
  quality changes; Reset returns the per-quality default.
- [ ] **Step 2: Write projection/picking tests using pure camera math.**
  Orthographic center and edge rays are parallel with different origins; hit the
  expected ground point. Use a viewport above the tab bar, not full window size.
  Perspective/shoulder rays retain current behavior. Avoid Scene or Geometry.
- [ ] **Step 3: Run failures then implement projection state and mode controls.**
  Use OrthographicSize.contain and the existing bounds; controls describe
  "Orthographic overview" and "Cinematic perspective". No second ticker/provider.
  Use active camera screenPointToRay for taps, dragging and ball selection.
- [ ] **Step 4: Verify and commit.** Both viewport orientations; overview orbit/zoom,
  taps near edges, character movement, balls and shoulder entry/exit. Compare Super
  Ultra custom reflections under orthographic and perspective; verify reset and
  hide/show. Do not require sky-disc framing to match between projection types.
  Targeted tests + analyze; commit as feat(island): orthographic overview and projection-safe picking.

### Task 3: Integrated defaults, profile evidence and documentation

**Files:** create docs/superpowers/notes/2026-10-06-flutter-scene-0.24-follow-up-verification.md;
modify README.md, learning.md, learning2.md, docs/island/06-island-scene.md,
docs/island/FLUTTER-3D-PLAYBOOK.md, skills/flutter-3d-in-apps/SKILL.md,
skills/flutter-3d-in-apps/references/{measuring.md,measured-costs.md,traps-0.23.md},
owning preset/default tests and the new follow-up plan progress checkboxes.
Do not rewrite old completed Task 1–11 evidence as if this work occurred then.

**Interfaces:**
- Evidence rows contain feature, platform/build, config/pose/time/viewport/exposure,
  applied scale/tier/AA/copy cap, observation, result and artifact path.
- Performance rows additionally contain paired order, sample duration, scene fps,
  Flutter fps, paced rate, UI/raster p90, memory and temperature/session conditions.
- Baseline comparison controls are functional before final acceptance.

- [ ] **Step 1: Add integrated default/ownership assertions.** Hotel Ultra includes
  new custom mirror and cloth plus Auto/AA Auto; island mode defaults match the spec.
  Diagnostic defaults are idle; all explicitly requested enhancements have a control
  and tested reset. Run focused tests, then the full fvm flutter test and analyze.
- [ ] **Step 2: Rebuild and prewarm materials before measurements.** No "keeping
  previous shaders", missing cooked texture or shader rejection for new defaults.
  Exercise all new materials/mirror/projection variants once outside timing windows.
- [ ] **Step 3: Perform hardware visual walkthroughs.** iPhone plus Android GPU:
  day/night/room B/viewport/hidden-tab/preset handoffs; each feature and comparison,
  malformed import, disabled/hidden capture and resized reflection target.
  Record screenshots and unavailable checks as pending. Do not call visual acceptance
  complete solely from macOS or a setter value.
- [ ] **Step 4: Measure paired hardware profile comparisons.** Use stable identical
  pose/time/exposure and settings; 2 s settle then 10 s samples, repeat at least three
  paired comparisons. Pair one feature change at a time; log actual adaptive tier/scale
  so unequal resolutions are visible. Exclude probe/capture requests from those windows.
  Record median ratios and variability; report throughput, memory and startup separately.
- [ ] **Step 5: Update documentation and plan status.** Refresh learning2.md's stale
  "hotel lane not started" section. Add current defaults and remaining-workaround notes;
  distinguish material configuration, diagnostics, automatic engine fixes and measured
  improvements. Mark only observed acceptance steps complete. Commit exact changed paths
  as docs: 0.24 follow-up defaults and device evidence.
- [ ] **Step 6: Final review and walkthrough handoff.** Resolve implementation findings
  before claiming completion. Summarize each new control, default changes, hardware
  evidence and material unresolved checks in the master roadmap. No merge/push/deploy
  is requested by this plan.

## Handoff

A plan is complete when written and reviewed; implementation is complete only after
the separate task checks and evidence above. The user requested planning first.
