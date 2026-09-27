import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/features/auto_exposure_feature.dart';
import 'package:flutter_3d/hotel/hotel_context.dart';
import 'package:flutter_3d/hotel/look.dart';

class _Context extends Fake implements HotelContext {
  @override
  final LookState look = LookState();
  int applied = 0;
  @override
  void applyLook() => applied++;
}

void main() {
  test('a walking step is not a teleport; a tour jump is', () {
    expect(isTeleport(Vector3(-4, 1.6, 3), Vector3(-4, 1.6, 3.03)), isFalse);
    expect(isTeleport(Vector3(-4, 1.6, 3), Vector3(-6.8, 1.6, 0.55)), isTrue);
  });

  test('mount switches the look flag on, unmount off', () async {
    final ctx = _Context();
    final f = AutoExposureFeature();
    await f.mount(ctx);
    expect(ctx.look.autoExposure, isTrue);
    expect(ctx.applied, 1);
    f.unmount(ctx);
    expect(ctx.look.autoExposure, isFalse);
    expect(ctx.applied, 2);
  });
}
