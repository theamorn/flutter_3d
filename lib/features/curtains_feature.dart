import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import '../math/schedulers.dart';
import 'interaction_registry.dart';

class CurtainsFeature extends HotelFeature {
  @override
  String get id => 'curtains';
  @override
  String get label => 'Curtains';
  @override
  CostTier get tier => CostTier.free;
  @override
  bool get toggleable => false;

  final List<_Curtains> _rooms = [];

  @override
  Future<void> mount(HotelContext ctx) async {
    for (final room in ctx.rooms.values) {
      final panels = <_Panel>[];
      void visit(Node n) {
        if (n.name == 'curtain_left' || n.name == 'curtain_right') {
          panels.add(_Panel(n, n.name == 'curtain_left' ? 1 : -1));
        }
        for (final c in n.children) {
          visit(c);
        }
      }

      visit(room);
      final curtains = _Curtains(panels);
      _rooms.add(curtains);
      _register(ctx, curtains);
    }
  }

  void _register(HotelContext ctx, _Curtains curtains) {
    for (final item in curtains.interactions) {
      ctx.interactions.unregister(item);
    }
    curtains.interactions.clear();
    for (final panel in curtains.panels) {
      final interaction = Interactable(
        node: panel.node,
        label: curtains.open ? 'Close curtains' : 'Open curtains',
        onTap: () {
          curtains.open = !curtains.open;
          _register(ctx, curtains);
        },
      );
      curtains.interactions.add(interaction);
      ctx.interactions.register(interaction);
    }
  }

  @override
  void tick(HotelContext ctx, double dt) {
    for (final curtains in _rooms) {
      // Normalize the travel so the complete 0.25..1 range takes 0.8 s.
      curtains.closed = approach(
        curtains.closed,
        curtains.open ? 0 : 1,
        dt,
        fadeSeconds: .8,
      );
      for (final panel in curtains.panels) {
        panel.apply(.25 + .75 * curtains.closed);
      }
    }
  }

  @override
  void unmount(HotelContext ctx) {
    for (final curtains in _rooms) {
      for (final item in curtains.interactions) {
        ctx.interactions.unregister(item);
      }
      for (final panel in curtains.panels) {
        panel.node.localTransform = panel.original;
      }
    }
    _rooms.clear();
  }
}

class _Curtains {
  _Curtains(this.panels) {
    if (panels.isNotEmpty) {
      closed = ((panels.first.node.scale.x - .25) / .75).clamp(0, 1);
    }
    open = closed < .5;
  }
  final List<_Panel> panels;
  final List<Interactable> interactions = [];
  double closed = 0;
  bool open = true;
}

class _Panel {
  _Panel(this.node, this.side)
    : original = node.localTransform.clone(),
      initialPosition = node.position,
      initialScale = node.scale,
      edge = node.position.x - side * .7 * node.scale.x;
  final Node node;
  final double side, edge;
  final Matrix4 original;
  final Vector3 initialPosition, initialScale;

  void apply(double scale) {
    node.scale = Vector3(scale, initialScale.y, initialScale.z);
    node.position = Vector3(
      edge + side * .7 * scale,
      initialPosition.y,
      initialPosition.z,
    );
  }
}
