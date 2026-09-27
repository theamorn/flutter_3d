import 'dart:math' as math;

/// Moves [current] toward [target] at 1/fadeSeconds per second, clamped 0..1.
double approach(double current, double target, double dt,
    {double fadeSeconds = 2.5}) {
  final delta = target - current;
  final step = math.min(delta.abs(), dt / fadeSeconds);
  return (current + delta.sign * step).clamp(0.0, 1.0);
}

/// When lightning strikes, and how bright each strike's flash is over time.
class LightningScheduler {
  LightningScheduler({required this._random, this.minGap = 4.5, this.maxGap = 12}) {
    _untilNext = _nextGap();
  }

  final math.Random _random;
  final double minGap, maxGap;
  late double _untilNext;

  double _nextGap() => minGap + _random.nextDouble() * (maxGap - minGap);

  /// Advance time; returns true on the frame a new strike should start.
  /// Counts down only while [enabled].
  bool tick(double dt, {required bool enabled}) {
    if (!enabled) return false;
    _untilNext -= dt;
    if (_untilNext > 0) return false;
    // Assign, don't add: carrying the overshoot would shorten the next gap
    // below minGap.
    _untilNext = _nextGap();
    return true;
  }

  /// 2–3 pulse start times (seconds since strike start) within 0.5 s.
  List<double> pulsesForStrike() => [
        0,
        0.12 + _random.nextDouble() * 0.08,
        if (_random.nextBool()) 0.35 + _random.nextDouble() * 0.1,
      ];

  /// Flash brightness 0..1 at [t] seconds since strike start; 0 after 0.7 s.
  /// Each pulse rises over 12 ms then decays exponentially (τ = 55 ms); the
  /// first (leader) pulse is dimmer.
  static double envelope(double t, List<double> pulseStarts) {
    if (t > 0.7) return 0;
    var sum = 0.0;
    for (var i = 0; i < pulseStarts.length; i++) {
      final local = t - pulseStarts[i];
      if (local < 0) continue;
      final rise = (local / 0.012).clamp(0.0, 1.0);
      final amp = i == 0 ? 0.4 : 1.0;
      sum += amp * rise * math.exp(-(local - 0.012) / 0.055);
    }
    return sum.clamp(0.0, 1.0);
  }
}

/// Allows a rebake at most every [minInterval] while changes keep coming,
/// plus one final rebake once changes stop.
class RebakeThrottle {
  RebakeThrottle({this.minInterval = 0.4});

  final double minInterval;
  bool _dirty = false;
  double _sinceBake = double.infinity;

  void markDirty() => _dirty = true;

  /// Call every frame; returns true when a rebake should happen now.
  bool tick(double dt) {
    _sinceBake += dt;
    if (!_dirty || _sinceBake < minInterval) return false;
    _dirty = false;
    _sinceBake = 0;
    return true;
  }
}

/// Fires once, [quiet] seconds after the last [markDirty], and never while
/// changes keep coming: for work too heavy to repeat mid-change (a probe
/// re-capture). [RebakeThrottle], by contrast, also fires during changes.
class SettleTimer {
  SettleTimer({this.quiet = 0.5});

  final double quiet;
  double? _sinceChange;

  /// Whether a change is waiting for the quiet period to end.
  bool get pending => _sinceChange != null;

  void markDirty() => _sinceChange = 0;

  /// Call every frame; true on the frame the quiet period ends.
  bool tick(double dt) {
    final since = _sinceChange;
    if (since == null) return false;
    final now = since + dt;
    if (now < quiet) {
      _sinceChange = now;
      return false;
    }
    _sinceChange = null;
    return true;
  }
}
