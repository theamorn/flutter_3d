import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/math/entrance_zone.dart';

void main() {
  test('enters near either mirrored room entrance', () {
    expect(EntranceZone().update(Vector2(-1.8, 0.8)), true);
    expect(EntranceZone().update(Vector2(1.8, 0.8)), true);
  });

  test('far away is outside', () {
    expect(EntranceZone().update(Vector2(-4, 5)), false);
  });

  test('hysteresis prevents boundary flicker and requires an exit', () {
    final zone = EntranceZone();
    zone.update(Vector2(-1.8, 1.0));
    expect(zone.update(Vector2(-1.8, 1.35)), true);
    expect(zone.update(Vector2(-1.8, 1.6)), false);
    expect(zone.update(Vector2(-1.8, 1.35)), false);
  });
}
