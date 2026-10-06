# Traps recorded in flutter_scene 0.23.0, with 0.24.0 follow-up

The sections below preserve the 0.23.0 behavior and workarounds on which the old measurements and
incidents were based. The final section lists traps checked against flutter_scene 0.24.0. For a
different package version, check the package source before applying a workaround.

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

- **Shadow support changed in 0.24.** In 0.23 only `DirectionalLight` and `SpotLight` cast
  shadows. 0.24 adds point-light shadows and caps shadowed spots and points at four each; use
  `Scene.shadowCasterOverflowCount` and `Scene.isShadowCasterGranted` to check the budget.
- **Sun shadows vanish under a sky IBL**: the IBL has no occlusion. Set
  `SunLight.shadowAmbientStrength` (~0.5 read well) so shadowed areas lose ambient light too.
- **Punctual-light upload cost was measured on 0.23.** `PunctualLightBuffer.build` overwrote two
  textures per frame and those submits accounted for 15–29% of the hotel's UI-thread waits. In
  0.24, unchanged light textures are no longer re-uploaded and froxel clustering replaces the
  per-object light cap; remeasure any remaining cost on the target device.
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
- **Scene-colour capture cost depends on overlap.** In 0.23 each reader used its own full-screen
  copy. In 0.24, `scene_color_reach` lets non-overlapping readers share a capture, and
  `Scene.sceneColorCaptureBatches` caps the copies per frame. With MSAA, splitting the pass also
  re-resolves.
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

## Still open in flutter_scene 0.24.0

The engine behavior below was checked against the 0.24 package source and remains open. The final
Kenney `.glb` item retains this repository's asset guidance; the 0.24 changelog does not cover those
asset-specific rules, so assume they are unchanged and verify them with the models you import.

- **Changing a mounted node's material:** assigning `primitive.material` is ignored. Assign a new
  mesh over the existing geometry with `node.mesh = node.mesh!.clone()..primitives.single.material = m`;
  `MeshComponent.refreshMaterials()` remains internal.
- **Physical-sky night lighting:** keep the `skyAt()` schedule that solves sky energy, lifts the sun
  above the horizon and lets the moon take over. `PhysicalSkySource.sunLightColor` is still constant
  and its shader still has no ambient floor.
- **Widget pages:** keep the `WidgetComponent` look-at-the-view and x-mirror setup. 0.24 makes pages
  display-referred by default; pass `displayReferred: false` when they should respond to exposure,
  tone mapping and fog.
- **Pausing a view:** use `TickerMode`, not `SceneView(autoTick:)`; the view still uses a single
  ticker provider.
- **Rain collision:** use analytic proxies for instanced geometry. `raycast.dart` still marks
  instanced-mesh raycasting and a BVH as TODOs.
- **Planar reflections:** `planar_reflection` still requires a lit `.fmat`; keep `mirror.fmat` and
  `ocean.fmat` lit.
- **Kenney glTF assets:** keep the repository's pruning and conversion rules: remove unreachable or
  duplicate nodes, embed textures instead of URI sidecars, set metallic to zero, replace
  `KHR_materials_unlit` when the model must respond to scene lighting, and account for portal
  culling. 0.24's Vulkan unlit fix does not change the lighting behavior of an unlit material.
