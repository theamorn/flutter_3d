# Hotel Task 9 physical iPhone shadow check (2026-10-06)

Status: range corrected and Task 9 Step 5 complete after the follow-up below.

Initial revision: `a1924c1`, branch `flutter-scene-0.24`. Device: Bank’s iPhone Duo,
`00008150-001A30DC2687801C`, iOS 27.0. Debug build with Metal/Impeller.

```bash
fvm flutter run -d 00008150-001A30DC2687801C --enable-flutter-gpu \
  --dart-define=HOTEL_TOUR=true --dart-define=HOTEL_PRESET=ultra \
  --host-vmservice-port=65109
```

The tour timer was stopped through the VM service, the clock set to 22:00,
rain/lightning disabled, and the camera held at each comparison viewpoint.
Frames were captured using the Flutter widget inspector; its capture includes
black padding on the right. No performance measurement was made.

| Check | Result |
|---|---|
| Startup with preload and warm-up | Hotel built, installed and rendered on the physical iPhone. |
| Reading-light pillow shadows | Observed in both rooms. In room A, disabling only the spot shadow flags while keeping the lights showed the pillow shadows disappearing. Normal feature ticks were resumed afterward. |
| Shadow atlas budget | `shadowCasterOverflowCount` was 0 in both rooms with bath shadows enabled and the reading lights on. Room A spots: `[true, false, true, false]`; room B: `[false, true, false, true]`, preserving camera-room selection. |
| Bathroom door-frame shadow on the floor | Failed with the shipped settings. Both bulbs are at y = 2.6499999 m, with range 2.6 m. Even the nearest floor point is outside the light's range. |

## Bathroom range finding

`LampsFeature` attaches each bulb 0.15 m below the 2.8 m ceiling. Its existing
`kBathLightRange` is 2.6 m. In the engine's `material_lighting.glsl`, the
distance window is clamped to zero at and beyond range; the bulb radius does
not extend that window. Thus this point light contributes no direct light to
the floor, and enabling its shadows cannot produce the planned floor shadow.
The bathroom doorway threshold is about 3.02 m from the bulb.

For diagnosis only, the live bulbs' range was temporarily set to 4.0 m.
The bathroom floor visibly brightened. A distinct projected door-frame floor
shadow was still not established in these views. A permanent range adjustment
needs a repeat of the doorway on/off comparison. The original 2.6 m range was
restored before ending the run; no application source was changed.

This initial check left Task 9 Step 5 unchecked for the range defect.

## Range correction and physical-device recheck

Changed `kBathLightRange` to 4.0 m while retaining intensity 1.5 and radius
0.06 m. The new regression mounts actual lights at the authored fixture pose
in both mirrored rooms and requires each doorway floor edge to lie within
85% of the light's range, keeping it away from the attenuation cutoff.
It failed with the original range (3.0467 m receiver distance versus a 2.21 m
margin boundary), and the final suite passes all 483 tests. Analysis is clean;
three existing missing-brace infos in GI/render code were corrected without
changing their behavior. Focused code review approved the fix.

Built and ran the changed source on the same physical iPhone with Ultra at
22:00. VM readback confirms both bulbs have range 4.0 m, bath shadows enabled,
and overflow zero. The camera was held at mirrored doorway views and the
bed; reading-light pillow shadows remained visible.

The doorway comparisons show the point shadow affecting floor shading beside
the wall/jamb. With the ambient lights on, the effect is subtle. Auto exposure
also changes brightness when shadows toggle, so the final comparison disabled
Auto exposure temporarily to hold the sky's scheduled exposure fixed. All
other lighting stayed in place, and normal Auto exposure and controls were
restored before ending the run. The floor comparison is visual acceptance,
not a performance measurement.

Saved comparison images:

- Doorway: [shadows on](hotel-ios-task9/bath-shadows-on.jpg), [shadows off](hotel-ios-task9/bath-shadows-off.jpg).
- Floor beside the jamb: [shadows on](hotel-ios-task9/bath-jamb-shadows-on.jpg), [shadows off](hotel-ios-task9/bath-jamb-shadows-off.jpg).

Task 9 Step 5 is complete. Physical-device verification substitutes for the
plan's simulator check at the user's explicit request. The simulator itself
was not rerun. Follow-up logs: `/tmp/hotel-bath-range-ios.log`,
`/tmp/hotel-bath-range-tests-final.log`, `/tmp/hotel-bath-range-analyze.log`.

## Local evidence

- Run/build log: `/tmp/hotel-task9-ios.log`.
- Original bathroom comparison: `/tmp/hotel-ios-bath-on.png`, `/tmp/hotel-ios-bath-off.png`.
- Reading comparison: `/tmp/hotel-ios-reading-on.png`, `/tmp/hotel-ios-reading-off.png`.
- Mirrored room: `/tmp/hotel-ios-reading-room-b.png`.
- Temporary range experiment: `/tmp/hotel-ios-bath-range-on.png`, `/tmp/hotel-ios-bath-range-off.png`, `/tmp/hotel-ios-door-on.png`, `/tmp/hotel-ios-door-off.png`.

The screenshots and VM helper scripts are temporary local artifacts.
