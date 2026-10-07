import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import '../render/wind.dart';

/// The world direction in which the window panes' u grows: +X in both rooms
/// (room B's builder flips its u back; see `QuadPart` in placeholder_rooms).
final Vector3 kWindowPaneUAxis = Vector3(1, 0, 0);

/// At or below this weather the panes keep their own glass material.
const double kRainGlassMinWeather = 0.001;

/// Period of the shader clock in seconds. Wrapping keeps `time` small, so
/// the drop maths keeps its float precision through a long storm; the drops
/// jump once per period.
const double kRainGlassClockWrap = 3600;

/// Whether the rain material belongs on the glass at [weather] (0 clear ..
/// 1 storm). Dry glass keeps its original material: at wetness 0 the shader
/// is only a copy of the scene behind the pane, and it would still cost a
/// scene-colour capture every frame the window is in view.
bool rainGlassWanted(double weather) => weather > kRainGlassMinWeather;

/// The shader clock [t] advanced by [dt] seconds, wrapped to
/// [0, kRainGlassClockWrap).
double advanceRainGlassClock(double t, double dt) =>
    (t + dt) % kRainGlassClockWrap;

/// Rain on the window: while it rains, both rooms' `window_glass` panes wear
/// `rain_glass.fmat`, which refracts the scene behind them through sliding
/// drops. `ctx.weather` (written by the rain feature) drives the wetness.
class RainGlassFeature extends HotelFeature {
  @override
  String get id => 'rain_glass';
  @override
  String get label => 'Rain on the window (refraction)';
  @override
  CostTier get tier => CostTier.expensive;
  @override
  bool get defaultOn => false;

  /// Loaded on the first mount and kept, so toggling doesn't load again.
  /// One instance serves both rooms: its parameters are the same for both.
  PreprocessedMaterial? _rain;

  /// Each pane wearing the rain material, with the mesh it had before. The
  /// original [Mesh] (its primitives and their materials) is never touched,
  /// so putting it back restores the glass exactly.
  final Map<Node, Mesh> _ownMesh = {};

  double _clock = 0;

  @override
  Future<void> mount(HotelContext ctx) async {
    _rain ??= await loadFmatMaterial('assets/materials/rain_glass.fmat');
  }

  @override
  void unmount(HotelContext ctx) => _restore();

  @override
  void tick(HotelContext ctx, double dt) {
    final rain = _rain;
    if (rain == null) return;
    final weather = ctx.weather.clamp(0.0, 1.0);
    if (!rainGlassWanted(weather)) {
      _restore();
      return;
    }
    // Looked up here, not in mount, so panes are found even if the rooms
    // mount after this feature.
    if (_ownMesh.isEmpty) _wear(ctx, rain);
    _clock = advanceRainGlassClock(_clock, dt);
    final wind = ctx.wind;
    rain.parameters
      ..setFloat('time', _clock)
      ..setFloat('wetness', weather)
      // With the beach wind on, the drops run sideways as they slide down.
      ..setFloat('wind_skew', wind == null ? 0 : rainGlassSkew(wind, uAxis: kWindowPaneUAxis));
  }

  void _wear(HotelContext ctx, Material rain) {
    for (final pane in ctx.nodesNamed('window_glass')) {
      final own = pane.mesh;
      if (own == null) continue;
      _ownMesh[pane] = own;
      // Same geometry, so the engine keeps the pane's render items and
      // only swaps their material.
      pane.mesh = Mesh.primitives(primitives: [
        for (final p in own.primitives)
          MeshPrimitive(p.geometry, rain)
            ..visible = p.visible
            ..castsShadow = p.castsShadow,
      ]);
    }
  }

  void _restore() {
    if (_ownMesh.isEmpty) return;
    _ownMesh.forEach((pane, own) => pane.mesh = own);
    _ownMesh.clear();
  }
}
