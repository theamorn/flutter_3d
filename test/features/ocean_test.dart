import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/features/ocean_feature.dart';
import 'package:flutter_3d/features/placeholder_rooms.dart';
import 'package:flutter_3d/math/floor_plan.dart';

/// HotelContext.camera.fovFar.
const double cameraFar = 900;

void main() {
  test('the hotel facade stays under the room floor slab (no z-fighting)', () {
    final floor = roomASpec().children.firstWhere((n) => n.name == 'floor');
    final slabBottom = floor.parts.map((p) => p.bounds.min.y).reduce((a, b) => a < b ? a : b);
    expect(kFacade.max.y, lessThan(slabBottom));
    expect(kFacade.max.z, lessThanOrEqualTo(FloorPlan.roomDepth),
        reason: 'the balcony overhangs the facade');
    expect(kFacade.min.y, lessThan(kSandTop), reason: 'the facade stands in the sand');
  });

  test('the whole sea is inside the far plane from anywhere you can stand', () {
    const rail = FloorPlan.roomDepth + FloorPlan.balconyDepth;
    final standing = [
      for (final x in [-FloorPlan.roomWidth, FloorPlan.roomWidth])
        for (final z in [0.0, rail])
          Vector3(x, FloorPlan.eyeHeight, z),
    ];
    for (final eye in standing) {
      for (final x in [kSea.min.x, kSea.max.x]) {
        for (final z in [kSea.min.z, kSea.max.z]) {
          expect((Vector3(x, kSeaLevel, z) - eye).length, lessThan(cameraFar),
              reason: 'sea corner ($x, $z) from $eye');
        }
      }
    }
  });

  test('the beach is dry above sea level and slopes under it at the shoreline', () {
    expect(kSandTop, greaterThan(kSeaLevel));
    expect(kShoreEndY, lessThan(kSeaLevel));
    // Where the slope crosses the water line, the sea must already be there.
    final crossing = kSea.min.z +
        (kSandTop - kSeaLevel) / (kSandTop - kShoreEndY) * (kShoreEndZ - kSea.min.z);
    expect(crossing, greaterThan(kSea.min.z));
    expect(crossing, lessThan(kShoreEndZ));
  });

  group('sea horizon', () {
    final standing = [
      for (final x in [-FloorPlan.roomWidth, -4.0, 0.0, FloorPlan.roomWidth])
        for (final z in [0.0, 3.0, FloorPlan.roomDepth + FloorPlan.balconyDepth])
          Vector3(x, FloorPlan.eyeHeight, z),
    ];
    double? hit(Ray r) {
      double? best;
      for (final b in kSeaHorizon) {
        final t = r.intersectsWithAabb3(b);
        if (t != null && (best == null || t < best)) best = t;
      }
      return best;
    }

    Vector3 heading(double azimuth, double elevation) => Vector3(
        math.cos(elevation) * math.sin(azimuth), math.sin(elevation),
        math.cos(elevation) * math.cos(azimuth));

    test('the sea reaches the horizon over the view (a sun just below it is hidden)', () {
      for (final eye in standing) {
        for (var az = -70.0; az <= 70.0; az += 5) {
          final r = Ray.originDirection(eye, heading(az * degrees2Radians, -0.3 * degrees2Radians));
          final t = hit(r);
          expect(t, isNotNull, reason: 'nothing below the horizon at azimuth $az from $eye');
          expect(t!, lessThan(cameraFar), reason: 'azimuth $az from $eye');
        }
      }
    });

    test('its top is the horizon: a sun just above it stays in view', () {
      for (final eye in standing) {
        for (var az = -70.0; az <= 70.0; az += 5) {
          final r = Ray.originDirection(eye, heading(az * degrees2Radians, 0.3 * degrees2Radians));
          expect(hit(r), isNull, reason: 'azimuth $az from $eye');
        }
      }
    });
  });
}
