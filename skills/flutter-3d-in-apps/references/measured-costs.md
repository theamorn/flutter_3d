# Measured costs (flutter_scene 0.23.0)

All numbers: iPhone 17 Pro Max, profile builds, Flutter 3.47.2, flutter_scene 0.23.0, September
2026. The scenes: a hotel (two furnished rooms, sea view, PBR, sky IBL, sun cascades, lamps,
rain and lightning) and an island (terrain, water, vegetation, fire). Quote ratios, not absolute
fps: the phone's temperature moves absolute numbers as much as most changes do.

## Paired A/B against the hotel's "ultra" preset

Each row: ultra measured, then ultra with one change, back to back at the same pose (4 s each,
after a 2.5 s settle). "Frame" is UI (build) time, which on this device is mostly GPU wait.

| Change | Room A window | Entrance (slowest view) |
|---|---|---|
| renderScale 0.85 | 25.5 → 32.8 fps (frame −21%) | 12.5 → 17.0 fps (−29%) |
| renderScale 0.75 | 23.2 → 40.0 fps (−49%) | 12.5 → 22.5 fps (−47%) |
| Dynamic GI off | −28% in one run, −5% in another | 14.8 → 29.8 fps (−55%) |
| renderScale 0.85 + dynamic GI off | 18.8 → 27.0 fps (−35%) | 13.0 → 26.0 fps (−52%) |
| renderScale 0.75 + dynamic GI off | 18.8 → 35.0 fps (−50%) | 12.5 → 29.0 fps (−61%) |
| MSAA → SMAA | +5% (slower) | — |
| MSAA → FXAA | −3% | — |
| SSR off | −10% | −10% |
| Area lights off | −7% | −7% |
| Spot lights off (2 shadowed) | −6% | — |
| AO off | −7% | — |
| Bloom off | +11% (slower; unexplained) | — |
| God rays off | −1% | — |
| Volumetric fog off | +3% | — |
| Sea planar reflection off (capture layer-masked to the horizon walls, sun and moon only) | 0% | — |
| Light probes off (static captures) | 0% | — |

Across all 12 hotel views, ultra with renderScale 0.85 and dynamic GI off drew **1.41×** the frames
of plain ultra (18.5 → 26.0 fps mean; median ×1.47, range ×1.11–×1.72). By eye, 85% couldn't be told
apart from full resolution.

Earlier twelve-view medians (on minus off, same device): area lights +5 ms UI (2–11) and +2 ms raster;
spot lights about +3/+2 ms; dynamic GI at least +6 ms UI (up to +12 in a single-view sweep).

## Where the UI thread's time went (VM CPU sampling, 3.5 s at a settled view)

| Scene | Blocked in `semaphore_wait_trap` under `CreateCommandBuffer` | Where it waited (not what each pass costs) |
|---|---|---|
| Hotel, room A window | 87% | Bloom passes 40%, punctual-light upload 29%, shadows 12% |
| Hotel, entrance | 89% | Bloom 52%, light upload 15%, resolve 11%, shadows 8% |
| Island, Super Ultra | 85% | Scene pass 37%, SSAO blur 39% |

App feature logic (all per-frame ticks) was 0.8%. A wait's location shows which pass submitted while
the queue was full, not which pass costs the most GPU time: bloom was the top waiter, yet switching it
off saved nothing.

## Whole-app numbers

| Situation | Result |
|---|---|
| Island, simple mode | 120 fps, UI 3.0 ms, raster 0.5 ms |
| Island, heaviest mode | ~37 fps (UI 21–22 ms) in one session, ~60 fps (UI 11–12 ms) in another |
| Hotel ultra, full resolution | 10–25 fps across 12 views |
| Home page with the island's heaviest mode alive in a hidden tab (`TickerMode` off) | 120 fps, UI 0.34–0.41 ms, raster 0.77–0.86 ms |
| Ray-marched sea shader as a hero (a third of a 3x screen) at full resolution | 63–66 fps of 120, raster 13.5–14.2 ms mean, 33–35 ms p90 (debug build) |
| Same, shaded at 1.5x into an image, sky skipped above the horizon | 115–120 fps, raster ~0.6 ms (debug); 120 fps in profile, even at the roughest waves |
| Same hotel view, cool phone vs warm phone | 57 fps vs 34 fps |
