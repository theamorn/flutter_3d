/// Frames a flutter_scene `Scene` actually rendered, kept apart from
/// Flutter's frames.
///
/// Since flutter_scene 0.24.0, a GPU-bound scene re-presents its previous
/// image (`Scene.maxGpuFramesInFlight`) instead of blocking the UI thread, so
/// `FrameTiming` counts can run far ahead of what the scene drew. Feed this
/// the scene's cumulative counters with a wall-clock timestamp, as often as you
/// like: the frames it rendered (`scene.renderStats.frameCount` less
/// `scene.pacedFrameCount`, because a paced frame still counts in `frameCount`)
/// and the frames it held (`scene.pacedFrameCount`).
library;

class SceneFrameMeter {
  SceneFrameMeter({this.windowMicros = 2000000});

  /// How far back the rates look.
  final int windowMicros;

  final List<(int, int, int)> _samples = <(int, int, int)>[];

  /// Records the scene's cumulative counters at [timestampMicros].
  void add(int timestampMicros, {required int sceneFrames, required int pacedFrames}) {
    _samples.add((timestampMicros, sceneFrames, pacedFrames));
    final cutoff = timestampMicros - windowMicros;
    // Keep one sample at or before the cutoff as the base, so the span
    // covers the whole window.
    while (_samples.length > 2 && _samples[1].$1 <= cutoff) {
      _samples.removeAt(0);
    }
    // After a pause longer than the window, the base is stale: drop it.
    if (_samples.length == 2 && _samples.first.$1 < cutoff - windowMicros) {
      _samples.removeAt(0);
    }
  }

  double get _seconds =>
      _samples.length < 2 ? 0 : (_samples.last.$1 - _samples.first.$1) / 1e6;

  /// Frames the scene rendered per second over the window.
  double get sceneFps =>
      _seconds <= 0 ? 0 : (_samples.last.$2 - _samples.first.$2) / _seconds;

  /// Frames the GPU pacing held (re-presented) per second over the window.
  double get pacedPerSecond =>
      _seconds <= 0 ? 0 : (_samples.last.$3 - _samples.first.$3) / _seconds;

  void clear() => _samples.clear();
}
