import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import 'interaction_registry.dart';

/// Faucet stream + basin splash + shower stream + shower steam, per room.
///
/// Both rooms are mirrored on X (room B is room A under `scale.x = -1`, see
/// `wave-d-constraints.md`). Every emitter here only ever throws particles
/// straight along local Y (down for water, up for steam) and every shape used
/// is radially symmetric in the local XZ plane, so the X mirror never changes
/// what an emitter looks like — there is nothing room-B-specific to handle.
class WaterFxFeature extends HotelFeature {
  @override
  String get id => 'water_fx';
  @override
  String get label => 'Faucet + shower particles';
  @override
  CostTier get tier => CostTier.mid;

  // On by default: the faucet and shower taps are registered here, so with
  // this off they can't be tapped at all. It costs nothing until the water
  // runs (every emitter is paused while off).

  final List<_Faucet> _faucets = [];
  final List<_Shower> _showers = [];

  @override
  Future<void> mount(HotelContext ctx) async {
    final waterTexture = _softDotTexture();
    final steamTexture = _softDotTexture(softness: 2.2);

    for (final node in ctx.nodesNamed('faucet_spout')) {
      final faucet = _Faucet(node, waterTexture);
      _faucets.add(faucet);
      ctx.interactions.register(faucet.interaction);
    }
    for (final node in ctx.nodesNamed('shower_head')) {
      final shower = _Shower(node, waterTexture, steamTexture);
      _showers.add(shower);
      ctx.interactions.register(shower.interaction);
    }
  }

  @override
  void unmount(HotelContext ctx) {
    for (final faucet in _faucets) {
      ctx.interactions.unregister(faucet.interaction);
      faucet.dispose();
    }
    _faucets.clear();
    for (final shower in _showers) {
      ctx.interactions.unregister(shower.interaction);
      shower.dispose();
    }
    _showers.clear();
  }

  @override
  void tick(HotelContext ctx, double dt) {
    for (final faucet in _faucets) {
      faucet.settle();
    }
    for (final shower in _showers) {
      shower.settle();
    }
  }
}

// --------------------------------------------------------------- emission

/// Wraps [inner] and flips the sampled position/velocity across Y, so a
/// shape that only knows how to emit along local +Y (every built-in
/// [EmitterShape] in flutter_scene 0.23.0) instead emits along local −Y.
///
/// Positions/velocities set by [inner] stay radially symmetric in X and Z
/// (both [ConeEmitterShape] and a zero-angle cone used as a disc sample the
/// XZ plane uniformly), so this flip is the only change needed to make a
/// faucet or shower head point down; nothing about it depends on which room
/// (or which X-mirror) the emitter's node sits under.
class _DownwardShape extends EmitterShape {
  const _DownwardShape(this.inner);
  final EmitterShape inner;

  @override
  void sample(ParticleStorage storage, int index) {
    inner.sample(storage, index);
    storage.posY[index] = -storage.posY[index];
    storage.velY[index] = -storage.velY[index];
  }
}

final Vector4 _waterColor = Vector4(0.65, 0.82, 0.95, 0.6); // light blue, alpha 0.6
final Vector3 _waterGravity = Vector3(0, -9.8, 0);

/// The faucet's falling stream, verbatim per the brief: a cone emitter
/// pointing −Y, 180/s, lifetime 0.35s, speed 0.6, size 0.012, gravity −9.8,
/// alpha 0.6 light blue, velocity-stretched billboards.
ParticleSystem buildFaucetStreamSystem({double rate = 180}) => ParticleSystem(
  maxParticles: 128,
  shape: const _DownwardShape(ConeEmitterShape(angle: 0.12, radius: 0.01)),
  spawner: Spawner(rate: rate),
  lifetime: const ConstantFloat(0.35),
  startSpeed: const ConstantFloat(0.6),
  startSize: const ConstantFloat(0.012),
  startColor: ConstantColor(_waterColor),
  gravity: _waterGravity,
);

