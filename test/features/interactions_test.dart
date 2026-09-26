import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/features/interaction_registry.dart';
import 'package:flutter_3d/features/interactions_feature.dart';

SceneRaycastHit hitOn(Node n, double d) => SceneRaycastHit(
      node: n,
      distance: d,
      worldPoint: Vector3.zero(),
      worldNormal: Vector3(0, 0, -1),
      uv: null,
      barycentrics: Vector3(1, 0, 0),
      triangleIndex: 0,
      primitiveIndex: 0,
    );

void main() {
  test('registered nodes and all their descendants become raycastable', () {
    final shade = Node(name: 'lamp_shade')..raycastable = false;
    final lamp = Node(name: 'lamp')
      ..raycastable = false
      ..add(Node(name: 'stem')
        ..raycastable = false
        ..add(shade));
    markRaycastable(lamp);
    expect(lamp.raycastable, true);
    expect(lamp.children.single.raycastable, true);
    expect(shade.raycastable, true);
  });

  group('pick', () {
    final registry = InteractionRegistry();
    final shade = Node(name: 'lamp_shade');
    final lamp = Node(name: 'lamp_bedside')..add(shade);
    final wall = Node(name: 'walls');
    var taps = 0;
    registry.register(Interactable(node: lamp, label: 'Lamp on/off', onTap: () => taps++));
    final ray = Ray.originDirection(Vector3(0, 1.6, 0), Vector3(0, 0, 1));

    test('a hit on a child mesh resolves to the registered parent, within reach', () {
      double? reach;
      final i = pick(registry, ray, (r, {required maxDistance}) {
        reach = maxDistance;
        return hitOn(shade, 2);
      });
      expect(i?.label, 'Lamp on/off');
      expect(reach, kReach);
      expect(kReach, 6);
    });

    test('a nearer non-interactive mesh (a wall) blocks the tap', () {
      expect(pick(registry, ray, (r, {required maxDistance}) => hitOn(wall, 1)), isNull);
    });

    test('nothing within reach → nothing', () {
      expect(pick(registry, ray, (r, {required maxDistance}) => null), isNull);
      expect(taps, 0, reason: 'picking never taps by itself');
    });
  });
}
