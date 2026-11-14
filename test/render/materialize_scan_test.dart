import 'package:flutter_3d/features/player_feature.dart';
import 'package:flutter_3d/math/fp_movement.dart';
import 'package:flutter_3d/render/materialize_scan.dart';
import 'package:flutter_scene/kit.dart' show CameraShake;
import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  group('evaluateMaterializeSweep', () {
    test('inactive at progress <= 0 and >= 1', () {
      final start = evaluateMaterializeSweep(0.0, minY: -0.5, maxY: 2.0);
      final end = evaluateMaterializeSweep(1.0, minY: -0.5, maxY: 2.0);
      expect(start.active, isFalse);
      expect(end.active, isFalse);
      expect(start.wireFront, lessThan(-0.5));
      expect(start.fadeFront, lessThan(start.wireFront));
    });

    test('sweeps monotonically from below minY to above maxY', () {
      var prevWire = double.negativeInfinity;
      for (var p = 0.05; p <= 0.95; p += 0.1) {
        final s = evaluateMaterializeSweep(p, minY: -0.5, maxY: 2.0);
        expect(s.active, isTrue);
        expect(s.wireFront, greaterThan(prevWire));
        expect(s.fadeFront, lessThan(s.wireFront));
        prevWire = s.wireFront;
      }
      final nearEnd = evaluateMaterializeSweep(0.99, minY: -0.5, maxY: 2.0);
      expect(nearEnd.fadeFront, greaterThan(2.0));
    });
  });

  group('aimCamera with CameraShake', () {
    test('leaves camera pose untouched when shakeOffset is null', () {
      final cam = PerspectiveCamera();
      final state = FpState(Vector2(-4, 3), 0.0, 0.0);
      aimCamera(cam, state);
      expect(cam.position, Vector3(-4, 1.6, 3));
      expect(cam.target, Vector3(-4, 1.6, 4));
    });

    test('applies translation and rotation when trauma is active', () {
      final cam = PerspectiveCamera();
      final state = FpState(Vector2(-4, 3), 0.0, 0.0);
      final shake = CameraShake(
        decayRate: 1.5,
        frequency: 20.0,
        maxTranslation: Vector3(0.1, 0.1, 0.1),
        maxRotation: Vector3(0.05, 0.05, 0.05),
      )..addTrauma(0.8);
      final offset = shake.update(0.033).toMatrix4();
      aimCamera(cam, state, shakeOffset: offset);
      expect((cam.position - Vector3(-4, 1.6, 3)).length, greaterThan(0));
    });
  });
}
