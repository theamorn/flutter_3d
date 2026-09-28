# Flutter 3D

A Flutter demo app for **Seaside Family Hotel**, combining a hotel landing page, an interactive first-person room tour, and an island playground. The 3D scenes use `flutter_scene` and Flutter GPU; the landing page uses animated fragment shaders.

## Explore the app

- **Home:** animated sea and sky, room options, amenities, and a booking quote screen with dates, guest counts, and prices in Thai baht.
- **Home Demo:** walk through connected hotel rooms with the on-screen joystick, drag the right side to look around, and tap interactive objects. Adjust the time of day, toggle rain, and use the Effects panel to compare quality presets and individual rendering features.
- **Island Demo:** tap to move around an island with animated characters, birds, a campfire, and physics objects. Compare Normal, Ultra, and Super Ultra quality modes; Super Ultra adds procedural terrain, ocean, grass, rain, lightning, and adjustable effects.

Scenes load when their tab is first opened, keep their state between visits, and pause rendering while their tab is hidden.

## Requirements

- Flutter **3.47.2**, pinned in [.fvmrc](.fvmrc), with Dart **3.13.2** or a compatible version satisfying `pubspec.yaml`.
- A native Flutter target with Flutter GPU and Impeller support. The project includes iOS, Android, and desktop runner directories; a browser is not the target for these GPU scenes.
- The platform toolchain for your chosen device, such as Xcode for iOS or macOS, or the Android SDK for Android.
- [FVM](https://fvm.app) if you want to use the pinned SDK through the commands below.

## Run locally

```sh
fvm install
fvm flutter pub get
fvm flutter devices
fvm flutter run --enable-flutter-gpu -d <device-id>
```

Replace `<device-id>` with an ID from `flutter devices`. If the correct SDK is already on your PATH, use `flutter` in place of `fvm flutter`.

The build hook in [hook/build.dart](hook/build.dart) imports the GLB models and compiles the custom `.fmat` materials. It generates engine-specific assets in `flutter_scene_generated/`, whose contents are ignored by Git. Rebuild the app after changing custom materials.

## Quality and performance

The hotel offers Low, Medium, High, and Ultra presets alongside individual effects. Ultra uses an 85% render scale; dynamic global illumination is available as a manual option. The island has its own Normal, Ultra, and Super Ultra modes and effects controls.

Use a physical device in profile mode to compare performance:

```sh
# Open the hotel directly and measure its fixed tour stops.
fvm flutter run --profile --enable-flutter-gpu -d <device-id> \
  --dart-define=HOTEL_PERF=true --dart-define=HOTEL_PRESET=ultra

# Open the island directly in Super Ultra and log frame timings.
fvm flutter run --profile --enable-flutter-gpu -d <device-id> \
  --dart-define=SCENE_QUALITY=superUltra --dart-define=SCENE_FRAME_STATS=true
```

These debug defines select the corresponding demo tab at startup. Higher quality modes add lighting, reflections, shadows, and post-processing passes, so performance depends on the device, scene, and selected effects. See [learning.md](learning.md) for recorded measurements and rendering findings.

## Development checks

```sh
fvm flutter analyze lib test
fvm flutter test
```

Tests cover booking calculations, tab navigation, feature registration and presets, collision and picking math, weather, island physics, and procedural effects. GPU visuals also need a native-device or simulator smoke test.

## Project layout

| Path | Purpose |
| --- | --- |
| `lib/app/`, `lib/home/`, `lib/ui/` | App shell, landing page, booking UI, and scene controls |
| `lib/hotel/`, `lib/features/` | Hotel scene, feature registry, presets, and rendering features |
| `lib/island/` | Island scene, movement, physics, particles, and Super Ultra effects |
| `lib/math/`, `lib/data/` | Geometry, collision, scheduling, booking, and data helpers |
| `assets/`, `shaders/`, `hook/` | Models, textures, custom materials, fragment shaders, and asset build hook |
| `test/` | Unit and widget tests |
| `tool/` | Tour capture and image comparison scripts |
| `docs/` | Design notes, implementation plans, and island documentation |
| `skills/flutter-3d-in-apps/` | Reusable development guidance and profiling tools for Flutter 3D |

## Assets and credits

Model sources and modifications are documented in [assets/models/CREDITS.txt](assets/models/CREDITS.txt). Room textures and their sources are documented in [assets/TEXTURE_CREDITS.md](assets/TEXTURE_CREDITS.md).
