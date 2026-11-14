# flutter_scene 0.24 Follow-up Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Apply the requested remaining 0.24 APIs to the existing island and hotel, with scene improvements enabled by default and visible comparisons.
**Architecture:** Three independently reviewable phases share rendering controls and scene-lifecycle rules. Diagnostics and policy precede effects; asset/camera work finishes with integrated device evidence.
**Tech Stack:** Flutter 3.47.2 via fvm, Dart 3.13.2, flutter_scene 0.24.0, existing Flutter/vector_math/test dependencies.
**Spec:** The three linked draft specs below. Status: planning only, pending user review.

## Global Constraints

- No implementation, builds, installs or new dependencies are part of preparing this plan.
- Execution starts from the current flutter-scene-0.24 work after checking status; baseline at planning time is a0e0915.
- Preserve pre-existing untracked files; learning2.md is a requested documentation source, not authorization to stage unrelated files.
- User chose "Enable the new features by default"; each phase specifies exactly which defaults change.
- Inspection tools are available by default; debug output, probing and captures run on request.
- Use the per-phase specs' GPU boundary, precision, ownership, rollback and hardware-evidence rules.
- Each task requires targeted verification and a focused commit; visual/device checks remain unchecked until observed.
- Capture comparisons include the previous behavior and new behavior at the same camera, clock, quality, viewport and exposure.
- Structural overlaps are repaired with geometry when warranted; depth layers are used only for real overlays.

## Review Focus

1. Rapid hotel preset/Auto/custom-reflection handoffs: the last selection owns the applied renderer settings.
2. A hidden scene with an in-flight probe/capture: no hanging spinner, stale resources or unwanted tick restart.
3. A page turn in mirrored room B: layered faces render correctly and WidgetComponent taps still reach the pages.
4. New shader effects on GLES and Metal: valid alpha/HDR output, lighting/shadows preserved, no previous-shader fallback.
5. A tab-bar viewport, resize or camera switch: reflected captures and picking use the actual active camera and size.

---

## Phase plans and specs

| Order | Plan | Spec | Deliverables |
|---|---|---|---|
| 1 | [Controls](2026-10-06-flutter-scene-0.24-controls.md) | [Design](../specs/2026-10-06-flutter-scene-0.24-controls-design.md) | Explicit Auto/tier/copy policy, SMAA controls, debug views, captures, depth layers |
| 2 | [Scene effects](2026-10-06-flutter-scene-0.24-scene-effects.md) | [Design](../specs/2026-10-06-flutter-scene-0.24-scene-effects-design.md) | Material hooks, coverage/glow/order, draw selectors/masks, shockwaves, custom mirrors |
| 3 | [Assets and cameras](2026-10-06-flutter-scene-0.24-assets-cameras.md) | [Design](../specs/2026-10-06-flutter-scene-0.24-assets-cameras-design.md) | ETC1S room assets, orthographic overview, final hardware comparisons/docs |

Execute phase tasks sequentially in the existing workspace unless an isolated worktree
is chosen at execution. The texture task may run independently after its manifest
interface is agreed, but shared scene/UI files require sequential integration.

### Existing file locations

Phase plans abbreviate existing basenames; resolve them with this map:

| Basenames | Directory |
|---|---|
| hotel_context.dart, feature_catalog.dart, presets.dart, render_scale_control.dart | lib/hotel/ |
| books_feature.dart, render_features.dart, rooms_feature.dart, room_textures.dart, placeholder_rooms.dart, lamps_feature.dart, spot_lights_feature.dart, lightning_feature.dart, reflection_features.dart, occlusion_feature.dart, ocean_feature.dart, instancing_feature.dart | lib/features/ |
| island_scene.dart, scene_app.dart, xray.dart | lib/island/ |
| super_ultra_rig.dart, super_ultra_fire.dart, super_ultra_effects.dart, lightning.dart | lib/island/super_ultra/ |
| effects_sheet.dart, hotel_page.dart | lib/ui/ |
| FLUTTER-3D-PLAYBOOK.md | docs/island/ |

New paths are named in their owning task. Create missing test/render, test/assets
and test/math directories only when implementing their first task.

## Requested feature coverage

| User request | Owner |
|---|---|
| Material.depthLayer and old overlap reports | Phase 1 Task 4 |
| More channels and two-view comparisons | Phase 1 Task 2 |
| Render-graph capture/export and ShaderReflection | Phase 1 Task 3 |
| Explicit adaptive tier/capture policy | Phase 1 Task 1 |
| Runtime SMAA tuning | Phase 1 Task 1 |
| Light/Ambient/Composite and custom indirect lighting | Phase 2 Task 1 |
| Additive blending and alpha-to-coverage | Phase 2 Task 2 |
| Node.renderOrder | Phase 2 Task 2 |
| Draw selectors and per-light shadow masks | Phase 2 Task 3 |
| Screen distortion | Phase 2 Task 4 |
| PlanarReflectionCamera | Phase 2 Task 5 |
| ETC1S KTX2 | Phase 3 Task 1 |
| Orthographic cameras | Phase 3 Task 2 |
| Defaults, device evidence and updated learning files | All tasks; Phase 3 Task 3 integrates |

## Defaults to expect

- Hotel Ultra and island Ultra/Super Ultra: explicit automatic scale-and-tier policy,
  AA Auto and tier-following scene-copy budget; fixed settings remain comparisons.
- Hotel Ultra: custom bedding material and custom bathroom-mirror backend.
- Super Ultra: custom stone lighting, additive core glow, covered grass edges and
  tier-dependent grass density.
- Existing lightning-enabled modes: one subtle distortion pulse per strike.
- Room photo colour textures: cooked ETC1S; normal maps use universal encoding.
- Island Normal/Ultra: orthographic overview; Super Ultra cinematic entry stays
  perspective to show moon/sky, with orthographic selectable.
- Scene-tools controls exist in both demos; debug image/probes/captures start idle.

## Progress

- [ ] Phase 1 implemented and its acceptance evidence recorded.
- [ ] Phase 2 implemented and its acceptance evidence recorded.
- [ ] Phase 3 implemented and its acceptance evidence recorded.
- [ ] Hardware performance comparisons recorded; unavailable checks explicitly pending.
- [ ] Final review and user walkthrough complete.

This roadmap and its linked drafts are the requested planning deliverable.
No implementation checkbox has been marked complete.
