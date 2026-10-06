# flutter_scene 0.24 coplanar overlaps (Task 2, 2026-10-06)

Source: the debug-build log message `flutter_scene: N surface overlaps in one
plane will flicker`, printed once a scene settles (and again if the set
changes). Rows are verbatim from the logs: node A, node B, overlap count and
largest area, and the engine's hint where it printed one. Only the hint on the
`beach_palms` row exists in the logs; the engine prints no hint for the others.

All runs were `fvm flutter run -d macos --enable-flutter-gpu` (debug, macOS,
not the simulator), stopped after the time shown. The island was run in every
mode; the hotel was run on its own and under `HOTEL_TOUR`.

## Hotel (Home Demo)

| Node A | Node B | Overlaps | Largest | Hint (verbatim) | Seen in |
|---|---|---|---|---|---|
| `root/sea_horizon_0` | `root/sea_horizon_1` | 4 | 45.80 m² | none printed | every hotel run |
| `root/sea_horizon_0` | `root/sea_horizon_2` | 4 | 45.80 m² | none printed | every hotel run |
| `root/room_a/bed` | `root/room_a/bed` | 2 | 0.50 m² | none printed | the two untoured runs (11 overlaps) |
| `root/beach_palms` | `root/beach_palms` | 1 | 0.61 m² | Pieces 3.04 m long are placed 1.49 m apart, so neighbors overlap 1.56 m; make them 1.49 m long | every hotel run |
| `root/room_a/trim` | `root/room_a/tv_unit` | 2 | 0.18 m² | none printed | the tour run, second report (10 overlaps) |

Totals the engine printed: 11 overlaps (sea_horizon x8, bed x2, palms x1) on a
plain launch; 9 (sea_horizon x8, palms x1) on the tour's first report, then 10
(sea_horizon x8, trim/tv_unit x2) on its second. The bed pair is absent from
the tour run and the trim/tv_unit pair absent from the plain runs, so the set
depends on what is mounted or posed when the scene is checked. Task 10 should
treat all five rows as the list.

## Island

None reported, in any mode. The only `flutter_scene` line printed is the
depth-range notice (`depth is 32-bit float, reversed, near 0.15 m, fitted to 16 m`).

## Commands run

```bash
# hotel, plain (settled scene, book opened later through the VM service)
fvm flutter run -d macos --enable-flutter-gpu --dart-define=HOTEL_PRESET=ultra
# hotel tour (8 stops, 100 s)
fvm flutter run -d macos --enable-flutter-gpu --dart-define=HOTEL_TOUR=true --dart-define=HOTEL_PRESET=ultra
# island, each mode (80 s each), then Super Ultra with rain and lightning (~4 min)
fvm flutter run -d macos --enable-flutter-gpu --dart-define=SCENE_QUALITY=normal
fvm flutter run -d macos --enable-flutter-gpu --dart-define=SCENE_QUALITY=ultra
fvm flutter run -d macos --enable-flutter-gpu --dart-define=SCENE_QUALITY=superUltra --dart-define=SCENE_RAIN=true --dart-define=SCENE_LIGHTNING_HOLD=2
# island, mode and clock tour (120 s: normal, ultra, superUltra, ...)
fvm flutter run -d macos --enable-flutter-gpu --dart-define=SCENE_TOUR=true --dart-define=SCENE_TOUR_MODES=true
# each log searched with: grep -n "surface overlap\|^flutter:   '" <log>
```

The hotel tour ran all 8 stops (both rooms, the balcony, the bathroom, the
entrance) and began a second lap; the island tour cycled normal, ultra and
superUltra twice. Not run: the Home tab (no scene), and any device or the iOS
simulator.
