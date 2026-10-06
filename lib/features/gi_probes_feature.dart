import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';

/// A value snapshot of the renderer's lattice. Its getter allocates a new
/// grid wrapper each frame, and its vectors can refer to engine-owned data.
class GiProbeLayout {
  Vector3? _origin, _spacing, _counts;

  bool update(bool enabled, IrradianceProbeGrid? grid) {
    if (!enabled || grid == null) {
      final changed = _origin != null;
      _origin = _spacing = _counts = null;
      return changed;
    }
    if (_origin == grid.origin &&
        _spacing == grid.spacing &&
        _counts == grid.counts)
      return false;
    _origin = grid.origin.clone();
    _spacing = grid.spacing.clone();
    _counts = grid.counts.clone();
    return true;
  }

  Iterable<Vector3> get positions sync* {
    final origin = _origin, spacing = _spacing, counts = _counts;
    if (origin == null || spacing == null || counts == null) return;
    for (var x = 0; x < counts.x.round(); x++) {
      for (var y = 0; y < counts.y.round(); y++) {
        for (var z = 0; z < counts.z.round(); z++) {
          yield Vector3(
            origin.x + spacing.x * x,
            origin.y + spacing.y * y,
            origin.z + spacing.z * z,
          );
        }
      }
    }
  }
}

/// Draws the actual live GI lattice, rather than the requested volume bounds.
class GiProbesFeature extends HotelFeature {
  @override
  String get id => 'gi_probes';
  @override
  String get label => 'Show GI probes';
  @override
  CostTier get tier => CostTier.free;
  @override
  bool get defaultOn => false;

  final GiProbeLayout _layout = GiProbeLayout();
  Node? _node;

  @override
  Future<void> mount(HotelContext ctx) async => tick(ctx, 0);

  @override
  void tick(HotelContext ctx, double dt) {
    if (!_layout.update(
      ctx.scene.globalIllumination.enabled,
      ctx.scene.globalIlluminationProbeGrid,
    ))
      return;
    _remove(ctx);
    final positions = _layout.positions.toList();
    if (positions.isEmpty) return;
    final mesh = InstancedMesh(
      geometry: CuboidGeometry(Vector3.all(0.05)),
      material: UnlitMaterial()..baseColorFactor = Vector4(1, 0.2, 0.05, 1),
    );
    for (final position in positions) {
      mesh.addInstance(Matrix4.translation(position));
    }
    final node = _node = Node(name: 'gi_probes')
      ..shadowCastingMode = ShadowCastingMode.off
      ..addComponent(InstancedMeshComponent(mesh));
    ctx.scene.add(node);
  }

  void _remove(HotelContext ctx) {
    final node = _node;
    if (node != null) ctx.scene.remove(node);
    _node = null;
  }

  @override
  void unmount(HotelContext ctx) {
    _remove(ctx);
    _layout.update(false, null);
  }
}
