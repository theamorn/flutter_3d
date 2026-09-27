import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/features/dynamic_gi_feature.dart';
import 'package:flutter_3d/hotel/look.dart';
import 'package:flutter_3d/math/floor_plan.dart';

void main() {
  final lo = kGiCenter - kGiHalfExtents, hi = kGiCenter + kGiHalfExtents;

  test('the grid covers both rooms and balconies, floor to ceiling', () {
    const rail = FloorPlan.roomDepth + FloorPlan.balconyDepth;
    expect(lo.x, lessThanOrEqualTo(-FloorPlan.roomWidth));
    expect(hi.x, greaterThanOrEqualTo(FloorPlan.roomWidth));
    expect(lo.z, lessThanOrEqualTo(0));
    expect(hi.z, greaterThanOrEqualTo(rail));
    expect(lo.y, lessThanOrEqualTo(0));
    expect(hi.y, greaterThanOrEqualTo(FloorPlan.ceiling));
  });

  test('probes about every 1.5 m or closer, and a leak bias under the thinnest wall', () {
    final spacing = Vector3(
      2 * kGiHalfExtents.x / (kGiResolution.x - 1),
      2 * kGiHalfExtents.y / (kGiResolution.y - 1),
      2 * kGiHalfExtents.z / (kGiResolution.z - 1),
    );
    for (final s in [spacing.x, spacing.y, spacing.z]) {
      expect(s, lessThanOrEqualTo(1.6));
    }
    final smallest = [spacing.x, spacing.y, spacing.z].reduce((a, b) => a < b ? a : b);
    expect(kGiVisibilityBias * smallest, lessThan(0.06), reason: 'the 6 cm bathroom wall');
  });
}
