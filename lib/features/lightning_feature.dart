import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import '../math/schedulers.dart';
import 'ocean_feature.dart' show kSeaLevel;
import 'reflection_features.dart' show kSeaReflectedLayer;
import 'sky_feature.dart' show kDayExposure, kNightExposure;

/// Debug hold: freeze the envelope at its peak for 2 s so a screenshot can
/// catch the bolt + lit room. `--dart-define=HOLD_LIGHTNING=true`.
const bool kHoldLightning = bool.fromEnvironment('HOLD_LIGHTNING');

/// How long the debug hold freezes the envelope at its peak.
const double kHoldSeconds = 2.0;

/// Top of the bolt (well above the balcony rail; the sea is at [kSeaLevel]).
const double kBoltTopY = 300;

/// In front of the window, spanning both mirrored rooms.
const double kBoltXMin = -80, kBoltXMax = 80;
const double kBoltZMin = 120, kBoltZMax = 220;

const int kBoltPasses = 6;
const double kBoltKick = 0.26;

/// Picks a random strike position in front of the window.
({double x, double z}) pickBoltXZ(math.Random rng) => (
      x: kBoltXMin + rng.nextDouble() * (kBoltXMax - kBoltXMin),
      z: kBoltZMin + rng.nextDouble() * (kBoltZMax - kBoltZMin),
    );

/// Builds a lightning bolt from `(x, kBoltTopY, z)` down to the sea
/// (`y = kSeaLevel`) by midpoint displacement: [passes] passes, each
/// inserting a midpoint kicked sideways by `kick × segment length` in a
/// random direction perpendicular to the segment. Pure and deterministic
/// for a given [rng]. Starting from 1 segment (2 points), each pass
/// doubles the segment count, so 6 passes gives 2^6 + 1 = 65 points.
List<Vector3> buildBoltPoints(double x, double z, math.Random rng,
    {int passes = kBoltPasses, double kick = kBoltKick}) {
  var points = <Vector3>[Vector3(x, kBoltTopY, z), Vector3(x, kSeaLevel, z)];
  for (var pass = 0; pass < passes; pass++) {
    final next = <Vector3>[points.first];
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i], b = points[i + 1];
      final segment = b - a;
      final segLen = segment.length;
      final mid = (a + b) * 0.5;
      final offset = _randomPerpendicular(rng, segment) * (kick * segLen);
      next
        ..add(mid + offset)
        ..add(b);
    }
    points = next;
  }
  return points;
}

/// A unit vector perpendicular to [along], sampled uniformly around it.
Vector3 _randomPerpendicular(math.Random rng, Vector3 along) {
  final arbitrary = along.x.abs() < 0.9 ? Vector3(1, 0, 0) : Vector3(0, 1, 0);
  var u = along.cross(arbitrary);
  if (u.length2 < 1e-12) u = Vector3(1, 0, 0).cross(along);
  u.normalize();
  final v = along.normalized().cross(u);
  final theta = rng.nextDouble() * 2 * math.pi;
  return u * math.cos(theta) + v * math.sin(theta);
}

/// Builds one strike's bolt (a random position plus its displaced points),
/// consuming [rng] for both.
List<Vector3> buildStrikeBolt(math.Random rng) {
  final pos = pickBoltXZ(rng);
  return buildBoltPoints(pos.x, pos.z, rng);
}

/// Room darkness used to scale the flash: 0.3 by day, 1.0 at night. Derived
/// by inverting the sky feature's own day/night log-lerp of `look.exposure`
/// (kDayExposure by day, kNightExposure at night), so it tracks whatever
/// the sky is doing without recomputing sun elevation here. Falls back to a
/// mid value if the sky feature isn't mounted (exposure stays at its 1.0
/// default).
double darknessForExposure(double exposure) {
  final t = ((math.log(exposure) - math.log(kDayExposure)) /
          (math.log(kNightExposure) - math.log(kDayExposure)))
      .clamp(0.0, 1.0);
  return 0.3 + 0.7 * t;
}

/// The `t` (seconds since strike start, in `0..0.7`) at which
/// [LightningScheduler.envelope] peaks, found by fine sampling. Pure and
/// used by the debug hold to know when to freeze.
double peakEnvelopeTime(List<double> pulseStarts) {
  var bestT = 0.0, bestE = -1.0;
  for (var t = 0.0; t <= 0.7; t += 0.001) {
    final e = LightningScheduler.envelope(t, pulseStarts);
    if (e > bestE) {
      bestE = e;
      bestT = t;
    }
  }
  return bestT;
}

