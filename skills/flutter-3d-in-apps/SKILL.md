---
name: flutter-3d-in-apps
description: Use when adding 3D with flutter_scene to an ordinary (non-game) Flutter app, choosing which rendering effects to turn on for phones, diagnosing a slow flutter_scene frame (high UI/build time, low fps, jank), or putting 3D scenes in tabs that must keep their state and cost nothing while hidden. APIs and guidance are written against flutter_scene 0.24.0 and Flutter 3.47.
---

# 3D in Flutter apps

> API guidance checked against flutter_scene 0.24.0 and Flutter 3.47.2. Measurements in
> `references/measured-costs.md` are from 0.23.0, before GPU pacing; they are historical and do not
> establish 0.24 performance. Check the project's version first: `grep -A2 'flutter_scene:'
> pubspec.lock`. If it differs, verify API names and behavior against the resolved package source.

## Rule 1: read scene fps separately from Flutter fps

With flutter_scene 0.24, GPU pacing can re-present the previous scene image while Flutter continues
to produce frames. `FrameTiming` and Flutter frame events therefore measure Flutter fps, not how
often the scene rendered a new image. Calculate scene fps from the change in
`scene.renderStats.frameCount - scene.pacedFrameCount` over wall time, and show Flutter fps and
paced frames per second beside it. A paced frame may also leave `renderStats.latest` without an
on-screen view; read draw counts from the newest recent frame that contains one.

The 0.23 profile runs recorded here had 85–89% of UI-thread samples blocked in
`semaphore_wait_trap` under `CreateCommandBuffer`, while app logic was about 1%. Treat that as
historical evidence, not a rule for 0.24. Before optimizing, sample the UI thread
(`node scripts/cpuprof.mjs <ws-url> 4`) and inspect the scene counters and render passes. High UI
time alone does not identify the scene's GPU cost.

## Rule 2: pull the measured levers, in this order

This order comes from the paired 0.23 results in `references/measured-costs.md`. Those runs predate
0.24 GPU pacing and are a starting point for experiments, not a performance ranking for 0.24.

| Change | Measured effect (paired A/B, see `references/measured-costs.md`) |
|---|---|
| `scene.renderScale = 0.85` | 21–29% less frame time; no visible difference on a 3x screen |
| `renderScale = 0.75` | 47–49% less; slightly softer |
| Dynamic GI (irradiance probe grid) off | 5–55% less depending on the view. Prefer static light probes when they meet the look |
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
- Point-light shadows are supported in 0.24; shadowed spot and point lights share a capped shadow atlas. Read `shadowCasterOverflowCount` when a requested caster is missing.
- Remaining engine traps and the historical 0.23 workarounds: `references/traps-0.23.md`.
