import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/math/schedulers.dart';

void main() {
  test('continuous dragging rebakes at most every 0.4 s', () {
    final r = RebakeThrottle();
    var bakes = 0;
    for (var i = 0; i < 120; i++) { // 2 s of dragging at 60 fps
      r.markDirty();
      if (r.tick(1 / 60)) bakes++;
    }
    expect(bakes, inInclusiveRange(4, 6));
  });

  test('one final bake after changes stop', () {
    final r = RebakeThrottle();
    r.markDirty();
    var bakes = 0;
    for (var i = 0; i < 120; i++) { if (r.tick(1 / 60)) bakes++; }
    expect(bakes, 1);
  });

  test('no changes → no bakes', () {
    final r = RebakeThrottle();
    for (var i = 0; i < 120; i++) { expect(r.tick(1 / 60), false); }
  });
}
