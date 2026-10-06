import 'dart:ui' show VoidCallback;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import '../render/shadow_channels.dart';
import 'interaction_registry.dart';

/// Lamp light and shade glow. Halved from the first cut (8 and 8, 6.24,
/// 4.4): at the night exposure (2.5) they washed the room out.
const double kLampIntensity = 4;
const double kBulbRadius = 0.06;
final Vector4 _shadeGlow = Vector4(4, 3.12, 2.2, 1);

/// The bathroom's dim ceiling light. Its bulb is 2.65 m above the floor;
/// 4 m reaches the doorway floor (~3.1 m away) with falloff margin, so point
/// shadows can land there. The old 2.6 m cutoff excluded the entire floor.
const double kBathLightIntensity = 1.5, kBathLightRange = 4.0;
final Vector4 _diffuserGlow = Vector4(2, 1.7, 1.3, 1);

/// A lamp's light in the lamp's frame, and the bath light's in its fixture's
/// (just under the ceiling fitting).
final Vector3 kLampLightSourceAt = Vector3(0, .3, 0);
final Vector3 kBathLightSourceAt = Vector3(0, -.15, 0);

/// How far the switch rocker tips when the light is off (radians).
const double kRockerTip = 0.3;

/// A faint locator glow on the rocker, so the switch can be found in the dark.
final Vector4 _locatorGlow = Vector4(0.3, 0.24, 0.14, 1);

class LampsFeature extends HotelFeature {
  @override
  String get id => 'lamps';
  @override
  String get label => 'Dynamic lamp lights';
  @override
  CostTier get tier => CostTier.mid;

  final List<_Lamp> _lamps = [];
  final List<_BathLight> _bathLights = [];

  /// Mounted bathroom PointLights for bath_shadow; empty when unmounted.
  static final List<PointLight> bathLights = [];

  @override
  Future<void> mount(HotelContext ctx) async {
    for (final node in [
      ...ctx.nodesNamed('lamp_bedside'),
      ...ctx.nodesNamed('lamp_floor'),
    ]) {
      final lamp = _Lamp(node, onSwitch: () => ctx.lightingRevision.value++);
      _lamps.add(lamp);
      ctx.interactions.register(lamp.interaction);
    }
    // One light and one switch per room, both listed room A first.
    final lights = ctx.nodesNamed('bath_light');
    final switches = ctx.nodesNamed('bath_switch');
    for (var i = 0; i < lights.length && i < switches.length; i++) {
      final bath = _BathLight(
        lights[i],
        switches[i],
        onSwitch: () => ctx.lightingRevision.value++,
      );
      _bathLights.add(bath);
      bathLights.add(bath.light);
      ctx.interactions.register(bath.interaction);
    }
    _applyCasterMask(ctx);
    // Switching the whole feature is a lighting change too.
    ctx.lightingRevision.value++;
  }

  /// Keeps each light's shadow casters on the context's fixture mask (the
  /// bath shadow feature switches the bath lights' shadows on and off).
  @override
  void tick(HotelContext ctx, double dt) => _applyCasterMask(ctx);

  void _applyCasterMask(HotelContext ctx) {
    for (final lamp in _lamps) {
      lamp.light.shadowCasterChannelMask = ctx.fixtureCasterMask;
    }
    for (final bath in _bathLights) {
      bath.light.shadowCasterChannelMask = ctx.fixtureCasterMask;
    }
  }

  @override
  void unmount(HotelContext ctx) {
    for (final lamp in _lamps) {
      ctx.interactions.unregister(lamp.interaction);
      lamp.dispose();
    }
    _lamps.clear();
    for (final bath in _bathLights) {
      ctx.interactions.unregister(bath.interaction);
      bath.dispose();
    }
    _bathLights.clear();
    bathLights.clear();
    ctx.lightingRevision.value++;
  }
}

/// Emissive factors of every PBR material on nodes named [name] under
/// [root], so a glow can be switched on and restored.
Map<PhysicallyBasedMaterial, Vector4> _glowMaterials(Node root, String name) {
  final out = <PhysicallyBasedMaterial, Vector4>{};
  void visit(Node n) {
    if (n.name == name) {
      for (final p in n.mesh?.primitives ?? <MeshPrimitive>[]) {
        final material = p.material;
        if (material is PhysicallyBasedMaterial) {
          out[material] = material.emissiveFactor.clone();
        }
      }
    }
    for (final child in n.children) {
      visit(child);
    }
  }

  visit(root);
  return out;
}

/// The switch rocker's transform: [rest] when the light is on, tipped
/// about its local Z when off.
Matrix4 rockerPose(Matrix4 rest, {required bool on}) =>
    on ? rest.clone() : rest.multiplied(Matrix4.rotationZ(kRockerTip));

