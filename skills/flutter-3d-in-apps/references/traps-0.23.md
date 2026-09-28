# Traps in flutter_scene 0.23.0, with workarounds

Each entry is as of flutter_scene 0.23.0 / Flutter 3.47.2. On a newer version, check the package
source before applying a workaround: the trap may be fixed, or the API renamed.

## Enabling and app integration

- **Flutter GPU is opt-in**, even on 3.47: `--enable-flutter-gpu` per run, or `FLTEnableFlutterGPU`
  in `Info.plist` (iOS, macOS), `io.flutter.embedding.android.EnableFlutterGPU` meta-data (Android),
  `set_enable_flutter_gpu` on the runner's `DartProject` (Windows, Linux; needs 3.47.1).
- **`SceneView(autoTick:)` toggle**: turning it back on calls `createTicker` again on a
  `SingleTickerProviderStateMixin` → "multiple tickers were created" (debug red screen). Pause with
  an ancestor `TickerMode(enabled: false)` instead.
- **Tests can't build GPU objects**: `Scene()` and geometry throw "Flutter GPU requires the Impeller
  rendering backend" in `flutter test`. Keep maths pure; `MeshData` (CPU) is testable;
  pass stand-in widgets for 3D views in widget tests.
- **2D fragment shaders**: use `#include <flutter/runtime_effect.glsl>` and `FlutterFragCoord()`
  (widget-local logical pixels under Impeller). `gl_FragCoord` is the render target's physical pixels.

## Lighting and shadows

- **Only `DirectionalLight` and `SpotLight` cast shadows.** `PointLight` and `RectAreaLight` have
  no `castsShadow`.
- **Shadowed spot lights share the sun's shadow atlas**, one tile each at the sun's resolution, and
  the atlas can't exceed 8192 px wide. Budget `(8192 / sunResolution) - cascades` shadowed spots.
  Past it: "Texture creation failed" every frame and a black view.
- **Sun shadows vanish under a sky IBL**: the IBL has no occlusion. Set
  `SunLight.shadowAmbientStrength` (~0.5 read well) so shadowed areas lose ambient light too.
- **Any light besides the sun costs two texture uploads every frame**: `PunctualLightBuffer.build`
  runs once per frame (plus once per probe capture or GI bake) and overwrites a parameters texture
  and an index texture, each through its own command buffer. On a GPU-bound phone those submits were
  15–29% of the UI thread's waits in the hotel. Fewer lights help; unchanging lights don't skip it.
- **`PhysicalSkySource`**: exposure 1.0 clips a sunlit room to white (~0.35 by day); its sky goes
  black from dusk (no ambient floor), and its sun light colour/intensity are constants. Drive the
  light from your own time-of-day curve; the sun disk can't be switched off, only covered.
- **Bloom's threshold is compared before exposure**: with exposure 0.35, `bloomThreshold: 1.0`
  blooms everything above 0.35. Use `bloomThreshold: 1.0 / exposure`.
- **`Scene.antiAliasingMode` defaults to `auto`** (MSAA where supported), so "no AA" isn't off
  until you set `AntiAliasingMode.none`.

## Global illumination and probes

- **Dynamic GI (irradiance grid)**: probes sit on a lattice through the world origin; the outermost
  cell fades to zero, so boundary surfaces get no GI; and injection learns only from the rendered
  frame, so what the camera hasn't seen stays dark. Pad the grid a cell past every surface, keep
  planes out of thin walls, and keep it off by default on phones.
- **A reflection probe in the frame-wide cross-fade overrides every material**, outdoor ones
  included. Keep probes at `weight: 0` and bind each material to its own probe.
- **A probe capture renders the scene lit by the previous capture**: one extra bounce per capture.
  Queue two captures if a change must be exact.

## Materials and `.fmat`

- **`primitive.material = m` on a mounted node is ignored.** Assign a new mesh over the same
  geometry: `node.mesh = node.mesh!.clone()..primitives.single.material = m`.
- **Planar reflections need a lit `.fmat`** with `engine_inputs: [planar_reflection]`; unlit is
  rejected and `PhysicallyBasedMaterial` never opts in.
- **A `scene_color` reader costs a full-screen copy per reader in view.** Swap such materials in
  only while needed (e.g. rain on glass only while raining). With MSAA the split also re-resolves.
- **A translucent `.fmat` with `depth_write: true` reads its own depth** through `scene_depth`
  (zero thickness everywhere). Water: `depth_write: false`.
- **`.fmat` syntax**: `shading_model:` (not `shading:`), a quoted `name:`, parameters as
  `material_params.x`, `culling` defaults to `back`, and `flat` is a reserved GLSL word.

## Geometry, culling and widgets

- **No occlusion culling** (frustum only). Hide with `MeshPrimitive.visible`: `node.visible = false`
  also switches off that node's lights and shadows.
- **`InstancedMesh` is one geometry and one material**: merge multi-part props into one `MeshData`
  with vertex colours. Walkers that read `Node.mesh` don't see instanced batches.
- **`WidgetComponent`'s built-in quad** draws only for a camera looking down the node's +Z, and
  mirrored. Point +Z along the view and scale x by −1, or pass your own geometry.
- **View basis**: facing +Z, screen-right is +X. Pin hand-written projection or picking maths
  against `camera.screenPointToRay` / `camera.worldToScreen` in unit tests.

## Particles

- `ParticleEmitterComponent` steps its system every frame: don't also call `system.step()`.
- Built-in emitter shapes emit along +Y; wrap a shape to flip it rather than rotating a node.
- `ParticleEmitterComponent.system` is final; gate a burst-only effect with `paused`.
