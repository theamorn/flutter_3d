import 'package:flutter_3d/render/shockwave_pool.dart';
import 'package:flutter_test/flutter_test.dart';

StrikeId id(int generation, int number) => StrikeId(generation: generation, number: number);

void main() {
  group('ShockwavePool', () {
    test('one strike makes one pulse; the same id again makes none', () {
      final pool = ShockwavePool();
      expect(pool.trigger(id(1, 1), 0.5, 0.5), isTrue);
      expect(pool.trigger(id(1, 1), 0.5, 0.5), isFalse);
      expect(pool.samples, hasLength(1));
    });

    test('a pulse grows and fades on the spec envelope, then expires', () {
      final pool = ShockwavePool()..trigger(id(1, 1), 0.3, 0.4);
      var s = pool.samples.single;
      expect(s.centerX, 0.3);
      expect(s.centerY, 0.4);
      expect(s.radius, 0);
      expect(s.strength, closeTo(0.008, 1e-12));
      expect(s.thickness, 0.06);
      expect(s.chromaticAberration, 0.15);
      pool.update(0.325); // half the 0.65 s life
      s = pool.samples.single;
      expect(s.radius, closeTo(0.3, 1e-9));
      expect(s.strength, closeTo(0.008 * 0.25, 1e-12));
      pool.update(0.33);
      expect(pool.samples, isEmpty);
    });

    test('every envelope value stays finite, even for odd time steps', () {
      final pool = ShockwavePool()..trigger(id(1, 1), 0.5, 0.5);
      for (final dt in [0.0, 1e-9, 0.016, 0.2, double.nan, -1.0, double.infinity]) {
        pool.update(dt);
        for (final s in pool.samples) {
          for (final v in [s.centerX, s.centerY, s.radius, s.thickness, s.strength, s.chromaticAberration]) {
            expect(v.isFinite, isTrue, reason: 'dt $dt');
          }
          expect(s.radius, inInclusiveRange(0, 0.6));
          expect(s.strength, inInclusiveRange(0, 0.008));
        }
      }
    });

    test('at capacity the oldest pulse makes room', () {
      final pool = ShockwavePool();
      for (var n = 1; n <= 5; n++) {
        pool.trigger(id(1, n), n / 10, 0.5);
        pool.update(0.01);
      }
      expect(pool.samples, hasLength(ShockwavePool.capacity));
      expect(pool.samples.map((s) => s.centerX), isNot(contains(0.1)));
      expect(pool.samples.map((s) => s.centerX), contains(0.5));
    });

    test('a strike off screen gets no pulse, never one clamped to the edge', () {
      final pool = ShockwavePool();
      expect(pool.trigger(id(1, 1), -0.2, 0.5), isFalse);
      expect(pool.trigger(id(1, 2), 0.5, 1.4), isFalse);
      expect(pool.trigger(id(1, 3), double.nan, 0.5), isFalse);
      expect(pool.samples, isEmpty);
      // A rejected strike does not use up the watermark either.
      expect(pool.trigger(id(1, 1), 0.5, 0.5), isTrue);
    });

    test('a remounted scheduler starts a new generation that may reuse numbers', () {
      final pool = ShockwavePool()..trigger(id(1, 7), 0.5, 0.5);
      expect(pool.trigger(id(2, 1), 0.5, 0.5), isTrue);
      expect(pool.trigger(id(1, 8), 0.5, 0.5), isFalse, reason: 'older generation');
      expect(pool.trigger(id(2, 1), 0.5, 0.5), isFalse, reason: 'duplicate');
      expect(pool.trigger(id(2, 2), 0.5, 0.5), isTrue);
    });

    test('clear (pause, hide, rain off) drops pulses and resets the watermark', () {
      final pool = ShockwavePool()..trigger(id(3, 9), 0.5, 0.5);
      pool.clear();
      expect(pool.samples, isEmpty);
      expect(pool.trigger(id(1, 1), 0.5, 0.5), isTrue);
    });

    test('the preview pulse is centred and does not move the watermark', () {
      final pool = ShockwavePool()..preview();
      expect(pool.samples.single.centerX, 0.5);
      expect(pool.samples.single.centerY, 0.5);
      expect(pool.trigger(id(1, 1), 0.2, 0.2), isTrue);
    });
  });

  group('StrikeId', () {
    test('orders by generation, then number', () {
      expect(id(2, 1).isAfter(id(1, 9)), isTrue);
      expect(id(1, 2).isAfter(id(1, 1)), isTrue);
      expect(id(1, 1).isAfter(id(1, 1)), isFalse);
      expect(id(1, 1).isAfter(id(2, 0)), isFalse);
      expect(id(1, 1), id(1, 1));
    });
  });

  group('StrikeCounter', () {
    test('numbers strikes within a generation and bumps the generation on replace', () {
      final counter = StrikeCounter();
      final a = counter.next();
      final b = counter.next();
      expect(b.isAfter(a), isTrue);
      counter.replaceScheduler();
      final c = counter.next();
      expect(c.generation, a.generation + 1);
      expect(c.number, 1);
      expect(c.isAfter(b), isTrue);
    });
  });
}
