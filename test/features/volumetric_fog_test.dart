import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/features/volumetric_fog_feature.dart';
import 'package:flutter_3d/hotel/hotel_context.dart';
import 'package:flutter_3d/hotel/look.dart';

class _Context extends Fake implements HotelContext {
  @override
  final LookState look = LookState();
  @override
  double weather = 0;
  int applied = 0;
  @override
  void applyLook() => applied++;
}

void main() {
  test('rain thickens the mist: 1x clear, 2.5x in a full storm', () {
    expect(fogThickness(0), 1);
    expect(fogThickness(1), 2.5);
    expect(fogThickness(3), 2.5, reason: 'clamped');
  });

  test('mount, weather change, unmount', () async {
    final ctx = _Context();
    final f = VolumetricFogFeature();
    await f.mount(ctx);
    expect(ctx.look.volumetricFog, isTrue);
    final applied = ctx.applied;
    f.tick(ctx, 0.016);
    expect(ctx.applied, applied, reason: 'no re-apply while nothing changes');
    ctx.weather = 1;
    f.tick(ctx, 0.016);
    expect(ctx.look.volumetricFogThickness, 2.5);
    expect(ctx.applied, applied + 1);
    f.unmount(ctx);
    expect(ctx.look.volumetricFog, isFalse);
    expect(ctx.look.volumetricFogThickness, 1);
  });
}
