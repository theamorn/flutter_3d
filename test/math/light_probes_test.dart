import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/math/floor_plan.dart';
import 'package:flutter_3d/math/light_probes.dart';
import 'package:flutter_3d/math/occlusion.dart';

bool inside(ProbeBox box, Vector3 point) =>
    (point.x - box.center.x).abs() <= box.halfExtents.x &&
    (point.y - box.center.y).abs() <= box.halfExtents.y &&
    (point.z - box.center.z).abs() <= box.halfExtents.z;

void main() {
  final boxes = roomProbeBoxes();
  final bedroom = boxes.firstWhere((box) => box.priority == 10);
  final bathroom = boxes.firstWhere((box) => box.priority == 20);

  test(
    'bedroom probe covers room corners and bathroom probe wins its cell',
    () {
      for (final point in [
        Vector3(-7.9, 0.1, 5.9),
        Vector3(-0.1, 2.7, 0.1),
        Vector3(-4, 1.6, 3),
      ]) {
        expect(inside(bedroom, point), isTrue, reason: '$point');
      }
      for (final point in [
        Vector3(-6.8, 1.6, 0.55),
        Vector3(-7.9, 0.1, 0.1),
        Vector3(-5.3, 2.7, 2.5),
      ]) {
        expect(inside(bathroom, point), isTrue, reason: '$point');
        expect(cellOf(point), Cell.bathA, reason: '$point');
      }
      expect(inside(bathroom, Vector3(-4, 1.6, 1.5)), isFalse);
      expect(bathroom.priority, greaterThan(bedroom.priority));
    },
  );

  test('each surface takes its own cell\'s probe; outdoors keeps the sky', () {
    ProbeBox boxAt(Vector3 p) => boxes[probeBoxFor(cellOf(p))!];
    expect(boxAt(Vector3(-6.8, 1.6, 0.55)).priority, 20, reason: 'bathroom');
    expect(boxAt(Vector3(6.8, 1.6, 0.55)).priority, 20, reason: "room B's bathroom, mirrored");
    expect(boxAt(Vector3(-4, 1.6, 3)).priority, 10, reason: 'bedroom');
    expect(boxAt(Vector3(4, 1.6, 3)).priority, 10, reason: "room B's bedroom");
    expect(probeBoxFor(cellOf(Vector3(-3, 1, 7.3))), isNull, reason: 'the balcony stays sky-lit');
  });

  test('balcony remains outside every room probe', () {
    final balcony = Vector3(-3, FloorPlan.eyeHeight, 7.3);
    expect(boxes.any((box) => inside(box, balcony)), isFalse);
  });

  group('LightingSignature', () {
    final sky = Object();
    final base = LightingSignature(
      timeOfDay: 15,
      weather: 0,
      sky: sky,
      revision: 0,
    );

    test('time, switch revision, and sky identity each trigger a capture', () {
      expect(
        LightingSignature(
          timeOfDay: 16,
          weather: 0,
          sky: sky,
          revision: 0,
        ).differsFrom(base),
        isTrue,
      );
      expect(
        LightingSignature(
          timeOfDay: 15,
          weather: 0,
          sky: sky,
          revision: 1,
        ).differsFrom(base),
        isTrue,
      );
      expect(
        LightingSignature(
          timeOfDay: 15,
          weather: 0,
          sky: Object(),
          revision: 0,
        ).differsFrom(base),
        isTrue,
      );
      expect(
        LightingSignature(
          timeOfDay: 15,
          weather: 0,
          sky: sky,
          revision: 0,
        ).differsFrom(base),
        isFalse,
      );
    });

    test(
      'gradual weather change triggers when cumulative change reaches 0.05',
      () {
        var last = base;
        var changes = 0;
        for (var hundredths = 1; hundredths <= 20; hundredths++) {
          final now = LightingSignature(
            timeOfDay: 15,
            weather: hundredths / 100,
            sky: sky,
            revision: 0,
          );
          if (now.differsFrom(last)) {
            changes++;
            last = now;
          }
        }
        expect(changes, greaterThanOrEqualTo(3));
      },
    );
  });

  group('CaptureQueue', () {
    test(
      'captures one probe per frame and releases hold on following frame',
      () {
        final queue = CaptureQueue(4)..start();
        final steps = [for (var i = 0; i < 5; i++) queue.step()];
        expect([for (final step in steps) step.capture], [0, 1, 2, 3, null]);
        expect(
          [for (final step in steps) step.hold],
          [true, true, true, true, false],
        );
        expect(queue.busy, isFalse);
      },
    );

    test('cancel mid-pass releases hold without capturing another probe', () {
      final queue = CaptureQueue(4)..start();
      queue.step();
      queue.cancel();
      expect(queue.step(), (capture: null, hold: false));
    });

    test('restart mid-pass captures the first probe again', () {
      final queue = CaptureQueue(4)..start();
      queue.step();
      queue.step();
      queue.start();
      expect(queue.step().capture, 0);
    });
  });
}
