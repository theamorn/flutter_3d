import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/features/render_features.dart';
import 'package:flutter_3d/hotel/look.dart';

class _Sky implements SunSky {
  @override
  Vector3 sunDirection = Vector3(0.5, 0.7, 0.2);
  @override
  Vector3 get sunLightColor => Vector3.all(1);
  @override
  double get sunLightIntensity => 3;
}

void main() {
  test('enabling shadows configures the current sun for a room-sized scene', () {
    final look = LookState()..sunLight = SunLight(_Sky(), castsShadow: false);
    final shadows = SunShadows()..enable(look);
    final sun = look.sunLight!;
    expect(look.sunShadows, true);
    expect(sun.castsShadow, true);
    expect(sun.shadowMapResolution, 2048);
    expect(sun.shadowCascadeCount, 2);
    expect(sun.shadowMaxDistance, kShadowDistance);
    expect(sun.shadowAmbientStrength, kShadowAmbient,
        reason: 'the sky IBL would otherwise light shaded areas as if in sun');
    expect(shadows.enabled, true);
  });

  test('disabling turns them off and clears the ambient darkening', () {
    final look = LookState()..sunLight = SunLight(_Sky());
    SunShadows()
      ..enable(look)
      ..disable(look);
    expect(look.sunShadows, false);
    expect(look.sunLight!.castsShadow, false);
    expect(look.sunLight!.shadowAmbientStrength, 0);
  });

  test('a sun the sky creates later (sky remounted) is configured on the next sync', () {
    final look = LookState();
    final shadows = SunShadows()..enable(look); // sky off: only the intent is kept
    expect(look.sunShadows, true);
    // The sky feature builds its sun with castsShadow: look.sunShadows.
    look.sunLight = SunLight(_Sky(), castsShadow: look.sunShadows);
    expect(look.sunLight!.shadowMapResolution, isNot(2048));
    shadows.sync(look);
    expect(look.sunLight!.castsShadow, true);
    expect(look.sunLight!.shadowMapResolution, 2048);
    expect(look.sunLight!.shadowCascadeCount, 2);
  });

  test('sync leaves a sun alone while shadows are off', () {
    final look = LookState()..sunLight = SunLight(_Sky(), castsShadow: false);
    SunShadows().sync(look);
    expect(look.sunLight!.castsShadow, false);
    expect(look.sunLight!.shadowMapResolution, 1024);
  });
}
