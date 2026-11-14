import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

/// Path to the holographic wireframe laser-scan material adapted from
/// `bdero/flutter_scene`'s `materialize_wireframe.fmat`.
const String kMaterializeWireframeFmat =
    'assets/materials/materialize_wireframe.fmat';

/// Computed world-space sweep fronts for a vertical laser-scan reveal.
typedef MaterializeSweep = ({
  double wireFront,
  double fadeFront,
  double edgeWidth,
  double fadeWidth,
  bool active,
});

/// Evaluates the leading laser front (`wireFront`) and trailing vanish front
/// (`fadeFront`) for normalized [progress] in `0..1` across `[minY, maxY]`.
///
/// Pure and deterministic so tests can verify the sweep bounds without a GPU.
MaterializeSweep evaluateMaterializeSweep(
  double progress, {
  required double minY,
  required double maxY,
  double edgeWidth = 0.45,
  double fadeLag = 0.35,
  double fadeWidth = 0.85,
  double noisePad = 0.4,
}) {
  if (progress <= 0.0 || progress >= 1.0) {
    return (
      wireFront: minY - edgeWidth - noisePad,
      fadeFront: minY - edgeWidth - fadeWidth - noisePad,
      edgeWidth: edgeWidth,
      fadeWidth: fadeWidth,
      active: false,
    );
  }
  final t = progress.clamp(0.0, 1.0);
  // Smooth cubic ease-in-out.
  final eased = t * t * (3.0 - 2.0 * t);
  final span = (maxY - minY).abs() < 1e-3 ? 1.0 : (maxY - minY);
  final startY = minY - noisePad;
  final endY = maxY + span * fadeLag + fadeWidth + edgeWidth + noisePad;
  final wireFront = startY + (endY - startY) * eased;
  final fadeFront = wireFront - span * fadeLag;
  return (
    wireFront: wireFront,
    fadeFront: fadeFront,
    edgeWidth: edgeWidth,
    fadeWidth: fadeWidth,
    active: true,
  );
}

/// Manages a glowing holographic wireframe laser-scan reveal over a set of
/// scene nodes using `MeshData.extractEdges()` and `LineSegmentsGeometry`.
///
/// While idle (`!isActive`), all wireframe overlay nodes have `visible = false`
/// so they cost zero draw calls.
class MaterializeScanRig {
  MaterializeScanRig({
    required this.minY,
    required this.maxY,
    this.durationSeconds = 2.2,
    this.edgeWidth = 0.45,
    this.fadeLag = 0.35,
    this.fadeWidth = 0.85,
    this.lineWidth = 0.008,
  });

  final double minY;
  final double maxY;
  final double durationSeconds;
  final double edgeWidth;
  final double fadeLag;
  final double fadeWidth;
  final double lineWidth;

  PreprocessedMaterial? _material;
  final List<Node> _wireNodes = <Node>[];
  double _elapsed = 0.0;
  bool _running = false;
  bool _looping = false;

  bool get isActive => _running || _looping;
  int get wireNodeCount => _wireNodes.length;

  /// Extracts unique edges from [targets] and attaches hidden
  /// `LineSegmentsGeometry` child nodes ready for a laser-scan sweep.
  Future<void> attachToNodes(
    Iterable<Node> targets, {
    int? layerMask,
    Vector3? wireColor,
    Vector3? glowColor,
  }) async {
    detach();
    PreprocessedMaterial material;
    try {
      material = _material ??= await loadFmatMaterial(kMaterializeWireframeFmat);
    } on Object {
      // Headless unit tests without compiled shader assets skip GPU material load.
      return;
    }
    if (wireColor != null) {
      material.parameters.setVec4(
        'wire_color',
        Vector4(wireColor.x, wireColor.y, wireColor.z, 1.0),
      );
    }
    if (glowColor != null) {
      material.parameters.setVec4(
        'glow_color',
        Vector4(glowColor.x, glowColor.y, glowColor.z, 1.0),
      );
    }

    for (final target in targets) {
      final mesh = target.mesh;
      if (mesh == null) continue;
      final parts = <MeshData>[
        for (final p in mesh.primitives)
          if (p.geometry.isReadable) p.geometry.extractMeshData(),
      ];
      if (parts.isEmpty) continue;
      final merged = parts.length == 1 ? parts.first : MeshData.merge(parts);
      final edges = merged.extractEdges();
      final wireGeom = LineSegmentsGeometry(
        edges,
        width: lineWidth,
        normalOffset: 0.002,
      );
      final wireNode = Node(
        name: '${target.name}_materialize_wire',
        mesh: Mesh(wireGeom, material),
      )
        ..shadowCastingMode = ShadowCastingMode.off
        ..visible = false;
      if (layerMask != null) {
        wireNode.layers = layerMask;
      }
      target.add(wireNode);
      _wireNodes.add(wireNode);
    }
    _syncMaterial(0.0);
  }

  /// Starts a single bottom-to-top holographic laser-scan sweep.
  void triggerSweep() {
    if (_wireNodes.isEmpty) return;
    _elapsed = 0.0;
    _running = true;
    for (final node in _wireNodes) {
      node.visible = true;
    }
    _syncMaterial(0.01);
  }

  /// Enables or disables a continuous looping scan (used when the Island
  /// X-ray wireframe mode is active).
  void setLooping(bool loop) {
    if (_looping == loop) return;
    _looping = loop;
    if (loop) {
      _elapsed = 0.0;
      for (final node in _wireNodes) {
        node.visible = true;
      }
      _syncMaterial(0.01);
    } else if (!_running) {
      for (final node in _wireNodes) {
        node.visible = false;
      }
    }
  }

  /// Advances the active scan sweep by [dt] seconds.
  void tick(double dt) {
    if (!isActive || _wireNodes.isEmpty) return;
    _elapsed += dt;
    final progress = _elapsed / durationSeconds;
    if (_looping) {
      final cycle = progress % 1.0;
      _syncMaterial(cycle.clamp(0.01, 0.99));
      return;
    }
    if (progress >= 1.0) {
      _running = false;
      for (final node in _wireNodes) {
        node.visible = false;
      }
      _syncMaterial(0.0);
      return;
    }
    _syncMaterial(progress);
  }

  void _syncMaterial(double progress) {
    final mat = _material;
    if (mat == null) return;
    final s = evaluateMaterializeSweep(
      progress,
      minY: minY,
      maxY: maxY,
      edgeWidth: edgeWidth,
      fadeLag: fadeLag,
      fadeWidth: fadeWidth,
    );
    mat.parameters.setVec4(
      'sweep',
      Vector4(s.wireFront, s.fadeFront, s.edgeWidth, s.fadeWidth),
    );
  }

  /// Removes all attached wireframe overlay nodes.
  void detach() {
    _running = false;
    _looping = false;
    for (final node in _wireNodes) {
      node.detach();
    }
    _wireNodes.clear();
  }
}
