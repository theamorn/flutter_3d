import 'dart:io';

import 'package:flutter_scene/scene.dart';
// The engine's own .fmat compiler (pure Dart, no GPU). Not exported; the
// engine's tests import it the same way.
// ignore: implementation_imports
import 'package:flutter_scene/src/fmat/fmat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/features/ocean_feature.dart';
import 'package:flutter_3d/features/placeholder_rooms.dart';
import 'package:flutter_3d/features/reflection_features.dart';
import 'package:flutter_3d/math/floor_plan.dart';

/// [spec] as bare nodes (names and transforms, no meshes), so the scene
/// graph maths runs without a GPU.
Node bare(RoomNode spec) {
  final node = Node(name: spec.name, localTransform: spec.localTransform);
  for (final c in spec.children) {
    node.add(bare(c));
  }
  return node;
}

Node named(Node root, String name) {
  final hits = <Node>[];
  void walk(Node n) {
    if (n.name == name) hits.add(n);
    n.children.forEach(walk);
  }

  walk(root);
  expect(hits, hasLength(1), reason: name);
  return hits.single;
}

/// Signed distance from [plane] (positive = in front of the mirror).
double side(Plane plane, Vector3 p) => plane.normal.dot(p) + plane.constant;

void expectVec(Vector3 actual, Vector3 expected, {String? reason}) {
  expect((actual - expected).length, lessThan(1e-5),
      reason: '${reason ?? ''} got $actual, want $expected');
}

