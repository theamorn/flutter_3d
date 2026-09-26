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
}