/// A tiny splash where the stream meets the basin (brief: "a tiny splash
/// burst at the basin, y = 0.85"). `faucet_spout` sits at room y = 1.05
/// (`lib/features/placeholder_rooms.dart`), 0.2 above the basin rim at
/// y = 0.85, so the splash emitter is a child of the spout offset by
/// (0, −0.2, 0). A few droplets kick sideways-and-up off the impact point
/// every 0.06s for as long as the emitter is unpaused — [ParticleEmitterComponent.system]
/// is final, so on/off toggling here pauses the component (which also
/// freezes system time, so the repeating burst resumes on the same cadence)
/// rather than rebuilding the system.
ParticleSystem buildFaucetSplashSystem() => ParticleSystem(
  maxParticles: 64,
  shape: const SphereEmitterShape(radius: 0.01, hemisphere: true),
  spawner: Spawner(
    bursts: const [ParticleBurst(time: 0, count: 3, interval: 0.06)],
  ),
  lifetime: const ConstantFloat(0.18),
  startSpeed: const UniformFloat(0.15, 0.35),
  startSize: const ConstantFloat(0.008),
  startColor: ConstantColor(_waterColor),
  gravity: _waterGravity,
);

/// The offset from `faucet_spout` (y = 1.05) down to the basin rim (y = 0.85).
const double faucetSplashLocalYOffset = -0.2;

/// The shower's falling stream (brief: a disc emitter radius 0.12 at
/// shower_head, 600/s, lifetime 0.6s, speed 1.0). A zero-angle cone samples a
/// uniform disc in the XZ plane while emitting straight along the axis, i.e.
/// exactly a disc emitter; wrapped the same way to point −Y. Gravity/alpha
/// are not called out separately in the brief, so the stream reuses the
/// faucet's water color and gravity for visual consistency.
ParticleSystem buildShowerStreamSystem({double rate = 600}) => ParticleSystem(
  maxParticles: 512,
  shape: const _DownwardShape(ConeEmitterShape(angle: 0, radius: 0.12)),
  spawner: Spawner(rate: rate),
  lifetime: const ConstantFloat(0.6),
  startSpeed: const ConstantFloat(1.0),
  startSize: const ConstantFloat(0.01),
  startColor: ConstantColor(_waterColor),
  gravity: _waterGravity,
);

final Vector4 _steamColor = Vector4(0.9, 0.92, 0.95, 0.12); // alpha 0.12

/// Puffs grow slightly as they rise and dissipate, from 60% to 160% of their
/// spawn size over their life.
final ParticleCurve _steamGrowthCurve = ParticleCurve.linear(
  from: 0.6,
  to: 1.6,
);

/// Steam while the shower is on (brief: 12/s large soft puffs rising at
/// 0.15 m/s, lifetime 4s, alpha 0.12). Emits straight up (local +Y, no flip
/// needed — steam rises), a point emitter so puffs start together near the
/// shower head and drift apart under a light upward drag-free rise.
ParticleSystem buildSteamSystem({double rate = 0}) => ParticleSystem(
  maxParticles: 64,
  shape: PointEmitterShape(direction: Vector3(0, 1, 0)),
  spawner: Spawner(rate: rate),
  lifetime: const ConstantFloat(4.0),
  startSpeed: const ConstantFloat(0.15),
  startSize: const UniformFloat(0.35, 0.55),
  startColor: ConstantColor(_steamColor),
  modules: [SizeOverLifeModule(CurveFloat(_steamGrowthCurve))],
);

// ------------------------------------------------------------- room glue

/// How far the faucet lever tilts up while the water runs (≈ 26°).
const double kLeverLift = 0.45;

/// The lever's transform: [rest] (where the room builder put it) when off,
/// tilted up about its pivot when [on]. The lever points along local +X.
Matrix4 faucetLeverPose(Matrix4 rest, {required bool on}) =>
    on ? rest.multiplied(Matrix4.rotationZ(kLeverLift)) : rest.clone();

class _Faucet {
  _Faucet(this.node, Texture2D waterTexture) {
    stream = ParticleEmitterComponent(
      system: buildFaucetStreamSystem(rate: 0),
      material: SpriteMaterial(colorTexture: waterTexture)
        ..blendMode = SpriteBlendMode.alpha,
    )..facing = BillboardFacing.velocityStretched;
    streamNode = Node(name: 'faucet_stream')
      ..shadowCastingMode = ShadowCastingMode.off
      ..raycastable = false
      ..addComponent(stream);

    splash = ParticleEmitterComponent(
      system: buildFaucetSplashSystem(),
      material: SpriteMaterial(colorTexture: waterTexture)
        ..blendMode = SpriteBlendMode.alpha,
    )..paused = true;
    splashNode = Node(
      name: 'faucet_splash',
      localTransform: Matrix4.translationValues(
        0,
        faucetSplashLocalYOffset,
        0,
      ),
    )
      ..shadowCastingMode = ShadowCastingMode.off
      ..raycastable = false
      ..addComponent(splash);

    node.add(streamNode);
    node.add(splashNode);

    for (final child in node.children) {
      if (child.name == 'faucet_lever') {
        lever = child;
        leverRest = child.localTransform.clone();
      }
    }

    interaction = Interactable(
      node: node,
      label: 'Water on/off',
      onTap: () {
        _on = !_on;
        _apply();
      },
    );
  }

