import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter_scene/scene.dart' show MeshData, PerspectiveCamera;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' hide Colors;
import 'package:flutter_3d/features/placeholder_rooms.dart';
import 'package:flutter_3d/math/picking.dart';
import 'package:flutter_3d/ui/screen_overlay.dart';

/// iPhone 17 Pro, logical pixels.
const _portrait = Size(402, 874), _landscape = Size(874, 402);
final _fov = 60 * degrees2Radians; // HotelContext's camera

/// The placeholder rooms' screens (placeholder_rooms.dart): node origin,
/// width and height of a quad facing +Z.
final _tv = (at: Vector3(-6.7, 1.3, 2.68), w: 1.2, h: 0.675);
final _pc = (at: Vector3(-3.8, 1.05, 0.25), w: 0.55, h: 0.34);

/// The screen's mesh data exactly as the rooms build it, and its node's world
/// transform. Room B is room A under a scale.x = −1 parent, built with u
/// flipped (d63cf81).
(MeshData, Matrix4) _screen(({Vector3 at, double w, double h}) s, {required bool roomB}) {
  final mesh = partsMeshData(
    [QuadPart(Vector3.zero(), Vector3(0, 0, 1), s.w, s.h, const Finish(0, 0, 0))],
    mirrored: roomB,
  );
  final node = Matrix4.translation(s.at);
  return (mesh, roomB ? Matrix4.diagonal3Values(-1, 1, 1) * node : node);
}

