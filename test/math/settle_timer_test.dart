import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/math/schedulers.dart';

void main() {
  test('fires once, after the quiet period', () {
    final t = SettleTimer(quiet: 0.5)..markDirty();
    expect(t.pending, isTrue);
    expect(t.tick(0.3), isFalse);
    expect(t.tick(0.3), isTrue);
    expect(t.pending, isFalse);
    expect(t.tick(1.0), isFalse);
  });

  test('never fires while changes keep coming', () {
    final t = SettleTimer(quiet: 0.5);
    for (var i = 0; i < 20; i++) {
      t.markDirty();
      expect(t.tick(0.1), isFalse);
    }
    expect(t.tick(0.5), isTrue);
  });

  test('an idle timer never fires', () {
    expect(SettleTimer().tick(10), isFalse);
  });
}
