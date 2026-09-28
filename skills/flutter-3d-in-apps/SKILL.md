---
name: flutter-3d-in-apps
description: Use when adding 3D with flutter_scene to an ordinary (non-game) Flutter app, choosing which rendering effects to turn on for phones, diagnosing a slow flutter_scene frame (high UI/build time, low fps, jank), or putting 3D scenes in tabs that must keep their state and cost nothing while hidden. Written against flutter_scene 0.23.0 and Flutter 3.47.
---

# 3D in Flutter apps

> Tested with flutter_scene 0.23.0 and Flutter 3.47.2 on an iPhone 17 Pro Max (September 2026).
> Check the project's version first: `grep -A2 'flutter_scene:' pubspec.lock`. If it's newer than
> 0.23.0, treat API names, the numbers and `references/traps-0.23.md` as possibly out of date, and
> check them against the package source before relying on them. The four rules below still apply.

## Rule 1: on a phone, "UI time" is usually the GPU

flutter_scene encodes and submits every render pass from the UI thread. When the GPU falls behind,
Metal's command queue fills up and the UI thread blocks in `CreateCommandBuffer`. So the frame chart
shows high **UI** time while the Dart code is idle; `FrameTiming.rasterDuration` doesn't include the
scene's GPU work. In our hotel, 87–89% of UI-thread samples were that wait, and app logic was 1%.

- Confirm before optimising anything: sample the UI thread (`node scripts/cpuprof.mjs <ws-url> 4`).
  If the top frame is `semaphore_wait_trap` under `CreateCommandBuffer`, treat UI time as GPU time.
  This overrides flutter_scene-performance's rule that UI over budget means scene-graph/CPU work.
- Then cut GPU work (Rule 2). Don't start with Dart ticks, allocations, instancing or LOD.

## Rule 2: pull the measured levers, in this order

| Change | Measured effect (paired A/B, see `references/measured-costs.md`) |
|---|---|
| `scene.renderScale = 0.85` | 21–29% less frame time; no visible difference on a 3x screen |
| `renderScale = 0.75` | 47–49% less; slightly softer |
| Dynamic GI (irradiance probe grid) off | 5–55% less depending on the view. It exists in 0.23.0; use static light probes (captured once, ~free) |
| SSR, AO, area lights, shadowed spot lights off | 5–10% each |
| Anti-aliasing mode, bloom, light probes | ~0% — keep them; cutting them saves nothing |
| Planar reflection (mirror, water, glossy floor) | Re-renders the scene every frame. Ours cost ~0% only because its capture was layer-masked to three far objects (horizon, sun, moon); one that reflects the room pays for the room again |
| God rays, volumetric fog | ~0%, but they barely showed in our room views — not worth adding for their own sake |

Cheap isn't the same as worth it: add an effect only if a side-by-side screenshot shows it. Price
anything else with paired A/B at several camera poses on the real phone (`references/measuring.md`):
phones heat up, and the same view measured 57 fps cool and 34 fps warm.

## Rule 3: 3D tabs sleep with `TickerMode`, never with `autoTick`

Build each 3D tab on its first visit, keep it in an `IndexedStack`, and wrap every tab in
`TickerMode(enabled: selected)`. `SceneView`'s ticker obeys it, so a hidden scene renders nothing
(measured: 0.4 ms UI for the whole app with a heavy scene hidden) and comes back exactly as left.

```dart
Widget slot(int tab, WidgetBuilder build) => TickerMode(
  enabled: tab == _selected,
  child: _visited.contains(tab) ? Builder(builder: build) : const SizedBox.shrink(),
);
// body: IndexedStack(index: _selected, children: [slot(0, home), slot(1, hotel), slot(2, island)])
// onDestinationSelected: (i) => setState(() { _selected = i; _visited.add(i); })
```

Never pause by toggling `SceneView(autoTick:)`: switching it back on creates a second ticker on a
`SingleTickerProviderStateMixin`, and the tab returns as a red "multiple tickers were created" screen.
`AutomaticKeepAliveClientMixin` does nothing inside an `IndexedStack`.

## Rule 4: 2D shaders count too

A full-resolution Shadertoy-style hero shader halved the app's frame rate before any 3D was shown.
Shade into a `Picture.toImageSync` image at `min(1.5, devicePixelRatio)` pixels per logical pixel,
stretch it with `FilterQuality.low`, return early for pixels whose result is known, and put the
painter in a `RepaintBoundary`. That took the app from ~64 to 120 fps.

## Common mistakes

- Quoting a "before" and an "after" from different sessions: that mostly measures temperature.
- Reading `flutter run`'s log for probe output: in profile runs it can go silent. Read the VM
  service's `Stdout` stream (`node scripts/stdout.mjs <ws-url> 'done' 900`).
- Assuming every light casts shadows: only the sun and spot lights can in 0.23.0.
- More traps with workarounds: `references/traps-0.23.md`.
