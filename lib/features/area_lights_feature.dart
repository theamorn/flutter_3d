import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import '../math/floor_plan.dart';
import 'occlusion_feature.dart' show roomContentsRoot;
import 'placeholder_rooms.dart' show windowX0, windowX1;
import 'sky_feature.dart' show skyAt;

/// The TV's glow: a cool panel the size of the screen (1.2 × 0.675 m).
const double kTvGlowIntensity = 1.5, kTvGlowRange = 4;
final Vector3 kTvGlowColor = Vector3(0.75, 0.85, 1.0);

/// The window's "skylight": a panel filling the opening, as bright as the
/// sky (full by day, about 1 % at night), dimmed by storm cloud.
const double kWindowLightDay = 3.0, kWindowLightRange = 6, kWindowTop = 2.4;
final Vector3 kWindowLightColor = Vector3(0.8, 0.88, 1.0);

/// The window light's intensity for a sky [brightness] (`skyAt().skyBrightness`,
/// 0.012 at night up to 1 by day) and [weather] (0 clear .. 1 storm).
double windowLightIntensity(double brightness, double weather) =>
    kWindowLightDay * brightness.clamp(0.0, 1.0) *
    (1 - 0.6 * weather.clamp(0.0, 1.0));

/// Room A's window light: in the opening, just inside the glass, turned to
/// face into the room (a rect light emits along its local +Z).
Matrix4 windowLightTransform() => Matrix4.compose(
      Vector3((windowX0 + windowX1) / 2, kWindowTop / 2, FloorPlan.roomDepth - 0.02),
      Quaternion.axisAngle(Vector3(0, 1, 0), math.pi),
      Vector3.all(1),
    );

/// Area lights: a soft glow off each TV screen, and a sky-bright panel in
/// each window, a cheap stand-in for daylight bouncing in. They cast no
/// shadows. Both hang under the rooms' contents, so room B is mirrored.
class AreaLightsFeature extends HotelFeature {
  @override
  String get id => 'area_lights';
  @override
  String get label => 'Area lights (TV glow, window light)';
  @override
  CostTier get tier => CostTier.cheap;

  final List<Node> _nodes = [];
  final List<RectAreaLight> _windows = [];

  @override
  Future<void> mount(HotelContext ctx) async {
    for (final screen in ctx.nodesNamed('tv_screen')) {
      final glow = Node(name: 'tv_glow', localTransform: Matrix4.translationValues(0, 0, 0.01))
        ..castsShadows = false
        ..raycastable = false
        ..addComponent(RectAreaLightComponent(RectAreaLight(
          color: kTvGlowColor.clone(),
          intensity: kTvGlowIntensity,
          width: 1.2,
          height: 0.675,
          range: kTvGlowRange,
        )));
      screen.add(glow);
      _nodes.add(glow);
    }
    for (final room in ctx.rooms.values) {
      final light = RectAreaLight(
        color: kWindowLightColor.clone(),
        width: windowX1 - windowX0,
        height: kWindowTop,
        range: kWindowLightRange,
      );
      final node = Node(name: 'window_light', localTransform: windowLightTransform())
        ..castsShadows = false
        ..raycastable = false
        ..addComponent(RectAreaLightComponent(light));
      roomContentsRoot(room).add(node);
      _nodes.add(node);
      _windows.add(light);
    }
    tick(ctx, 0);
    if (_nodes.isNotEmpty) ctx.lightingRevision.value++;
  }

  @override
  void tick(HotelContext ctx, double dt) {
    final sky = skyAt(ctx.timeOfDay.value);
    final intensity = windowLightIntensity(sky.skyBrightness, ctx.weather);
    final color = Vector3(
      sky.lightColor.x * kWindowLightColor.x,
      sky.lightColor.y * kWindowLightColor.y,
      sky.lightColor.z * kWindowLightColor.z,
    );
    for (final light in _windows) {
      light.intensity = intensity;
      light.color = color.clone();
    }
  }

  @override
  void unmount(HotelContext ctx) {
    final hadLights = _nodes.isNotEmpty;
    for (final n in _nodes) {
      n.parent?.remove(n);
    }
    _nodes.clear();
    _windows.clear();
    if (hadLights) ctx.lightingRevision.value++;
  }
}
