import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/math/colliders.dart';

void main() {
  const wall = Box2(0, 0, 1, 10); // wall occupying x∈[0,1]
  const r = 0.25;

  test('free movement is unchanged', () {
    final p = moveCircle(Vector2(-3, 5), Vector2(-2, 5), r, [wall]);
    expect(p.x, closeTo(-2, 1e-9));
    expect(p.y, closeTo(5, 1e-9));
  });

  test('walking into a wall stops at radius distance', () {
    final p = moveCircle(Vector2(-1, 5), Vector2(0.5, 5), r, [wall]);
    expect(p.x, closeTo(-r, 1e-6));
  });

  test('diagonal into wall slides along it', () {
    final p = moveCircle(Vector2(-1, 5), Vector2(0.5, 6), r, [wall]);
    expect(p.x, closeTo(-r, 1e-6));
    expect(p.y, closeTo(6, 1e-6));
  });

  test('fast step cannot tunnel through a thin wall', () {
    const thin = Box2(0, 0, 0.12, 10);
    final p = moveCircle(Vector2(-1, 5), Vector2(3, 5), r, [thin]);
    expect(p.x, lessThan(0));
  });

  test('player overlapping a newly-enabled box is pushed out, not stuck', () {
    const door = Box2(-0.05, 2.0, 0.05, 2.9);
    final start = Vector2(0.0, 2.45); // standing in the doorway as it closes
    final p = moveCircle(start, start, r, [door]);
    final inside = p.x > door.minX - r + 1e-6 && p.x < door.maxX + r - 1e-6 &&
        p.y > door.minZ - r + 1e-6 && p.y < door.maxZ + r - 1e-6;
    expect(inside, false);
  });

  test('mirrored box flips x', () {
    final m = const Box2(-8, 0, -5.2, 2.6).mirrored();
    expect([m.minX, m.maxX], [5.2, 8]);
  });
}