class _Strike {
  _Strike(this.pulses) : peakT = peakEnvelopeTime(pulses);
  final List<double> pulses;
  final double peakT;
  double t = 0;
  bool holding = false;
  double holdRemaining = kHoldSeconds;
}

/// Lightning strikes over the sea during a storm (`ctx.weather > 0.7`): a
/// midpoint-displacement bolt, a brief shadowless flash light, and a room
/// ambient boost, both scaled by the pulse envelope and room darkness.
class LightningFeature extends HotelFeature {
  @override
  String get id => 'lightning';
  @override
  String get label => 'Lightning storm';
  @override
  CostTier get tier => CostTier.mid;
  @override
  bool get defaultOn => false;

  final math.Random _rng = math.Random();
  late final LightningScheduler _scheduler =
      LightningScheduler(random: math.Random());

  Node? _boltNode;
  TubeGeometry? _boltGeometry;
  Node? _flashNode;
  DirectionalLight? _flashLight;
  _Strike? _strike;

  /// The environment-intensity boost currently applied, so it can be backed
  /// out exactly (never compounds, never leaves residue).
  double _appliedBoost = 0;

  static final Vector4 _boltColor = Vector4(0.85, 0.92, 1.0, 1.0) * 12;

  @override
  Future<void> mount(HotelContext ctx) async {
    // Seeded with a harmless straight-down stub; the first real strike
    // reshapes it via updatePath before the node is ever shown.
    final initial = buildBoltPoints(0, (kBoltZMin + kBoltZMax) / 2, _rng);
    final geometry = _boltGeometry = TubeGeometry(
      PolylinePath(initial),
      radius: 0.4,
      radialSegments: 5,
      caps: false,
      storage: GeometryStorage.updatable,
    );
    final material = UnlitMaterial()..baseColorFactor = _boltColor;
    final bolt = _boltNode = Node(
      name: 'lightning_bolt',
      mesh: Mesh(geometry, material),
    )
      ..shadowCastingMode = ShadowCastingMode.off
      ..visible = false
      ..layers = kRenderLayerDefault | kSeaReflectedLayer;
    ctx.scene.add(bolt);

    // A separate, shadowless flash light aimed down and toward the room
    // (away from the sea), independent of Scene.environmentSettings.sunLight
    // (which the sky feature owns). It coexists as an extra entry in
    // Scene's directional-light list; it does not replace the sun.
    final light = _flashLight = DirectionalLight(intensity: 0, castsShadow: false);
    final flash = _flashNode = Node(name: 'lightning_flash')
      ..addComponent(
        DirectionalLightComponent.aimed(light, Vector3(0, -1, -0.6)..normalize()),
      );
    ctx.scene.add(flash);
  }

  @override
  void tick(HotelContext ctx, double dt) {
    if (_scheduler.tick(dt, enabled: ctx.weather > 0.7)) {
      final pulses = _scheduler.pulsesForStrike();
      _strike = _Strike(pulses);
      final points = buildStrikeBolt(_rng);
      _boltGeometry?.updatePath(PolylinePath(points));
      debugPrint('lightning strike');
    }

    final strike = _strike;
    final darkness = darknessForExposure(ctx.look.exposure);
    double envelope = 0;
    if (strike != null) {
      if (kHoldLightning && !strike.holding && strike.t >= strike.peakT) {
        strike.holding = true;
      }
      if (strike.holding && strike.holdRemaining > 0) {
        strike.holdRemaining -= dt;
      } else {
        strike.t += dt;
      }
      envelope = LightningScheduler.envelope(strike.t, strike.pulses);
      if ((!strike.holding || strike.holdRemaining <= 0) && strike.t > 0.7) {
        _strike = null;
      }
    }

    _boltNode?.visible = envelope > 0.001;
    _flashLight?.intensity = envelope * 4 * darkness;

    final boost = envelope * 0.8 * darkness;
    if (boost != _appliedBoost) {
      ctx.look.environmentIntensity += boost - _appliedBoost;
      _appliedBoost = boost;
      // No IBL rebake here: only environmentIntensity, a scalar the resolve
      // pass reads every frame, changes. The sky's own rebake throttle
      // (SkyEnvironment.invalidate) is untouched.
      ctx.applyLook();
    }
  }

  @override
  void unmount(HotelContext ctx) {
    final bolt = _boltNode;
    if (bolt != null) ctx.scene.remove(bolt);
    final flash = _flashNode;
    if (flash != null) ctx.scene.remove(flash);
    if (_appliedBoost != 0) {
      ctx.look.environmentIntensity -= _appliedBoost;
      _appliedBoost = 0;
      ctx.applyLook();
    }
    _boltNode = null;
    _boltGeometry = null;
    _flashNode = null;
    _flashLight = null;
    _strike = null;
  }
}
