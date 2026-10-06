import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_scene/scene.dart';

import 'scene_frame_meter.dart';

typedef SceneCounts = ({int meshes, int triangles});

/// Triangle count per geometry. The engine's index count is internal, so this
/// reads it once through [Geometry.extractMeshData] and caches it.
final Expando<int> _triangles = Expando('triangles');

int _trianglesOf(Geometry g) {
  final cached = _triangles[g];
  if (cached != null) return cached;
  var n = 0;
  if (g.isReadable) {
    try {
      n = g.extractMeshData().triangleCount;
    } on StateError {
      n = 0; // non-triangle geometry (lines)
    }
  }
  return _triangles[g] = n;
}

/// Visible mesh nodes under [root] and their triangle count. Hidden subtrees
/// and hidden primitives (occlusion culling) are skipped.
SceneCounts countScene(Node root) {
  var meshes = 0, triangles = 0;
  void walk(Node n) {
    if (!n.visible) return;
    final shown = n.mesh?.primitives.where((p) => p.visible) ?? const <MeshPrimitive>[];
    if (shown.isNotEmpty) meshes++;
    for (final p in shown) {
      triangles += _trianglesOf(p.geometry);
    }
    for (final c in n.children) {
      walk(c);
    }
  }

  walk(root);
  return (meshes: meshes, triangles: triangles);
}

/// Frames [scene] actually rendered. `renderStats.frameCount` also counts
/// every frame the GPU pacing held (`pacedFrameCount`): a paced frame still
/// opens and closes a stats frame, with no views and no draws. Feed this to
/// `SceneFrameMeter`, not `frameCount` alone.
int renderedFrameCount(Scene scene) =>
    scene.renderStats.frameCount - scene.pacedFrameCount;

/// The newest recent frame with an on-screen view, skipping paced frames
/// (which have no views) and offscreen-only capture frames. `latest` alone is
/// an empty frame about as often as the GPU is paced.
RenderFrameStats? lastOnScreenFrame(Scene scene) {
  final history = scene.renderStats.history;
  for (var i = history.length - 1; i >= 0 && i >= history.length - 16; i--) {
    if (history[i].views.any((v) => !v.offscreen)) return history[i];
  }
  return null;
}

/// The on-screen view's draws in the last rendered frame, and how many
/// offscreen views (planar captures, probes) rendered with it.
({int draws, int instances, int offscreenViews})? onScreenDraws(RenderFrameStats? frame) {
  if (frame == null) return null;
  var draws = -1, instances = 0, offscreen = 0;
  for (final v in frame.views) {
    if (v.offscreen) {
      offscreen++;
    } else if (draws < 0) {
      draws = v.counters.draws;
      instances = v.counters.instances;
    }
  }
  if (draws < 0) return null;
  return (draws: draws, instances: instances, offscreenViews: offscreen);
}

/// Scene fps (from `renderStats.frameCount`) and Flutter fps, UI/raster ms
/// (avg and p90 over the last 2 s of FrameTimings), the on-screen draw count
/// from `renderStats`, and the visible triangle count of [scene].
class Hud extends StatefulWidget {
  const Hud({super.key, required this.scene});
  final Scene scene;
  @override
  State<Hud> createState() => _HudState();
}

class _HudState extends State<Hud> {
  final List<FrameTiming> _window = [];
  final SceneFrameMeter _meter = SceneFrameMeter();
  String _text = '…';

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  void _onTimings(List<FrameTiming> t) {
    _window.addAll(t);
    final cutoff =
        _window.last.timestampInMicroseconds(FramePhase.rasterFinish) - 2000000;
    _window.removeWhere(
        (f) => f.timestampInMicroseconds(FramePhase.rasterFinish) < cutoff);
    double ms(Duration d) => d.inMicroseconds / 1000;
    List<double> sorted(Iterable<double> xs) => xs.toList()..sort();
    final ui = sorted(_window.map((f) => ms(f.buildDuration)));
    final raster = sorted(_window.map((f) => ms(f.rasterDuration)));
    double avg(List<double> xs) => xs.reduce((a, b) => a + b) / xs.length;
    double p90(List<double> xs) =>
        xs[(xs.length * 0.9).floor().clamp(0, xs.length - 1)];
    final c = countScene(widget.scene.root);
    _meter.add(DateTime.now().microsecondsSinceEpoch,
        sceneFrames: renderedFrameCount(widget.scene),
        pacedFrames: widget.scene.pacedFrameCount);
    final d = onScreenDraws(lastOnScreenFrame(widget.scene));
    setState(() => _text = '${_meter.sceneFps.round()} fps scene · '
        '${(_window.length / 2).round()} flutter\n'
        'UI  ${avg(ui).toStringAsFixed(1)} / p90 ${p90(ui).toStringAsFixed(1)} ms\n'
        'GPU ${avg(raster).toStringAsFixed(1)} / p90 ${p90(raster).toStringAsFixed(1)} ms\n'
        '${d == null ? '–' : '${d.draws}'} draws · ${(c.triangles / 1000).toStringAsFixed(1)}k tris'
        '${d == null || d.offscreenViews == 0 ? '' : ' · ${d.offscreenViews} captures'}');
  }

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
            color: Colors.black54, borderRadius: BorderRadius.circular(6)),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(_text,
              style: const TextStyle(
                  color: Colors.white, fontSize: 11, fontFamily: 'monospace')),
        ),
      );
}
