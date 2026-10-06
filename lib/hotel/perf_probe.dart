import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';
import '../features/player_feature.dart';
import '../math/fp_movement.dart';
import '../ui/hud.dart' show lastOnScreenFrame, onScreenDraws, renderedFrameCount;
import 'debug_tour.dart';
import 'hotel_scene.dart';
import 'presets.dart';

/// Views that test occlusion: each looks at a wall with something drawn
/// behind it (the bathroom, the sea, the far room).
final List<TourStop> _occlusionStops = [
  TourStop(
    name: 'sofa facing the shared wall, door shut',
    xz: Vector2(-3.0, 3.5),
    yaw: math.pi / 2,
    timeOfDay: 15.0,
  ),
  TourStop(
    name: 'desk facing the bathroom door',
    xz: Vector2(-3.0, 1.5),
    yaw: -math.pi / 2,
    timeOfDay: 15.0,
  ),
  TourStop(
    name: 'room centre facing the bed wall',
    xz: Vector2(-4.0, 4.5),
    yaw: -math.pi / 2,
    timeOfDay: 15.0,
  ),
  TourStop(
    name: 'bathroom facing the shower',
    xz: Vector2(-7.0, 1.6),
    yaw: math.pi / 2,
    timeOfDay: 15.0,
  ),
];

/// Every view the probe measures.
final List<TourStop> perfStops = [...DebugTour.stops, ..._occlusionStops];

/// Mean and 90th percentile, in milliseconds.
({double mean, double p90}) msStats(Iterable<Duration> ds) {
  final xs = ds.map((d) => d.inMicroseconds / 1000).toList()..sort();
  if (xs.isEmpty) return (mean: 0, p90: 0);
  return (
    mean: xs.reduce((a, b) => a + b) / xs.length,
    p90: xs[(xs.length * 0.9).floor().clamp(0, xs.length - 1)],
  );
}

double _pitchOf(PerspectiveCamera camera) {
  final f = (camera.target - camera.position)..normalize();
  return math.asin(f.y.clamp(-1.0, 1.0));
}

/// Profile-build frame-time probe: `flutter run --profile
/// --enable-flutter-gpu --dart-define=HOTEL_PERF=true`, optionally with
/// `HOTEL_PRESET` (default ultra) and `HOTEL_PERF_AB=<feature id>`, which
/// measures every stop with that feature off, then on. `HOTEL_PERF_SWEEP=true`
/// first prices every enabled feature at one view.
///
/// Per stop it prints Flutter's FrameTimings (UI build and raster milliseconds,
/// mean and p90), the scene's own frame rate and GPU-paced frames per second
/// (`renderStats.frameCount` less `Scene.pacedFrameCount`; Flutter's frames
/// keep coming when 0.24's pacing re-presents the last image), and the
/// on-screen draws and offscreen captures from `renderStats`, as
/// `hotel perf: ...` lines closed with `hotel perf: done`.
Future<void> maybeRunPerfProbe(HotelScene hotel) async {
  const enabled = bool.fromEnvironment('HOTEL_PERF');
  if (!enabled) return;
  const presetName = String.fromEnvironment('HOTEL_PRESET', defaultValue: 'ultra');
  const abId = String.fromEnvironment('HOTEL_PERF_AB');
  const sweep = bool.fromEnvironment('HOTEL_PERF_SWEEP');
  final preset = parsePreset(presetName) ?? Preset.ultra;
  await applyPreset(hotel.registry, preset);

  final ctx = hotel.ctx;
  final frames = <FrameTiming>[];
  void onTimings(List<FrameTiming> t) => frames.addAll(t);
  SchedulerBinding.instance.addTimingsCallback(onTimings);
  final size = PlatformDispatcher.instance.views.first.physicalSize;
  debugPrint('hotel perf: preset ${preset.name}, view ${size.width.round()}x${size.height.round()}'
      '${abId.isEmpty ? '' : ', A/B $abId'}');

  Future<void> sample(TourStop stop, String tag) async {
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    // Settled: a capture script can screenshot now.
    debugPrint('hotel perf: hold ${stop.name}$tag');
    frames.clear();
    final scene = ctx.scene;
    final startMicros = DateTime.now().microsecondsSinceEpoch;
    final startFrames = renderedFrameCount(scene), startPaced = scene.pacedFrameCount;
    await Future<void>.delayed(const Duration(seconds: 4));
    final seconds = (DateTime.now().microsecondsSinceEpoch - startMicros) / 1e6;
    final sceneFps = (renderedFrameCount(scene) - startFrames) / seconds;
    final pacedFps = (scene.pacedFrameCount - startPaced) / seconds;
    final d = onScreenDraws(lastOnScreenFrame(scene));
    final ui = msStats(frames.map((f) => f.buildDuration));
    final raster = msStats(frames.map((f) => f.rasterDuration));
    String f(double v) => v.toStringAsFixed(2);
    debugPrint('hotel perf: ${stop.name}$tag | ui ${f(ui.mean)}/${f(ui.p90)} | '
        'raster ${f(raster.mean)}/${f(raster.p90)} ms | scene ${sceneFps.toStringAsFixed(1)} fps '
        'paced ${pacedFps.toStringAsFixed(1)}/s | draws ${d?.draws ?? -1} inst ${d?.instances ?? -1} '
        'captures ${d?.offscreenViews ?? -1} | frames ${frames.length}');
  }

  void pose(TourStop stop) {
    // The walk keeps its own pitch; steer it to the stop's look-down.
    final pitchNow = _pitchOf(ctx.camera);
    applyTourStop(ctx, stop);
    final wantPitch = -stop.lookDelta.dy * kLookSensitivity;
    PlayerFeature.pendingLook = Offset(0, (pitchNow - wantPitch) / kLookSensitivity);
  }

  if (sweep) {
    // One view, each enabled feature switched off in turn: its cost is the
    // difference from the all-on lines either side.
    final stop = perfStops.first;
    pose(stop);
    await sample(stop, ' [all on]');
    final registry = hotel.registry;
    for (final f in registry.features.where((f) => f.toggleable && registry.isEnabled(f.id))) {
      await registry.setEnabled(f.id, false);
      await sample(stop, ' [-${f.id}]');
      await registry.setEnabled(f.id, true);
    }
    await sample(stop, ' [all on]');
  }

  for (final stop in perfStops) {
    pose(stop);
    if (abId.isEmpty) {
      await sample(stop, '');
    } else {
      for (final on in [false, true]) {
        await hotel.registry.setEnabled(abId, on);
        await sample(stop, ' [$abId ${on ? 'on' : 'off'}]');
      }
    }
  }
  SchedulerBinding.instance.removeTimingsCallback(onTimings);
  debugPrint('hotel perf: done');
}