/// The bathroom ceiling light, switched from the wall by the bathroom door.
class _BathLight {
  _BathLight(this.fixture, this.switchNode, {required this.onSwitch}) {
    _diffusers.addAll(_glowMaterials(fixture, 'bath_light_diffuser'));
    _locators.addAll(_glowMaterials(switchNode, 'bath_switch_rocker'));
    for (final m in _locators.keys) {
      m.emissiveFactor = _locatorGlow.clone();
    }
    for (final child in switchNode.children) {
      if (child.name == 'bath_switch_rocker') {
        rocker = child;
        rockerRest = child.localTransform.clone();
      }
    }
    lightNode.addComponent(PointLightComponent(light));
    fixture.add(lightNode);
    interaction = Interactable(
      node: switchNode,
      label: 'Bathroom light on/off',
      onTap: () {
        _on = !_on;
        _apply();
        onSwitch();
      },
    );
    _apply();
  }

  final Node fixture, switchNode;
  final VoidCallback onSwitch;
  Node? rocker;
  Matrix4? rockerRest;
  final PointLight light = PointLight(
    radius: kBulbRadius,
    color: Vector3(1, .85, .68),
    intensity: kBathLightIntensity,
    range: kBathLightRange,
  );
  // Just under the ceiling fitting.
  final Node lightNode =
      Node(
          name: 'bath_light_source',
          localTransform: Matrix4.translation(kBathLightSourceAt),
        )
        ..shadowCastingMode = ShadowCastingMode.off
        ..raycastable = false;
  final Map<PhysicallyBasedMaterial, Vector4> _diffusers = {};
  final Map<PhysicallyBasedMaterial, Vector4> _locators = {};
  late final Interactable interaction;
  bool _on = true;

  void _apply() {
    light.intensity = _on ? kBathLightIntensity : 0;
    for (final entry in _diffusers.entries) {
      entry.key.emissiveFactor = _on
          ? _diffuserGlow.clone()
          : entry.value.clone();
    }
    final rest = rockerRest;
    if (rest != null) rocker?.localTransform = rockerPose(rest, on: _on);
  }

  void dispose() {
    fixture.remove(lightNode);
    for (final entry in _diffusers.entries) {
      entry.key.emissiveFactor = entry.value;
    }
    _diffusers.clear();
    for (final entry in _locators.entries) {
      entry.key.emissiveFactor = entry.value;
    }
    _locators.clear();
    final rest = rockerRest;
    if (rest != null) rocker?.localTransform = rest;
  }
}

class _Lamp {
  _Lamp(this.node, {required this.onSwitch}) {
    _shades.addAll(_glowMaterials(node, 'lamp_shade'));
    lightNode.addComponent(PointLightComponent(light));
    node.add(lightNode);
    interaction = Interactable(
      node: node,
      label: 'Lamp on/off',
      onTap: () {
        _on = !_on;
        _apply();
        onSwitch();
      },
    );
    _apply();
  }

  final Node node;
  final VoidCallback onSwitch;
  final PointLight light = PointLight(
    radius: kBulbRadius,
    color: Vector3(1, .78, .55),
    intensity: kLampIntensity,
    range: 6,
  );
  final Node lightNode =
      Node(
          name: 'lamp_light',
          localTransform: Matrix4.translation(kLampLightSourceAt),
        )
        ..shadowCastingMode = ShadowCastingMode.off
        ..raycastable = false;
  final Map<PhysicallyBasedMaterial, Vector4> _shades = {};
  late final Interactable interaction;
  bool _on = true;

  void _apply() {
    light.intensity = _on ? kLampIntensity : 0;
    for (final entry in _shades.entries) {
      // HDR shade radiance gives bloom a small, localized highlight.
      entry.key.emissiveFactor = _on ? _shadeGlow.clone() : entry.value.clone();
    }
  }

  void dispose() {
    node.remove(lightNode);
    for (final entry in _shades.entries) {
      entry.key.emissiveFactor = entry.value;
    }
    _shades.clear();
  }
}

/// The comparison for the fixture light channels: while on, every fixture
/// light's shadow map takes every caster again, the shades around the bulbs
/// included. Off (the default) leaves those shades out.
class FixtureShadowsFeature extends HotelFeature {
  @override
  String get id => 'fixture_shadows';
  @override
  String get label => 'Lamp shades shadow their own light (comparison)';
  @override
  CostTier get tier => CostTier.free;
  @override
  bool get defaultOn => false;

  @override
  Future<void> mount(HotelContext ctx) async {
    ctx.fixtureCasterMask = kIncludeFixtureCasterMask;
    ctx.lightingRevision.value++;
  }

  @override
  void unmount(HotelContext ctx) {
    ctx.fixtureCasterMask = kFixtureExcludedCasterMask;
    ctx.lightingRevision.value++;
  }
}