void main() {
  group('layers', () {
    test('the sea sits alone on bit 2, which only its own capture leaves out', () {
      expect(kSeaLayer, 1 << 2);
      expect(kSeaCaptureMask, 0xFFFFFFFB);
      expect(kSeaLayer & kSeaCaptureMask, 0, reason: 'the sea skips its own capture');
      expect(kSeaLayer & kRenderLayerAll, isNot(0),
          reason: 'the main view and the mirror captures still draw the sea');
      expect(kRenderLayerDefault & kSeaCaptureMask, isNot(0),
          reason: 'everything on the default layer still reflects in the sea');
      // Adding bit 2 to the default layer would leave bit 0 in the mask:
      // the sea would still draw into its own capture.
      expect((kRenderLayerDefault | kSeaLayer) & kSeaCaptureMask, isNot(0));
    });
  });

  group('reflectors', () {
    test('mirror and sea use the planned settings', () {
      final mirror = mirrorReflector();
      expect(mirror.resolutionScale, 0.5);
      expectVec(mirror.localNormal, Vector3(1, 0, 0));
      expect(mirror.layerMask, kRenderLayerAll);

      final sea = seaReflector();
      expect(sea.resolutionScale, 0.5);
      expectVec(sea.localNormal, Vector3(0, 1, 0));
      expect(sea.layerMask, kSeaCaptureMask);
    });

    // The rooms as RoomsFeature builds them: room B is room A under a
    // scale.x = -1 parent.
    final roomA = bare(roomASpec())..name = 'room_a';
    final roomB = Node(name: 'room_b', localTransform: Matrix4.diagonal3Values(-1, 1, 1))
      ..add(bare(roomASpec()));

    test("room A's mirror faces +X, into its bathroom", () {
      final r = mirrorReflector();
      named(roomA, 'mirror').addComponent(r);
      final plane = r.worldPlane();
      expectVec(plane.normal, Vector3(1, 0, 0));
      expect(side(plane, Vector3(-7.99, 1.55, 0.55)), closeTo(0, 1e-5));
      // Standing in the bathroom, in front of the basin.
      expect(side(plane, Vector3(-6.8, FloorPlan.eyeHeight, 1.8)), greaterThan(0));
    });

    test("room B's mirror flips to -X under the negative-scale parent", () {
      final r = mirrorReflector();
      named(roomB, 'mirror').addComponent(r);
      final plane = r.worldPlane();
      expectVec(plane.normal, Vector3(-1, 0, 0));
      expect(side(plane, Vector3(7.99, 1.55, 0.55)), closeTo(0, 1e-5));
      final eye = FloorPlan.mirror(Vector2(-6.8, 1.8));
      expect(side(plane, Vector3(eye.x, FloorPlan.eyeHeight, eye.y)), greaterThan(0),
          reason: 'the engine skips the capture when the camera is behind the plane');
    });

    test('the sea reflects about y = -90, facing up', () {
      final r = seaReflector();
      Node(localTransform: Matrix4.translation(kSea.center)).addComponent(r);
      final plane = r.worldPlane();
      expectVec(plane.normal, Vector3(0, 1, 0));
      expect(side(plane, Vector3(0, kSeaLevel, 100)), closeTo(0, 1e-4));
      expect(side(plane, Vector3(-4, FloorPlan.eyeHeight, 7)), closeTo(91.6, 1e-4));
    });
  });

  group('findSea', () {
    test('finds the scene-level sea and ignores deeper nodes', () {
      final root = Node();
      expect(findSea(root), isNull);
      root.add(Node(name: 'beach')..add(Node(name: 'sea')));
      expect(findSea(root), isNull, reason: 'only direct children of the root');
      final sea = Node(name: 'sea');
      root.add(sea);
      expect(findSea(root), same(sea));
    });
  });

  group('PlanarBinding', () {
    // A mesh-less node: no material to swap, so this runs without a GPU.
    // (PhysicallyBasedMaterial constructs lazily and needs no device.)
    PlanarBinding bind(Node n, {int? layers}) =>
        PlanarBinding.attach(n, seaReflector(), material: PhysicallyBasedMaterial(), layers: layers);

    int reflectors(Node n) => n.getComponents<PlanarReflectorComponent>().length;

    test('detach removes the reflector and restores the layers', () {
      final n = Node(name: 'sea');
      final b = bind(n, layers: kSeaLayer);
      expect(reflectors(n), 1);
      expect(n.layers, kSeaLayer);
      b.detach();
      expect(reflectors(n), 0);
      expect(n.layers, kRenderLayerDefault);
    });

    test('without layers the node keeps its own', () {
      final n = Node(name: 'mirror')..layers = 1 << 5;
      final b = bind(n);
      expect(n.layers, 1 << 5);
      b.detach();
      expect(n.layers, 1 << 5);
    });

    test('on/off/on leaves exactly one reflector', () {
      final n = Node(name: 'sea');
      bind(n, layers: kSeaLayer).detach();
      final b = bind(n, layers: kSeaLayer);
      expect(reflectors(n), 1);
      b.detach();
      b.detach(); // a second detach is harmless
      expect(reflectors(n), 0);
      expect(n.layers, kRenderLayerDefault);
    });

    test('followSurface keeps the binding on the current node and cleans the old one', () {
      final first = Node(name: 'sea'), second = Node(name: 'sea');
      var b = followSurface(null, first, (n) => bind(n, layers: kSeaLayer));
      expect(b!.node, same(first));

      // Same node: nothing changes, no second reflector.
      final again = followSurface(b, first, (n) => fail('must not rebind'));
      expect(again, same(b));
      expect(reflectors(first), 1);

      // The ocean remounted: a new sea node replaced the old one.
      b = followSurface(b, second, (n) => bind(n, layers: kSeaLayer));
      expect(b!.node, same(second));
      expect(reflectors(first), 0, reason: 'nothing left on the detached sea');
      expect(first.layers, kRenderLayerDefault);
      expect(reflectors(second), 1);
      expect(second.layers, kSeaLayer);

      // The ocean turned off: no sea at all.
      b = followSurface(b, null, (n) => fail('no node to bind'));
      expect(b, isNull);
      expect(reflectors(second), 0);
      expect(second.layers, kRenderLayerDefault);
    });
  });

  group('mirror.fmat', () {
    test('is a lit material that declares the planar_reflection input', () {
      final compiled = compileFmat(File(kMirrorFmat).readAsStringSync(), fileName: kMirrorFmat);
      expect(compiled.material.engineInputs, ['planar_reflection']);
      expect(compiled.sidecar['engine_inputs'], ['planar_reflection']);
      expect(compiled.glsl, contains('vec4 GetPlanarReflection()'));
      for (final p in ['base_color', 'metallic_factor', 'roughness_factor', 'reflectivity', 'fresnel_mix']) {
        expect(compiled.sidecar.toString(), contains(p), reason: 'parameter $p');
      }
    });
  });
}
