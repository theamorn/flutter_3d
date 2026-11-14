# flutter_scene 0.24 follow-up: controls and diagnostics design

Status: draft for user review. Planning only; implementation is not authorized by this document.
Date: 2026-10-06.
Baseline: flutter-scene-0.24, a0e0915; original upgrade Tasks 1–11 are complete.

## Intent and decisions

The user requested a plan for the remaining 0.24 capabilities and explicitly selected
"Enable the new features by default". Scene improvements therefore become defaults in
their relevant quality modes. Inspection tools are available by default, but replacing
the rendered scene with a debug channel, probing depth, and taking captures requires
a user action. Controls retain a previous-behavior comparison.

Phase 1 establishes shared rendering policy, inspection controls and real depth-layer
usage in the current hotel and island. Phase 2 adds scene effects and materials.
Phase 3 integrates compressed textures and cameras. Each phase has its own plan and
can be reviewed independently.

Sources: the official [0.24 changelog](https://pub.dev/packages/flutter_scene/changelog),
the installed flutter_scene-0.24.0 package source, the original upgrade plan, learning.md,
learning2.md, and the coplanar-overlap note. learning2.md predates Tasks 9–11;
its "not started" paragraph is historical and must not drive implementation.

## Constraints

- Flutter 3.47.2 via fvm; flutter_scene resolves to 0.24.0. No new dependencies.
- Use existing Effects entry points, hotel feature registration and island mode handling.
- Split new models/adapters/widgets into focused files; avoid placing new subsystems inside scene_app.dart.
- GPU-free tests exercise policies, ownership, serialization and widget controls. They never construct Scene, Geometry or real demo pages.
- Shader compile tests may use the existing pure compileFmat helper.
- Preserve TickerMode pausing and scene fps calculated from frameCount minus pacedFrameCount.
- All custom shader bodies declare highp for project world-space/procedural calculations.
- Runtime checks require a real GPU. Simulator black screenshots are a capture limitation.
- Only profile/release measurements on hardware support performance claims.
- Default enhancements follow each mode/preset, and Reset returns to the newly documented defaults.

## Explicit quality policy

Add pure project enums AdaptiveMode {fixed, scaleOnly, scaleAndTier}, AaChoice
{auto, none, fxaa, smaa, msaa, taa}, and CapturePolicy {tier, separate, shared}.
A pure resolver returns base scale, adaptive, adaptiveTiers, target fps, scale bounds,
AA choice and capture cap. The engine adapter maps those choices to Scene.

For scaleOnly and scaleAndTier: base scale 1.0, target 60, min 0.6, max 1.0.
scaleOnly sets adaptiveTiers false; scaleAndTier sets it true. Fixed uses the requested
scale and disables adaptation. Explicit Separate means cap 8, the exported
maxSceneColorCaptureBatches in 0.24.0; Shared means 1; tier-following means null.
The existing Separate=null mapping is incorrect once tier adaptation is allowed.

Defaults:
- Island Ultra and Super Ultra: scaleAndTier, AA auto, captures tier, target 60.
- Island Normal: existing fixed scale 0.75 and existing lighting/content.
- Hotel Ultra: render_scale_auto + new aa_auto feature, captures tier; existing fixed
  85% and MSAA choices remain comparisons. Other hotel presets retain their existing
  fixed policies unless selecting Auto.
- New policy controls offer scaleOnly as a predictable-resolution adaptation option.
- Readouts show scene fps, Flutter fps, effective tier, actual applied scale
  (base scale multiplied by adaptive multiplier), effective AA and effective capture cap.
- Hotel selection ownership is independent for scale/adaptation, AA and captures.
  Each domain has its own owner token; stale teardown cannot overwrite its latest
  selection or reset another domain. Resolve the current domain selections together.
- Explicit user AA or capture choices continue to override tier defaults.

Expose the island Effects entry in Ultra as well as Super Ultra. Only applicable
rows appear in each mode, so Ultra's new policy defaults have reachable comparisons.

SMAA profiles, available in both Effects surfaces:
Engine/balanced = threshold 0.1, search 16, diagonal 8, corner rounding 25.
Fast = 0.15, 8, 0, 25. Sharp = 0.05, 32, 16, 25.
Balanced is the default. A 0–100 corner control permits comparison. The row is
enabled only when effective AA is SMAA; switching AA retains the chosen profile.

## Debug comparisons

Introduce one SceneToolsController per demo and one owner of scene.debug.
The existing X-ray button delegates to this owner; it never independently clears
another tool's state. Shared pure DebugComparisonState contains enabled, left/right
view IDs, split fraction, wipe animation, gain, scalar range, and overlays.

List DebugViewRegistry entries instead of duplicating channel enum names. Include
roughness, metallic, UV/checkers, identity, validation and depthGap. Normal lit image
is the default left view; users may select a second debug channel, invoking splitView.
Wipe or manual split is supported. Reset, disabling inspection, scene hiding and
leaving an applicable quality mode restore view none, split/splitView null and both
overlay sets empty. Settings may be remembered, but no stale debug output is rendered.

Depth-conflict overlay and probe buttons state that they add rendering work.
probeDepthConflicts runs only on request, at 480 x 270, minPixels 4. The live overlay
is independently enabled and cleared. A dismissed panel does not strand a probe spinner.

## Captures and shader inspection

Controller signature:
SceneToolsController({required Scene scene, required Camera Function() camera,
required bool Function() visible}).

Expose capture({bool withImages = false}), probeDepth(), exportJson(), and dispose().
Capture capability is registered once per live tools controller through an app gate;
the global debugAllowRenderGraphCapture flag is restored when the last controller
unregisters. Each controller permits one operation at a time.

Default capture: metadata only, screen-view index 0, timeout 5 seconds.
Optional images: thumbnailMaxDim 128, fullResolution false.
Summaries show pass CPU timings, draw/instance counts, skipped items with reasons,
resource sizes and shader names. Those CPU timings are not GPU timer measurements.
Use ShaderReflection.loadAll and info/source lookups to display backend bindings and
compiled source. Missing reflection/source metadata is an explicit unavailable state.

Keep one capture in memory per scene. Replace/drop its resources on recapture or
dispose; use only public lifecycle APIs and do not invent a capture.dispose method.
Export through Copy JSON using Flutter Clipboard; accept pasted JSON for offline
inspection via RenderGraphCaptureResult.fromJsonString. No sharing plugin or network
upload is needed. Imported captures restore metadata/thumbnails, not live GPU textures.

## Depth layers and overlap evidence

Use an actual existing layering candidate: the open book cover, stationary pages,
and curling page at rest. Their small Z offsets are recorded in books_feature.dart,
even though the initial coplanar scanner did not report this dynamic state.
Keep cover thickness and the dismissal backdrop's separate interaction plane.
Define cover layer 0, stationary-page layer 1, curling-page layer 2.
Place overlay bases at the cover's front plane rather than relying on the two
anti-flicker millimetre offsets. Preserve mirrored text orientation, page input,
animated curl displacement and the genuine volume of the book.

WidgetComponent has a material constructor argument but no public material getter.
Supply a per-page UnlitMaterial explicitly with displayReferred=false and depthLayer=1;
the component's displayReferred argument does not override a supplied material.
Set page_curl.fmat depth_layer to 2. Compare flat/rest poses and moving page poses.

For the five old overlap pairs, run depth probes at reproducible hotel-tour poses.
Actual structural fights require geometry changes, not depth-layer assignments.
Intentional intersecting foliage and hidden faces may remain with an evidenced
explanation. Do not shorten whole palm instances merely because a bounding overlap
suggests a repeated-piece length. Record before/after results per pair and distinguish
"resolved", "intentional", and "not reproduced"; never claim an empty log without it.

## Acceptance

- Auto quality, AA and capture choices report exactly what the renderer applies.
- Rapid hotel fixed/Auto/fixed handoffs leave the last selection active.
- X-ray and the advanced panel share ownership; disabling either restores the scene.
- Capture/probe requests complete or fail visibly; hidden tabs and repeat requests do not hang.
- Book layers remain stable during orbit, page turns and room-B mirroring; book taps still work.
- Depth results report the five structural rows honestly.
- Controls can be exercised on a physical iPhone; Android GPU checks cover GLES/Vulkan behavior.
