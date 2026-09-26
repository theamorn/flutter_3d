import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/hotel/debug_tour.dart';
import 'package:flutter_3d/hotel/hotel_context.dart';
import 'package:flutter_3d/hotel/presets.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

class _FakeContext extends Fake implements HotelContext {
  @override
  Vector2 playerXZ = Vector2(-4, 3);
  @override
  double playerYaw = 0.0;
  @override
  final ValueNotifier<double> timeOfDay = ValueNotifier(15.0);
  @override
  final ValueNotifier<bool> rainRequested = ValueNotifier(false);
  @override
  double weather = 0.0;
  @override
  final ValueNotifier<bool> doorOpen = ValueNotifier(false);
  @override
  final PerspectiveCamera camera = PerspectiveCamera(
    position: Vector3(-4, 1.6, 3),
    target: Vector3(-4, 1.6, 6),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DebugTour stops specification', () {
    test('defines all 8 specified stops', () {
      expect(DebugTour.stops.length, 8);
      expect(DebugTour.stops[0].name, 'room A window, 15:00');
      expect(DebugTour.stops[1].name, 'room A window, 19:00');
      expect(DebugTour.stops[2].name, 'balcony looking down, 12:00');
      expect(DebugTour.stops[3].name, 'bathroom mirror, 21:00');
      expect(DebugTour.stops[4].name, 'through the open door into room B, 15:00');
      expect(DebugTour.stops[5].name, 'window in rain, 17:00');
      expect(DebugTour.stops[6].name, 'TV, 22:00');
      expect(DebugTour.stops[7].name, 'entrance with Book now showing, 15:00');
    });

    test('verifies time of day across stops', () {
      expect(DebugTour.stops[0].timeOfDay, 15.0);
      expect(DebugTour.stops[1].timeOfDay, 19.0);
      expect(DebugTour.stops[2].timeOfDay, 12.0);
      expect(DebugTour.stops[3].timeOfDay, 21.0);
      expect(DebugTour.stops[4].timeOfDay, 15.0);
      expect(DebugTour.stops[5].timeOfDay, 17.0);
      expect(DebugTour.stops[6].timeOfDay, 22.0);
      expect(DebugTour.stops[7].timeOfDay, 15.0);
    });

    test('verifies rain is enabled on stop 6 only', () {
      for (var i = 0; i < DebugTour.stops.length; i++) {
        expect(DebugTour.stops[i].rain, i == 5,
            reason: 'Stop $i (${DebugTour.stops[i].name}) rain expectation mismatch');
      }
    });

    test('verifies doorOpen is true on stop 5 (open door into room B)', () {
      expect(DebugTour.stops[4].doorOpen, isTrue);
    });
  });

  group('DebugTour application', () {
    late _FakeContext ctx;

    setUp(() {
      ctx = _FakeContext();
    });

    test('applying stop 0 updates context and camera', () {
      final tour = DebugTour(ctx, autoStart: false);
      tour.applyStop(0);

      expect(ctx.playerXZ.x, closeTo(-4.0, 0.1));
      expect(ctx.playerXZ.y, closeTo(4.8, 0.1));
      expect(ctx.playerYaw, 0.0);
      expect(ctx.timeOfDay.value, 15.0);
      expect(ctx.rainRequested.value, isFalse);
      expect(ctx.camera.position.x, closeTo(-4.0, 0.1));
      expect(ctx.camera.position.z, closeTo(4.8, 0.1));
    });

    test('applying stop 5 activates rain and weather', () {
      final tour = DebugTour(ctx, autoStart: false);
      tour.applyStop(5);

      expect(ctx.rainRequested.value, isTrue);
      expect(ctx.weather, 1.0);
      expect(ctx.timeOfDay.value, 17.0);
    });

    test('applying stop 7 places player in entrance zone for Book Now', () {
      final tour = DebugTour(ctx, autoStart: false);
      tour.applyStop(7);

      expect(ctx.playerXZ.x, closeTo(-1.8, 0.1));
      expect(ctx.playerXZ.y, closeTo(0.8, 0.1));
      expect(ctx.playerYaw, closeTo(math.pi, 0.01));
      expect(ctx.timeOfDay.value, 15.0);
    });

    test('stepping advances through all stops and wraps around', () {
      final tour = DebugTour(ctx, autoStart: false);
      expect(tour.currentIndex, 0);

      for (var i = 1; i < 8; i++) {
        tour.next();
        expect(tour.currentIndex, i);
      }

      tour.next();
      expect(tour.currentIndex, 0);
    });

    test('matches preset name case-insensitively', () {
      expect(parsePreset('low'), Preset.low);
      expect(parsePreset('Medium'), Preset.medium);
      expect(parsePreset('HIGH'), Preset.high);
      expect(parsePreset('Ultra'), Preset.ultra);
      expect(parsePreset('unknown'), isNull);
      expect(parsePreset(''), isNull);
    });
  });
}