void main() {
  test('target projects to the centre; behind camera is null', () {
    final eye = Vector3(0, 1.6, 0), target = Vector3(0, 1.6, 5);
    const vp = Size(400, 800);
    final c = projectToScreen(target, eye: eye, target: target, fovY: 60 * degrees2Radians, viewport: vp);
    expect(c!.dx, closeTo(200, 1e-6));
    expect(c.dy, closeTo(400, 1e-6));
    expect(projectToScreen(Vector3(0, 1.6, -1), eye: eye, target: target, fovY: 1.0, viewport: vp), isNull);
  });

  test('off-axis points land on the engine\'s screen-right (+X facing +Z)', () {
    final eye = Vector3(0, 1.6, 0), target = Vector3(0, 1.6, 5);
    final p = projectToScreen(Vector3(1, 2, 5), eye: eye, target: target, fovY: _fov, viewport: _portrait)!;
    expect(p.dx, greaterThan(_portrait.width / 2), reason: 'world +X is screen-right facing +Z');
    expect(p.dy, lessThan(_portrait.height / 2), reason: 'world +Y is screen-up');

    // Facing room A's TV (looking −Z), its −X corner is on the right.
    final tvEye = Vector3(-6.7, 1.3, 5), tvTarget = Vector3(-6.7, 1.3, 2.68);
    final corner = projectToScreen(Vector3(-7.3, 1.6375, 2.68),
        eye: tvEye, target: tvTarget, fovY: _fov, viewport: _portrait)!;
    expect(corner.dx, greaterThan(_portrait.width / 2));
    expect(corner.dy, lessThan(_portrait.height / 2));
  });

  test('projectToScreen inverts screenRay, corners included', () {
    final eye = Vector3(-2, 1.4, 3), target = Vector3(0, 1.1, 6), up = Vector3(0, 1, 0);
    for (final pixel in const [Offset(0, 0), Offset(402, 874), Offset(30, 700), Offset(390, 100)]) {
      final ray = screenRay(screen: pixel, viewport: _portrait, eye: eye, target: target, up: up, fovY: 1.1);
      final back = projectToScreen(ray.origin + ray.direction * 4,
          eye: eye, target: target, up: up, fovY: 1.1, viewport: _portrait)!;
      expect(back.dx, closeTo(pixel.dx, 1e-3));
      expect(back.dy, closeTo(pixel.dy, 1e-3));
    }
  });

  test('projectToScreen agrees with the engine camera\'s worldToScreen', () {
    final camera = PerspectiveCamera(
        position: Vector3(-2, 1.4, 3), target: Vector3(0, 1.1, 6), fovRadiansY: _fov);
    for (final point in [Vector3(-1.2, 1.8, 7), Vector3(1.5, 0.2, 4), Vector3(-3, 2.5, 9)]) {
      final ours = projectToScreen(point,
          eye: camera.position, target: camera.target, up: camera.up, fovY: _fov, viewport: _landscape)!;
      final engine = camera.worldToScreen(point, _landscape)!;
      expect(ours.dx, closeTo(engine.dx, 1e-3));
      expect(ours.dy, closeTo(engine.dy, 1e-3));
    }
  });

  test('projectedBounds is null when any corner is behind the camera', () {
    final corners = [Vector3(-1, 1, 5), Vector3(1, 1, 5), Vector3(1, 0, -1), Vector3(-1, 0, 5)];
    expect(
        projectedBounds(corners,
            eye: Vector3.zero(), target: Vector3(0, 0, 1), fovY: _fov, viewport: _portrait),
        isNull);
  });

  group('ScreenQuad.fromMesh', () {
    test('room A TV: corners in the viewer\'s tl, tr, br, bl order, facing +Z', () {
      final (mesh, world) = _screen(_tv, roomB: false);
      final q = ScreenQuad.fromMesh(mesh, world);
      expect((q.centre - Vector3(-6.7, 1.3, 2.68)).length, lessThan(1e-5));
      expect((q.normal - Vector3(0, 0, 1)).length, lessThan(1e-6));
      expect(q.width, closeTo(1.2, 1e-5));
      expect(q.height, closeTo(0.675, 1e-5));
      // A viewer facing −Z has −X on their right, so top-left is at +X.
      expect((q.corners[0] - Vector3(-6.1, 1.6375, 2.68)).length, lessThan(1e-5));
      expect((q.corners[2] - Vector3(-7.3, 0.9625, 2.68)).length, lessThan(1e-5));
    });

    test('room B TV: mirrored across x = 0, still facing +Z', () {
      final (mesh, world) = _screen(_tv, roomB: true);
      final q = ScreenQuad.fromMesh(mesh, world);
      expect((q.centre - Vector3(6.7, 1.3, 2.68)).length, lessThan(1e-5));
      expect((q.normal - Vector3(0, 0, 1)).length, lessThan(1e-6));
      expect(q.width, closeTo(1.2, 1e-5));
      expect((q.corners[0] - Vector3(7.3, 1.6375, 2.68)).length, lessThan(1e-5));
    });

    test('the poster reads left to right in both rooms from the focus pose', () {
      for (final roomB in [false, true]) {
        final (mesh, world) = _screen(_tv, roomB: roomB);
        final q = ScreenQuad.fromMesh(mesh, world);
        final pose = q.focusPose(focusDistance(q, fovY: _fov, viewport: _portrait));
        final rect = projectedBounds(q.corners,
            eye: pose.eye, target: pose.target, fovY: _fov, viewport: _portrait)!;
        // The vertex carrying texture (0, 0), the poster's top-left.
        final uv = mesh.texCoords!;
        final i = [for (var v = 0; v < 4; v++) v]
            .firstWhere((v) => uv[2 * v] == 0 && uv[2 * v + 1] == 0);
        final p = mesh.positions;
        final topLeft = world.transform3(Vector3(p[3 * i], p[3 * i + 1], p[3 * i + 2]));
        final px = projectToScreen(topLeft,
            eye: pose.eye, target: pose.target, fovY: _fov, viewport: _portrait)!;
        expect(px.dx, closeTo(rect.left, 1e-2), reason: roomB ? 'room B' : 'room A');
        expect(px.dy, closeTo(rect.top, 1e-2), reason: roomB ? 'room B' : 'room A');
      }
    });
  });

  group('focus pose', () {
    test('0.9 m when the screen already fits (landscape)', () {
      for (final s in [_tv, _pc]) {
        final (mesh, world) = _screen(s, roomB: false);
        final q = ScreenQuad.fromMesh(mesh, world);
        expect(focusDistance(q, fovY: _fov, viewport: _landscape), 0.9);
      }
    });

    test('backs off in portrait until the whole screen is on screen, centred', () {
      for (final s in [_tv, _pc]) {
        for (final roomB in [false, true]) {
          final (mesh, world) = _screen(s, roomB: roomB);
          final q = ScreenQuad.fromMesh(mesh, world);
          final d = focusDistance(q, fovY: _fov, viewport: _portrait);
          expect(d, greaterThanOrEqualTo(0.9));
          final pose = q.focusPose(d);
          expect((pose.target - q.centre).length, lessThan(1e-6));
          expect(((pose.eye - q.centre).normalized() - q.normal).length, lessThan(1e-5));
          final rect = projectedBounds(q.corners,
              eye: pose.eye, target: pose.target, fovY: _fov, viewport: _portrait)!;
          expect(rect.left, greaterThan(0));
          expect(rect.right, lessThan(_portrait.width));
          expect(rect.top, greaterThan(0));
          expect(rect.bottom, lessThan(_portrait.height));
          expect(rect.center.dx, closeTo(_portrait.width / 2, 1e-2));
          expect(rect.center.dy, closeTo(_portrait.height / 2, 1e-2));
          // Head-on, the rect has the screen's own aspect.
          expect(rect.width / rect.height, closeTo(s.w / s.h, 1e-3));
        }
      }
      // The TV is the case the literal 0.9 m clips: 1.2 m wide in a 0.46 aspect.
      final (mesh, world) = _screen(_tv, roomB: false);
      expect(focusDistance(ScreenQuad.fromMesh(mesh, world), fovY: _fov, viewport: _portrait),
          greaterThan(2));
    });
  });

  group('FocusEase', () {
    final home = CameraPose(Vector3(-4, 1.6, 3), Vector3(-4, 1.6, 4));
    final focus = CameraPose(Vector3(-6.7, 1.3, 5.3), Vector3(-6.7, 1.3, 2.68));

    test('glides in over 0.6 s, holds, and glides back to the exact home pose', () {
      final ease = FocusEase();
      expect(ease.phase, FocusPhase.idle);
      expect(ease.step(0.1), isNull, reason: 'idle never writes the camera');

      expect(ease.enter(home, focus), isTrue);
      expect(ease.phase, FocusPhase.entering);
      final mid = ease.step(0.3)!;
      final halfway = (home.eye + focus.eye) * 0.5;
      expect((mid.eye - halfway).length, lessThan(1e-5));
      expect(ease.phase, FocusPhase.entering);
      final end = ease.step(0.3)!;
      expect(ease.phase, FocusPhase.focused);
      expect(end.eye, focus.eye);
      expect(end.target, focus.target);
      expect(ease.step(0.1), isNull, reason: 'focused: the camera stays put');

      expect(ease.leave(), isTrue);
      expect(ease.phase, FocusPhase.leaving);
      final back = ease.step(0.6)!;
      expect(ease.phase, FocusPhase.idle);
      expect(back.eye, home.eye);
      expect(back.target, home.target);
    });

    test('one tap at a time: enter only when idle, leave only when focused', () {
      final ease = FocusEase();
      expect(ease.leave(), isFalse);
      expect(ease.enter(home, focus), isTrue);
      expect(ease.enter(focus, home), isFalse);
      expect(ease.leave(), isFalse, reason: 'no close while still gliding in');
      ease.step(1);
      expect(ease.leave(), isTrue);
      expect(ease.leave(), isFalse);
      expect(ease.enter(home, focus), isFalse, reason: 'still gliding out');
      ease.step(5); // a long frame hitch finishes the glide in one step
      expect(ease.phase, FocusPhase.idle);
      expect(ease.enter(home, focus), isTrue);
    });

    test('reset hands back the home pose it interrupted, then idles', () {
      final ease = FocusEase();
      expect(ease.reset(), isNull);
      ease.enter(home, focus);
      ease.step(0.2);
      final restored = ease.reset()!;
      expect(restored.eye, home.eye);
      expect(ease.phase, FocusPhase.idle);
      expect(ease.step(0.1), isNull);
    });
  });

  testWidgets('overlay places the page on the rect and the close button works', (tester) async {
    var closed = 0;
    await tester.pumpWidget(MaterialApp(
      home: ScreenOverlay(
        bounds: const Rect.fromLTWH(40, 60, 200, 100),
        onClose: () => closed++,
        child: const ColoredBox(key: Key('page'), color: Colors.blue),
      ),
    ));
    expect(tester.getTopLeft(find.byKey(const Key('page'))), const Offset(40, 60));
    expect(tester.getSize(find.byKey(const Key('page'))), const Size(200, 100));
    await tester.tap(find.byTooltip('Close screen'));
    expect(closed, 1);
  });

  testWidgets('while a page is up, taps elsewhere never reach the scene', (tester) async {
    var sceneTaps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Stack(fit: StackFit.expand, children: [
        GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => sceneTaps++),
        ScreenOverlay(
          bounds: const Rect.fromLTWH(40, 60, 200, 100),
          onClose: () {},
          child: const ColoredBox(color: Colors.blue),
        ),
      ]),
    ));
    await tester.tapAt(const Offset(300, 400));
    expect(sceneTaps, 0);
  });
}
