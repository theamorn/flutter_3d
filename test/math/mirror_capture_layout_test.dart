import 'package:flutter_3d/math/mirror_capture_layout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

/// [p] mirrored across [plane] (normal · x + constant = 0).
Vector3 reflect(Plane plane, Vector3 p) =>
    p - plane.normal * (2 * (plane.normal.dot(p) + plane.constant));

double side(Plane plane, Vector3 p) => plane.normal.dot(p) + plane.constant;

void main() {
  group('computeMirrorTargetSize', () {
    test('keeps the viewport aspect with the long side at 512', () {
      expect(computeMirrorTargetSize(390, 844), (237, 512));
      expect(computeMirrorTargetSize(844, 390), (512, 237));
      expect(computeMirrorTargetSize(1000, 1000), (512, 512));
      expect(computeMirrorTargetSize(100, 50), (512, 256));
    });

    test('never makes a side under 64 or a zero target', () {
      expect(computeMirrorTargetSize(4000, 10), (512, 64));
      for (final (w, h) in [(0.0, 0.0), (-5.0, 100.0), (double.nan, 10.0), (10.0, double.infinity)]) {
        final (tw, th) = computeMirrorTargetSize(w, h);
        expect(tw, inInclusiveRange(64, 512), reason: '$w x $h');
        expect(th, inInclusiveRange(64, 512), reason: '$w x $h');
      }
      expect(computeMirrorTargetSize(0, 0), (512, 512));
    });

    test('is stable, so a resize to the same viewport keeps the target', () {
      expect(computeMirrorTargetSize(390, 844), computeMirrorTargetSize(390, 844));
    });
  });

  group('computeMirrorPlane', () {
    test('room A: the mirror facing +X at x = -7.9', () {
      final plane = computeMirrorPlane(
          Matrix4.translationValues(-7.9, 1.5, 1.0), Vector3(1, 0, 0))!;
      expect(plane.normal.x, closeTo(1, 1e-9));
      expect(side(plane, Vector3(-7.0, 1.5, 1.0)), greaterThan(0), reason: 'the room is in front');
      final r = reflect(plane, Vector3(-7.0, 1.6, 1.2));
      expect(r.x, closeTo(-8.8, 1e-6));
      expect(r.y, closeTo(1.6, 1e-6));
    });

    test('room B: the x-mirrored copy faces -X, and the room is still in front', () {
      final roomB = Matrix4.diagonal3Values(-1, 1, 1)
        ..multiply(Matrix4.translationValues(-7.9, 1.5, 1.0));
      final plane = computeMirrorPlane(roomB, Vector3(1, 0, 0))!;
      expect(plane.normal.x, closeTo(-1, 1e-9));
      expect(side(plane, Vector3(7.0, 1.5, 1.0)), greaterThan(0));
      final r = reflect(plane, Vector3(7.0, 1.6, 1.2));
      expect(r.x, closeTo(8.8, 1e-6));
    });

    test('takes the normal through the inverse transpose under non-uniform scale', () {
      final plane = computeMirrorPlane(
          Matrix4.diagonal3Values(2, 1, 1), Vector3(1, 1, 0)..normalize())!;
      final want = Vector3(0.5, 1, 0)..normalize();
      // vector_math's Matrix4 is float32.
      expect(plane.normal.dot(want), closeTo(1, 1e-6));
    });

    test('refuses a singular transform instead of guessing a plane', () {
      expect(computeMirrorPlane(Matrix4.diagonal3Values(0, 1, 1), Vector3(1, 0, 0)), isNull);
      expect(computeMirrorPlane(Matrix4.identity(), Vector3.zero()), isNull);
    });
  });

  group('ReflectionCaptureRegistry', () {
    test('register and unregister are idempotent', () {
      final r = ReflectionCaptureRegistry<String>();
      r.register('feature', 'mirror A', 'capture A');
      r.register('feature', 'mirror A', 'capture A');
      expect(r.active, ['capture A']);
      r.unregister('feature', 'mirror A');
      r.unregister('feature', 'mirror A');
      expect(r.active, isEmpty);
    });

    test('a late unregister from an old owner keeps the newer owner\'s capture', () {
      final r = ReflectionCaptureRegistry<String>()
        ..register('custom (old mount)', 'mirror A', 'old')
        ..register('custom (new mount)', 'mirror A', 'new');
      r.unregister('custom (old mount)', 'mirror A');
      expect(r.active, ['new']);
      r.unregisterAll('custom (old mount)');
      expect(r.active, ['new']);
      r.unregisterAll('custom (new mount)');
      expect(r.active, isEmpty);
    });
  });
}
