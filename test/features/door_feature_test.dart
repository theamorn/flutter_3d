import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/features/door_feature.dart';

void main() {
  test('door remains a visible root child when either room is culled', () {
    final root = Node(name: 'root');
    final roomA = Node(
      name: 'room_a',
      localTransform: Matrix4.translationValues(-1, 0, 0)..rotateY(0.3),
    );
    final roomB = Node(name: 'room_b');
    final door = Node(
      name: 'door_connect',
      localTransform: Matrix4.translationValues(1, 0, 2),
    );
    root
      ..add(roomA)
      ..add(roomB);
    roomA.add(door);
    final before = door.globalTransform.clone();

    moveDoorToSceneRoot(door, root);
    roomA.visible = false;
    expect(door.parent, same(root));
    expect(door.visible, true);
    roomA.visible = true;
    roomB.visible = false;
    expect(door.visible, true);
    final after = door.globalTransform;
    for (var i = 0; i < 16; i++) {
      expect(after.storage[i], closeTo(before.storage[i], 1e-6));
    }
  });
}
