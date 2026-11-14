import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'badge_spin.dart';
import 'holo_badge.dart';
import 'lanyard.dart';
import 'lanyard_physics.dart';
import 'scroll_push.dart';
import 'sparkles.dart';

/// Standalone Flame game rendering a holographic member badge on a Verlet
/// spring-physics lanyard with custom GLSL thin-film foil shader.
class HoloCardGame extends FlameGame {
  HoloCardGame({
    this.onClaim,
    this.onBadgeBounds,
    this.config,
  });

  static const promoCode = 'HOLO20';
  static const backdropColor = Color(0xFF0C0A1C);

  final void Function(String code)? onClaim;
  final void Function(vm.Aabb2 bounds, double seconds)? onBadgeBounds;
  final LanyardConfig? config;

  late final LanyardWorld physics;
  late final ui.FragmentShader foilShader;
  final BadgeSpin spin = BadgeSpin();
  final ScrollPush _push = ScrollPush();
  final Stopwatch _clock = Stopwatch()..start();
  final math.Random _random = math.Random();
  bool _loaded = false;
  double _impulseDirection = 1;
  double _lastScrollAt = double.negativeInfinity;

  /// Scale factor relative to the original 124px-tall mobile card.
  double get visualScale =>
      _loaded ? physics.config.cardHeight / 124.0 : 1.0;

  /// Tilt progress (-1..1) from external scroll or discrete impulse flicks.
  double scrollProgress = 0;
  bool claimed = false;

  /// 0 -> 1 after the claim, for the foil's shift to gold.
  double claimedAmount = 0;

  /// 0 -> 1 once per claim tap, for the shine sweep; 1 means idle.
  double shine = 1;
  double elapsed = 0;
  double _lastHapticAt = double.negativeInfinity;

  double get _seconds => _clock.elapsedMicroseconds / 1e6;

  @override
  Color backgroundColor() => backdropColor;

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    final program = await ui.FragmentProgram.fromAsset(
      'shaders/holo_foil.glsl',
    );
    foilShader = program.fragmentShader();
    final resolvedConfig =
        config ??
        ((size.x >= 460 && size.y >= 520)
            ? LanyardConfig.presentation
            : const LanyardConfig());
    physics = LanyardWorld(
      width: size.x,
      height: size.y,
      config: resolvedConfig,
    );
    _loaded = true;
    await world.addAll([PromoBackdrop(), LanyardStrap(), HoloBadge()]);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (_loaded) physics.resize(size.x, size.y);
  }

  /// Feeds scroll velocity into [ScrollPush], or imparts a playful sideways
  /// lanyard flick + spin when triggered as a discrete impulse (e.g. button).
  void hostScrolled(double progress, double velocity) {
    final now = _seconds;
    scrollProgress = progress;
    _lastScrollAt = now;
    _push.addSample(velocity, now);

    if (!_loaded) return;
    if (_push.accelerationAt(now) == 0 && velocity.abs() > 0) {
      final dir = _impulseDirection;
      _impulseDirection = -_impulseDirection;
      final kick = velocity * visualScale * dir;
      physics.applyCardVelocityImpulse(
        vm.Vector2(kick, -velocity.abs() * 0.28 * visualScale),
      );
      spin.flick(dir * (velocity.abs() * 0.013).clamp(4.0, 18.0));
      final center = physics.pose.center;
      world.add(
        sparkleBurst(
          at: Vector2(center.x, center.y),
          count: 10,
          speed: 190,
          random: _random,
          scale: visualScale,
        ),
      );
      HapticFeedback.lightImpact();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_loaded) return;
    elapsed += dt;
    if (_seconds - _lastScrollAt > 0.2) {
      scrollProgress *= math.exp(-3.5 * dt);
    }

    final push = vm.Vector2(0, _push.accelerationAt(_seconds));
    final impacts = physics.step(dt, externalAcceleration: push);
    spin.step(dt);
    if (claimed) claimedAmount = math.min(1, claimedAmount + dt / 0.8);
    if (shine < 1) shine = math.min(1, shine + dt / 0.6);

    for (final impact in impacts) {
      world.add(
        sparkleBurst(
          at: Vector2(impact.position.x, impact.position.y),
          count: 8,
          speed: 160,
          random: _random,
          scale: visualScale,
        ),
      );
      if (_seconds - _lastHapticAt > 0.09) {
        _lastHapticAt = _seconds;
        HapticFeedback.lightImpact();
      }
    }
    onBadgeBounds?.call(physics.cardBounds, _seconds);
  }

  bool grab(Vector2 point) => physics.grab(vm.Vector2(point.x, point.y));

  void dragTo(Vector2 point) => physics.dragTo(vm.Vector2(point.x, point.y));

  /// A sideways throw also spins the badge around its strap.
  void release(Vector2 velocity) {
    physics.release();
    spin.flick(velocity.x * 0.012);
  }

  /// First tap claims the promo and turns the badge to show the code; later
  /// taps turn it back and forth.
  void tapBadge() {
    final center = physics.pose.center;
    if (!claimed) {
      claimed = true;
      shine = 0;
      onClaim?.call(promoCode);
    } else {
      HapticFeedback.selectionClick();
    }
    spin.flip();
    world.add(
      sparkleBurst(
        at: Vector2(center.x, center.y),
        count: claimedAmount == 0 ? 40 : 14,
        speed: 280,
        random: _random,
        scale: visualScale,
      ),
    );
  }
}
