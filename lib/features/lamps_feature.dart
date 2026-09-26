import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import 'interaction_registry.dart';

class LampsFeature extends HotelFeature {
  @override
  String get id => 'lamps';
  @override
  String get label => 'Dynamic lamp lights';
  @override
  CostTier get tier => CostTier.mid;

  final List<_Lamp> _lamps = [];

  @override
  Future<void> mount(HotelContext ctx) async {
    for (final node in [
      ...ctx.nodesNamed('lamp_bedside'),
      ...ctx.nodesNamed('lamp_floor'),
    ]) {
      final lamp = _Lamp(node);
      _lamps.add(lamp);
      ctx.interactions.register(lamp.interaction);
    }
  }

  @override
  void unmount(HotelContext ctx) {
    for (final lamp in _lamps) {
      ctx.interactions.unregister(lamp.interaction);
      lamp.dispose();
    }
    _lamps.clear();
  }
}

class _Lamp {
  _Lamp(this.node) {
    void visit(Node n) {
      if (n.name == 'lamp_shade') {
        for (final p in n.mesh?.primitives ?? <MeshPrimitive>[]) {
          final material = p.material;
          if (material is PhysicallyBasedMaterial) {
            _shades[material] = material.emissiveFactor.clone();
          }
        }
      }
      for (final child in n.children) {
        visit(child);
      }
    }

    visit(node);
    lightNode.addComponent(PointLightComponent(light));
    node.add(lightNode);
    interaction = Interactable(
      node: node,
      label: 'Lamp on/off',
      onTap: () {
        _on = !_on;
        _apply();
      },
    );
    _apply();
  }

  final Node node;
  final PointLight light = PointLight(
    color: Vector3(1, .78, .55),
    intensity: 8,
    range: 6,
  );
  final Node lightNode =
      Node(
          name: 'lamp_light',
          localTransform: Matrix4.translationValues(0, .3, 0),
        )
        ..castsShadows = false
        ..raycastable = false;
  final Map<PhysicallyBasedMaterial, Vector4> _shades = {};
  late final Interactable interaction;
  bool _on = true;

  void _apply() {
    light.intensity = _on ? 8 : 0;
    for (final entry in _shades.entries) {
      // HDR shade radiance gives bloom a small, localized highlight.
      entry.key.emissiveFactor = _on
          ? Vector4(8, 6.24, 4.4, 1)
          : entry.value.clone();
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
