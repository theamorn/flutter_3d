# flutter_scene 0.24 follow-up: assets and cameras design

Status: draft for user review. Planning only.
Date: 2026-10-06.
Depends on controls and scene-effects phases for final integration.
The texture task can be developed in isolation after its manifest interface is fixed.

## Intent and constraints

Make the requested ETC1S pipeline useful for the current hotel photo textures and
provide an orthographic island overview. New features are defaults in their relevant
contexts, with explicit previous-behavior comparison paths. Use Flutter 3.47.2,
flutter_scene 0.24.0, fvm and existing dependencies. Tests follow the GPU boundary
and performance evidence rules in the controls spec.

## Texture pipeline

Room textures are separate assets/textures/*.jpg files, currently decoded at runtime
by RoomTextures.load via Texture2D.fromAsset. Preserve source files and licenses in
the repository; cook them in the existing hook before loading the rooms.

Introduce one shared pure texture_manifest.dart: room IDs, source paths, colour versus
normal content, encoding decision and sampling. Both hook and RoomTextures use it.
No flutter/dart:ui imports may enter the manifest used by the build-hook isolate.

Defaults:
- Opaque colour photos: TextureEncoding.etc1s(quality: 192), TextureContent.color.
- Normal maps: TextureEncoding.universal, TextureContent.normal.
- Alpha sprites, project-generated normals and masks stay on their existing paths.
- Input dimensions must be multiples of four or use buildTextures alignForCompression
  true, recording source/generated sizes. Do not stretch UV metres or texel density.
- Embedded GLB textures are outside this compression task: 0.24 buildScenes still
  uses its own encoding for those, so only the separate room assets adopt ETC1S.

ETC1S does support alpha, but its encoder can consume substantial memory/time for
large alpha images, and its per-block hue representation is unsuitable for our
normal detail. Neither "opaque only" nor "every texture can be compressed equally"
is an accurate restriction.

Hook calls buildTextures with explicit source list, contents and encoding overrides.
RoomTextures stores TextureSource rather than Texture2D and loads cooked assets by
source path through loadTexture. Maintain per-source reference claims; release
partially loaded claims on failures and release all claims when room textures are
disposed. Concurrent/remounted room loads must not double-release one shared source.

Cooked registry absence/errors produce a visible scene-start error naming the path,
not a silently white room. Change only the RoomTextures path that owns these images;
keep unrelated procedural textures unchanged. The phase-2 cloth materials bind
TextureSource.sampledTexture/sampledSampler. TextureSource is not Listenable: the
cloth feature tick compares sampledTexture identity and rebinds setTexture only when
it changes, retaining the matching sampler. Do not invent source.addListener.

Change pubspec asset inclusion so full source JPGs do not ship alongside cooked room
textures. Inspect all source-path references first. Build-hook source access does
not require bundling source images. Generated manifests/texture assets continue to ship.
A build-time comparison option ROOM_TEXTURES_RAW restores raw sources with a documented
temporary manifest for paired builds; do not duplicate full originals in the default
bundle solely for an A/B toggle. A small two-texture comparison fixture is sufficient
for an in-app quality demonstration.

Acceptance uses wood grain, white tiles, textiles and normal-map grazing highlights.
Record generated texture bytes, bundle asset bytes, time to load, memory format and
fallback behavior. iOS may choose an rgba fallback instead of native BC/ETC2; smaller
disk encoding is not proof of smaller GPU memory or higher fps.
ETC1S becomes the default once its visual/device checks pass; a failing candidate
uses the documented higher-quality encoding override instead of claiming a lossless result.

## Orthographic overview

Add IslandCameraMode.orthographic; retain orbit perspective and overTheShoulder.
Normal/Ultra default to the new overview; Super Ultra initially chooses the cinematic
perspective mode that shows the custom moon/sky. Orthographic is one tap away there.
A user-selected camera mode is preserved across quality changes, except entering/
leaving shoulder mode applies the existing character-control rules.
Reset explicitly reapplies the per-quality initial camera mode.

Use the existing camera node and CameraComponent, changing projection rather than
building a second ticker/controller. Fit an OrthographicProjection to the island's
authored interactive bounds, excluding the 318-m sea and distant backdrop. Use
OrthographicSize.contain(width, height), margin 1.15, near 0.05 and far 400.
Initial position/target follow the island overview, with orthographic view size derived
from its bounds and current view aspect. Existing OrbitCameraController handles zoom;
shoulder uses the original perspective projection. Store perspective and orthographic
zoom separately so a switch does not jump to an unrelated scale.

Tap-to-move uses the active camera's screenPointToRay. Character selection, drag
controls and ball interactions use that same active projection. Validate portrait,
landscape, zero-size layouts and viewport above the tab bar. No viewport measurement
may use a full-window size when the scene occupies less than the window.
Orthographic sky/reflections use engine support; a moon-disc composition is inherently
different from the perspective cinematic shot and must not be presented as identical.

## Final evidence and documentation

Update learning.md and refresh learning2.md's stale Tasks 9–11 status.
Document newly selected defaults and comparisons in README.md,
docs/island/06-island-scene.md, docs/island/FLUTTER-3D-PLAYBOOK.md and the local app skill.
Old upgrade checkboxes remain complete. New plans use unchecked implementation steps.

Create docs/superpowers/notes/2026-10-06-flutter-scene-0.24-follow-up-verification.md
with per-feature implementation/automated/runtime/profile evidence.
Record uncertain checks as pending rather than converting a setter value into a
rendering or frame-rate result. Capture overhead must be excluded from performance
windows. Prewarm new material pipelines before paired timing windows.

Final validation:
- Targeted unit/widget/shader checks after each task; full flutter test and analyze
  once each integrated phase is stable.
- Physical iPhone visual checks for all new defaults; Android native GPU checks for
  shader portability and compressed-texture formats; macOS is additional evidence.
- Hardware profile A/B pairs at identical poses/settings after temperature settles,
  repeat at least three pairs, recording both scene and Flutter rates and applied tier/scale.
- If a backend/device is unavailable, document it and leave its acceptance unchecked.
