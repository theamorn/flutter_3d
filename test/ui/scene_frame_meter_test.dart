import 'package:flutter_3d/ui/scene_frame_meter.dart';
import 'package:flutter_test/flutter_test.dart';

/// Feeds [seconds] of samples at [hz] Flutter frames per second, the scene
/// rendering [sceneHz] of them; returns the time after the last sample.
int feed(SceneFrameMeter m, {required int startMicros, required double seconds,
    required double hz, required double sceneHz, required List<int> counters}) {
  final n = (seconds * hz).round();
  var t = startMicros;
  for (var i = 1; i <= n; i++) {
    t = startMicros + (i * 1e6 / hz).round();
    final scene = (counters[0] + i * sceneHz / hz).floor();
    final paced = (counters[1] + i * (hz - sceneHz) / hz).floor();
    m.add(t, sceneFrames: scene, pacedFrames: paced);
  }
  counters[0] += (seconds * sceneHz).round();
  counters[1] += (seconds * (hz - sceneHz)).round();
  return t;
}

void main() {
  test('no samples reads zero', () {
    final m = SceneFrameMeter();
    expect(m.sceneFps, 0);
    expect(m.pacedPerSecond, 0);
  });

  test('every Flutter frame rendered: scene fps is the frame rate', () {
    final m = SceneFrameMeter();
    feed(m, startMicros: 0, seconds: 3, hz: 60, sceneHz: 60, counters: [0, 0]);
    expect(m.sceneFps, closeTo(60, 1));
    expect(m.pacedPerSecond, closeTo(0, 1));
  });

  test('paced frames are not scene frames', () {
    final m = SceneFrameMeter();
    feed(m, startMicros: 0, seconds: 3, hz: 120, sceneHz: 40, counters: [0, 0]);
    expect(m.sceneFps, closeTo(40, 1.5));
    expect(m.pacedPerSecond, closeTo(80, 1.5));
  });

  test('the window slides: only the last 2 s count', () {
    final m = SceneFrameMeter();
    final c = [0, 0];
    final t = feed(m, startMicros: 0, seconds: 5, hz: 60, sceneHz: 60, counters: c);
    feed(m, startMicros: t, seconds: 3, hz: 60, sceneHz: 30, counters: c);
    expect(m.sceneFps, closeTo(30, 1.5));
  });

  test('gap ages out: a 10 s pause stops counting after the window', () {
    final m = SceneFrameMeter();
    final c = [0, 0];
    final t = feed(m, startMicros: 0, seconds: 3, hz: 60, sceneHz: 60, counters: c);
    feed(m, startMicros: t + 10000000, seconds: 2.5, hz: 60, sceneHz: 60, counters: c);
    expect(m.sceneFps, closeTo(60, 2));
  });

  test('clear forgets everything', () {
    final m = SceneFrameMeter();
    feed(m, startMicros: 0, seconds: 1, hz: 60, sceneHz: 60, counters: [0, 0]);
    m.clear();
    expect(m.sceneFps, 0);
  });
}
