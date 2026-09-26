import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/features/water_fx_feature.dart';

/// Steps [system] by [seconds] worth of 60Hz fixed steps.
void _stepSeconds(ParticleSystem system, double seconds) {
  final steps = (seconds * 60).round();
  for (var i = 0; i < steps; i++) {
    system.step(1 / 60);
  }
}

void main() {
  group('buildFaucetStreamSystem', () {
    test('emits straight down: velocity has a negative Y component', () {
      final system = buildFaucetStreamSystem(rate: 1000);
      system.step(1 / 60);
      expect(system.storage.aliveCount, greaterThan(0));
      for (var i = 0; i < system.storage.aliveCount; i++) {
        expect(system.storage.velY[i], lessThan(0));
      }
    });

    test('a spread cone stays close to the axis (half-angle 0.12 rad)', () {
      final system = buildFaucetStreamSystem(rate: 1000);
      system.step(1 / 60);
      expect(system.storage.aliveCount, greaterThan(0));
      for (var i = 0; i < system.storage.aliveCount; i++) {
        final vx = system.storage.velX[i];
        final vy = system.storage.velY[i];
        final vz = system.storage.velZ[i];
        final horizontal = (vx * vx + vz * vz);
        // cos(0.12) ~= 0.9928, so the vertical component dominates.
        expect(vy.abs(), greaterThan(horizontal));
      }
    });

    test('rate switches the emitter fully off and back on', () {
      final off = buildFaucetStreamSystem(rate: 0);
      _stepSeconds(off, 1.0);
      expect(off.storage.aliveCount, 0);

      final on = buildFaucetStreamSystem(rate: 0);
      _stepSeconds(on, 0.5);
      expect(on.storage.aliveCount, 0);
      on.spawner.rate = 180;
      _stepSeconds(on, 0.2);
      expect(on.storage.aliveCount, greaterThan(0));
    });

    test('matches the brief verbatim: lifetime 0.35s, speed 0.6, size 0.012',
        () {
      final system = buildFaucetStreamSystem(rate: 1000);
      system.step(1 / 60);
      expect(system.lifetime, isA<ConstantFloat>());
      expect((system.lifetime as ConstantFloat).value, 0.35);
      expect((system.startSpeed as ConstantFloat).value, 0.6);
      expect((system.startSize as ConstantFloat).value, 0.012);
      expect(system.gravity.y, closeTo(-9.8, 1e-4));
    });
  });

  group('buildShowerStreamSystem', () {
    test('disc emitter (zero cone angle) fires exactly straight down', () {
      final system = buildShowerStreamSystem(rate: 1000);
      system.step(1 / 60);
      expect(system.storage.aliveCount, greaterThan(0));
      for (var i = 0; i < system.storage.aliveCount; i++) {
        expect(system.storage.velX[i], 0.0);
        expect(system.storage.velZ[i], 0.0);
        expect(system.storage.velY[i], lessThan(0));
      }
    });

    test('spawn positions stay within the 0.12 disc radius', () {
      final system = buildShowerStreamSystem(rate: 1000);
      system.step(1 / 60);
      expect(system.storage.aliveCount, greaterThan(0));
      for (var i = 0; i < system.storage.aliveCount; i++) {
        final x = system.storage.posX[i];
        final z = system.storage.posZ[i];
        expect(x * x + z * z, lessThanOrEqualTo(0.12 * 0.12 + 1e-9));
      }
    });

    test('rate switches 0 <-> value', () {
      final system = buildShowerStreamSystem(rate: 0);
      _stepSeconds(system, 0.5);
      expect(system.storage.aliveCount, 0);
      system.spawner.rate = 600;
      _stepSeconds(system, 0.1);
      expect(system.storage.aliveCount, greaterThan(0));
    });
  });

  group('buildSteamSystem', () {
    test('rate 0 (shower off) never spawns', () {
      final system = buildSteamSystem(rate: 0);
      _stepSeconds(system, 2.0);
      expect(system.storage.aliveCount, 0);
    });

    test('rate 12 (shower on) rises straight up with no gravity', () {
      final system = buildSteamSystem(rate: 12);
      // 12/s needs >= 1/12 s to accumulate a whole particle to spawn.
      _stepSeconds(system, 1.0);
      expect(system.storage.aliveCount, greaterThan(0));
      for (var i = 0; i < system.storage.aliveCount; i++) {
        expect(system.storage.velX[i], 0.0);
        expect(system.storage.velZ[i], 0.0);
        expect(system.storage.velY[i], closeTo(0.15, 1e-6));
      }
      expect(system.gravity, Vector3.zero());
    });

    test('matches the brief verbatim: 12/s, lifetime 4s, alpha 0.12', () {
      final system = buildSteamSystem(rate: 12);
      expect(system.spawner.rate, 12);
      expect((system.lifetime as ConstantFloat).value, 4.0);
      final sampled = system.startColor.sample(0, 0, Vector4.zero());
      expect(sampled.w, closeTo(0.12, 1e-6));
    });
  });

  group('buildFaucetSplashSystem', () {
    test('is a repeating burst of small droplets kicking upward', () {
      final system = buildFaucetSplashSystem();
      expect(system.spawner.bursts, hasLength(1));
      final burst = system.spawner.bursts.single;
      expect(burst.count, 3);
      expect(burst.interval, 0.06);
      expect(burst.cycles, isNull); // repeats forever while unpaused

      const dt = 1 / 60.0;
      system.step(dt);
      expect(system.storage.aliveCount, greaterThan(0));
      for (var i = 0; i < system.storage.aliveCount; i++) {
        // SphereEmitterShape(hemisphere: true) only samples the +Y half, so
        // the *spawn* velocity is >= 0; back out this step's one increment
        // of gravity to recover it (storage only exposes post-integration
        // values).
        final spawnVelY = system.storage.velY[i] + system.gravity.y.abs() * dt;
        expect(spawnVelY, greaterThanOrEqualTo(-1e-4));
      }
    });
  });

  test(
    'the basin offset documents where faucet_spout (y=1.05) meets the '
    'basin rim (y=0.85), from lib/features/placeholder_rooms.dart',
    () {
      expect(faucetSplashLocalYOffset, closeTo(0.85 - 1.05, 1e-9));
    },
  );
}
