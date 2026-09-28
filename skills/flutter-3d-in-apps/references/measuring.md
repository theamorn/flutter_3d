# Measuring a flutter_scene app on a phone

## Ground rules

- **Profile build, real device.** `flutter run --profile --enable-flutter-gpu -d <device>`. Debug
  builds and simulators say nothing about speed (a debug hotel ran 4–8 fps on the simulator).
- **Count frames, not just milliseconds.** `FrameTiming.rasterDuration` covers Flutter compositing
  the finished scene texture, not the scene's GPU work. Frames per second is the honest number.
- **Pair every comparison.** Measure the baseline, then the change, back to back at the same camera
  pose, and repeat at several poses. A before from one session and an after from another mostly
  measure the phone's temperature (the same view: 57 fps cool, 34 fps warm). Quote ratios.
- **Settle before sampling.** Wait ~2.5 s after a pose or setting change (exposure, probe captures
  and first-use pipelines converge), then sample ~4 s.
- **Read differences under ~5% as noise**, and leave out views with random events (lightning).

## The VM service URL

`flutter run` prints `A Dart VM Service ... is available at: http://127.0.0.1:PORT/TOKEN=/`.
The scripts take the WebSocket form: `ws://127.0.0.1:PORT/TOKEN=/ws`. Node 22+ has a global
`WebSocket`, so the scripts need no packages.

## Scripts (run with `node`)

| Script | Use |
|---|---|
| `scripts/frames.mjs <ws> <secs> [label]` | fps plus build/raster mean and p90 from the engine's `Flutter.Frame` events. The stream replays a backlog; the script dedupes by frame number and keeps only the last `<secs>` seconds |
| `scripts/cpuprof.mjs <ws> <secs> <label> [out.json]` | Samples the UI (main isolate) thread: top self-time functions, and flutter_scene/app functions by inclusive time |
| `scripts/waits.mjs <out.json>` | For samples blocked in `semaphore_wait_trap`, which calls led to the wait (e.g. `CreateCommandBuffer <- BloomPass._drawUpsample`) |
| `scripts/stdout.mjs <ws> <pattern> [maxSecs]` | Streams the app's stdout until a line contains `<pattern>`. Use it for probe output: `flutter run`'s own log can go silent in profile runs |

## Driving the app without touching it

- Put the A/B inside the app behind a `--dart-define` (a probe that poses the camera, applies a
  change, waits, samples `SchedulerBinding.addTimingsCallback`, prints a line, restores). Then one
  build measures every candidate at every pose with no taps.
- Pipe commands into `flutter run`: `tail -f cmd.txt | flutter run ...`, then append `r`, `R` or `q`
  to `cmd.txt` to hot reload, restart or quit from a script.
- The VM service's `evaluate` runs Dart inside the app. `WidgetsBinding.instance.handlePointerEvent`
  injects real taps; `camera.screenPointToRay` plus `scene.raycast` names the node under a pixel.
  Wrap state changes in `Future(() { ... })`: an evaluate can land mid-paint.
- With fvm, a running `fvm flutter run` holds a global lock that stalls other `fvm` commands; call
  the SDK's own `flutter` binary for tests meanwhile.
