import 'dart:ui' show PlatformDispatcher;
import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/features/occlusion_feature.dart';
import 'package:flutter_3d/hotel/hotel_context.dart';
import 'package:flutter_3d/math/floor_plan.dart';

// No scene: Scene needs the GPU (and is a base class, so it can't be faked).
// A culling pass reads ctx.scene, which throws here.
class _Context extends Fake implements HotelContext {
  @override
  final Map<RoomId, Node> rooms = {};
  @override
  final PerspectiveCamera camera = PerspectiveCamera(
    position: Vector3(-4, 1.6, 3),
    target: Vector3(-4, 1.6, 0),
  );
  @override
  int occlusionHolds = 0;
}

void main() {
  test('the view is known, so tick runs a culling pass', () {
    final view = PlatformDispatcher.instance.implicitView;
    expect(view, isNotNull);
    expect(view!.physicalSize.isEmpty, isFalse);
    expect(() => OcclusionFeature().tick(_Context(), 0), throwsA(isA<UnimplementedError>()));
  });

  test('under an occlusion hold, tick culls nothing', () {
    final ctx = _Context()..occlusionHolds = 1;
    OcclusionFeature().tick(ctx, 0);
  });

  test('room contents hang under the root, or under room B\'s mirror', () {
    final a = Node(name: 'room_a')
      ..add(Node(name: 'bed'))
      ..add(Node(name: 'desk'));
    expect(roomContentsRoot(a), same(a));

    final inner = Node(name: 'room')
      ..add(Node(name: 'bed'))
      ..add(Node(name: 'desk'));
    final b = Node(name: 'room_b')..add(Node(name: 'mirror_x')..add(inner));
    expect(roomContentsRoot(b), same(inner));
    expect(roomContents(b), inner.children);
  });
}
