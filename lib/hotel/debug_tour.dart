import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math.dart';
import '../features/player_feature.dart';
import '../math/fp_movement.dart';
import 'hotel_context.dart';
import 'hotel_scene.dart';
import 'presets.dart';

/// Specification for a single fixed tour viewpoint and environment state.
class TourStop {
  const TourStop({
    required this.name,
    required this.xz,
    required this.yaw,
    required this.timeOfDay,
    this.pitch = 0.0,
    this.rain = false,
    this.doorOpen = false,
    this.lookDelta = Offset.zero,
  });

  final String name;
  final Vector2 xz;
  final double yaw;
  final double timeOfDay;
  final double pitch;
  final bool rain;
  final bool doorOpen;
  final Offset lookDelta;
}

/// Matches preset name case-insensitively, or returns null.
Preset? parsePreset(String name) {
  if (name.isEmpty) return null;
  for (final p in Preset.values) {
    if (p.name.toLowerCase() == name.toLowerCase()) return p;
  }
  return null;
}

/// Automated tour stepper that visits 8 showcase scenes every 8 seconds.
class DebugTour {
  DebugTour(this.ctx, {this.interval = const Duration(seconds: 8), bool autoStart = true}) {
    if (autoStart) start();
  }

  final HotelContext ctx;
  final Duration interval;
  Timer? _timer;
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  static final List<TourStop> stops = [
    // 1. room A window, 15:00
    TourStop(
      name: 'room A window, 15:00',
      xz: Vector2(-4.0, 4.8),
      yaw: 0.0,
      timeOfDay: 15.0,
    ),
    // 2. room A window, 19:00
    TourStop(
      name: 'room A window, 19:00',
      xz: Vector2(-4.0, 4.8),
      yaw: 0.0,
      timeOfDay: 19.0,
    ),
    // 3. balcony looking down, 12:00
    TourStop(
      name: 'balcony looking down, 12:00',
      xz: Vector2(-3.0, 6.8),
      yaw: 0.0,
      pitch: -0.4,
      timeOfDay: 12.0,
      lookDelta: const Offset(0, 80),
    ),
    // 4. bathroom mirror, 21:00
    TourStop(
      name: 'bathroom mirror, 21:00',
      xz: Vector2(-6.8, 0.55),
      yaw: -math.pi / 2,
      timeOfDay: 21.0,
      lookDelta: const Offset(0, -80),
    ),
    // 5. through the open door into room B, 15:00
    TourStop(
      name: 'through the open door into room B, 15:00',
      xz: Vector2(-1.5, 2.45),
      yaw: math.pi / 2,
      timeOfDay: 15.0,
      doorOpen: true,
    ),
    // 6. window in rain, 17:00
    TourStop(
      name: 'window in rain, 17:00',
      xz: Vector2(-4.0, 4.8),
      yaw: 0.0,
      timeOfDay: 17.0,
      rain: true,
    ),
    // 7. TV, 22:00
    TourStop(
      name: 'TV, 22:00',
      xz: Vector2(-6.7, 3.8),
      yaw: math.pi,
      timeOfDay: 22.0,
    ),
    // 8. entrance with Book now showing, 15:00
    TourStop(
      name: 'entrance with Book now showing, 15:00',
      xz: Vector2(-1.8, 0.8),
      yaw: math.pi,
      timeOfDay: 15.0,
    ),
  ];

  /// Applies the stop at [index] and logs `hotel tour: <stop name>`.
  void applyStop(int index) {
    _currentIndex = index % stops.length;
    final stop = stops[_currentIndex];

    ctx.playerXZ = stop.xz.clone();
    ctx.playerYaw = stop.yaw;
    ctx.timeOfDay.value = stop.timeOfDay;
    ctx.rainRequested.value = stop.rain;
    ctx.weather = stop.rain ? 1.0 : 0.0;
    ctx.doorOpen.value = stop.doorOpen;

    if (stop.lookDelta != Offset.zero) {
      PlayerFeature.pendingLook = stop.lookDelta;
    }
    aimCamera(ctx.camera, FpState(stop.xz, stop.yaw, stop.pitch));

    debugPrint('hotel tour: ${stop.name}');
  }

  /// Advances to the next tour stop.
  void next() => applyStop((_currentIndex + 1) % stops.length);

  /// Starts the tour cycle.
  void start() {
    applyStop(0);
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => next());
  }

  /// Disposes timer resources.
  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Checks environment variables and starts the debug tour if requested.
Future<DebugTour?> maybeStartDebugTour(HotelScene scene) async {
  const isTour = bool.fromEnvironment('HOTEL_TOUR');
  if (!isTour) return null;

  assert(kDebugMode, 'HOTEL_TOUR is only supported in debug builds');

  const presetName = String.fromEnvironment('HOTEL_PRESET');
  if (presetName.isNotEmpty) {
    final preset = parsePreset(presetName);
    if (preset != null) {
      await applyPreset(scene.registry, preset);
    }
  }

  return DebugTour(scene.ctx);
}
