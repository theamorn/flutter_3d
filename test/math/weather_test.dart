import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/math/schedulers.dart';

void main() {
  test('reaches target after fadeSeconds, never overshoots', () {
    var w = 0.0;
    for (var i = 0; i < 150; i++) { w = approach(w, 1, 1 / 60); }
    expect(w, 1.0);
    expect(approach(0.99, 1, 1), 1.0);
    expect(approach(0.5, 0, 0.5, fadeSeconds: 2.5), closeTo(0.3, 1e-9));
  });
}
