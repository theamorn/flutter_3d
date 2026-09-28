# Changelog

## 1.0.0 (2026-09-28)

- First release. Tested with flutter_scene 0.23.0 and Flutter 3.47.2 on an iPhone 17 Pro Max.
- Rules: UI time is GPU wait on phones; measured levers (render scale, dynamic GI); 3D tabs with
  `TickerMode`; 2D shader cost.
- References: measured costs, how to measure, traps as of 0.23.0.
- Scripts: `frames.mjs`, `cpuprof.mjs`, `waits.mjs`, `stdout.mjs` (Node 22+, no packages).