  final Node node;
  late final Node streamNode;
  late final Node splashNode;
  late final ParticleEmitterComponent stream;
  late final ParticleEmitterComponent splash;
  late final Interactable interaction;
  Node? lever;
  Matrix4? leverRest;
  bool _on = false;

  void _apply() {
    final rest = leverRest;
    if (rest != null) lever?.localTransform = faucetLeverPose(rest, on: _on);
    stream.system.spawner.rate = _on ? 180 : 0;
    stream.paused = false;
    // The splash is a repeating burst; pausing freezes its system clock too,
    // so it simply resumes the same cadence rather than needing a rebuilt
    // system (ParticleEmitterComponent.system is final).
    splash.paused = !_on;
  }

  /// Pauses CPU stepping once a turned-off stream has no live particles
  /// left, so it stops costing anything until switched on again.
  void settle() {
    if (!_on && stream.system.storage.aliveCount == 0) stream.paused = true;
  }

  void dispose() {
    node.remove(streamNode);
    node.remove(splashNode);
    final rest = leverRest;
    if (rest != null) lever?.localTransform = rest;
  }
}

class _Shower {
  _Shower(this.node, Texture2D waterTexture, Texture2D steamTexture) {
    stream = ParticleEmitterComponent(
      system: buildShowerStreamSystem(rate: 0),
      material: SpriteMaterial(colorTexture: waterTexture)
        ..blendMode = SpriteBlendMode.alpha,
    )..facing = BillboardFacing.velocityStretched;
    streamNode = Node(name: 'shower_stream')
      ..shadowCastingMode = ShadowCastingMode.off
      ..raycastable = false
      ..addComponent(stream);

    steam = ParticleEmitterComponent(
      system: buildSteamSystem(rate: 0),
      material: SpriteMaterial(colorTexture: steamTexture)
        ..blendMode = SpriteBlendMode.alpha,
    );
    steamNode = Node(name: 'shower_steam')
      ..shadowCastingMode = ShadowCastingMode.off
      ..raycastable = false
      ..addComponent(steam);

    node.add(streamNode);
    node.add(steamNode);

    interaction = Interactable(
      node: node,
      label: 'Shower on/off',
      onTap: () {
        _on = !_on;
        _apply();
      },
    );
  }

  final Node node;
  late final Node streamNode;
  late final Node steamNode;
  late final ParticleEmitterComponent stream;
  late final ParticleEmitterComponent steam;
  late final Interactable interaction;
  bool _on = false;

  void _apply() {
    stream.system.spawner.rate = _on ? 600 : 0;
    stream.paused = false;
    // Steam only while the shower is on.
    steam.system.spawner.rate = _on ? 12 : 0;
    steam.paused = false;
  }

  void settle() {
    if (!_on && stream.system.storage.aliveCount == 0) stream.paused = true;
    if (!_on && steam.system.storage.aliveCount == 0) steam.paused = true;
  }

  void dispose() {
    node.remove(streamNode);
    node.remove(steamNode);
  }
}

// ----------------------------------------------------------------- texture

/// A small radial-gradient RGBA texture: opaque white at the center fading
/// to transparent at the edge. A `SpriteMaterial` with no texture draws a
/// hard square; particles need this so the sprite reads as a soft droplet or
/// puff. [softness] > 1 spreads the falloff further for a fluffier look
/// (used for steam).
Texture2D _softDotTexture({int size = 16, double softness = 1.0}) {
  final pixels = Uint8List(size * size * 4);
  final center = (size - 1) / 2.0;
  final maxDist = center * math.sqrt(2);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final dx = x - center;
      final dy = y - center;
      final dist = math.sqrt(dx * dx + dy * dy) / maxDist;
      var alpha = 1.0 - dist;
      alpha = math.pow(alpha.clamp(0.0, 1.0), softness).toDouble();
      final o = (y * size + x) * 4;
      pixels[o] = 255;
      pixels[o + 1] = 255;
      pixels[o + 2] = 255;
      pixels[o + 3] = (alpha * 255).round().clamp(0, 255);
    }
  }
  return Texture2D.fromPixels(pixels, size, size);
}
