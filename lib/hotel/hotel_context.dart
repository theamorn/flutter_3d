import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';
import '../features/interaction_registry.dart';
import '../math/colliders.dart';
import '../math/floor_plan.dart';
import 'look.dart';

/// Shared state handed to every feature.
class HotelContext {
  HotelContext(this.scene) {
    // The msaa feature owns anti-aliasing. The engine default (auto) already
    // means MSAA where supported, so "MSAA off" would be a lie until the
    // feature first mounts and unmounts.
    scene.antiAliasingMode = AntiAliasingMode.none;
  }
  final Scene scene;

  /// Punctual shadow casters rejected by the renderer atlas budget.
  int get shadowCasterOverflowCount => scene.shadowCasterOverflowCount;
  final PerspectiveCamera camera = PerspectiveCamera(
    position: Vector3(-4, 1.6, 3),
    target: Vector3(-4, 1.6, 6),
    fovRadiansY: 60 * degrees2Radians,
    fovNear: 0.05,
    fovFar: 900,
  );
  final LookState look = LookState();
  final InteractionRegistry interactions = InteractionRegistry();

  /// Hours 0..24.
  final ValueNotifier<double> timeOfDay = ValueNotifier(15.0);
  final ValueNotifier<bool> rainRequested = ValueNotifier(false);

  /// Smoothed 0 clear..1 storm (Task 20 writes).
  double weather = 0.0;

  /// Filled by the rooms feature (Task 9).
  final Map<RoomId, Node> rooms = {};

  /// Task 17 writes.
  final ValueNotifier<bool> doorOpen = ValueNotifier(false);

  /// Task 10 writes.
  Vector2 playerXZ = Vector2(-4, 3);

  /// Radians, 0 looks toward +Z.
  double playerYaw = 0.0;

  /// Extra collision boxes features can add (door leaf). Key = owner id.
  final Map<String, List<Box2>> dynamicColliders = {};

  /// Bumped when a light the probes should see is switched (lamps, the
  /// bathroom light, reading lights). The light-probes feature re-captures
  /// once things settle.
  final ValueNotifier<int> lightingRevision = ValueNotifier(0);

  /// While above zero, occlusion culling hides nothing: a probe capture must
  /// see the whole scene, not just what the camera sees. Take and release it
  /// in pairs.
  int occlusionHolds = 0;

  void applyLook() => scene.environmentSettings = composeLook(look);

  /// Every node named [name] in both rooms (A first). Empty if rooms not mounted.
  List<Node> nodesNamed(String name) {
    final out = <Node>[];
    void walk(Node n) {
      if (n.name == name) out.add(n);
      for (final c in n.children) {
        walk(c);
      }
    }

    for (final id in RoomId.values) {
      final root = rooms[id];
      if (root != null) walk(root);
    }
    return out;
  }
}
