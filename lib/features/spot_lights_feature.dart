import 'dart:ui' show VoidCallback;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import '../math/floor_plan.dart' show RoomId;
import 'interaction_registry.dart';
import 'placeholder_rooms.dart' show kReadingLightArm;

/// Warm reading light: a tight cone onto the pillows.
const double kReadingLightIntensity = 6, kReadingLightRange = 3;

/// Cone half-angles in radians: about 17° full brightness, fading out by 34°.
const double kReadingLightInner = 0.3, kReadingLightOuter = 0.6;

/// Down and out from the wall toward the pillows, in the fixture's frame
/// (room A's +X; room B's mirror flips it for free).
Vector3 readingLightAim() => Vector3(0.7, -1, 0)..normalize();

/// The light's position in the fixture's frame: just under the shade.
final Vector3 kReadingLightSourceAt = Vector3(kReadingLightArm, -0.14, 0);

final Vector4 _shadeGlow = Vector4(3, 2.4, 1.7, 1);

class _ReadingLight {
  _ReadingLight(this.fixture, {required this.inRoomA, required this.onSwitch}) {
    for (final c in fixture.children) {
      if (c.name != 'reading_light_shade') continue;
      for (final p in c.mesh?.primitives ?? const <MeshPrimitive>[]) {
        final m = p.material;
        if (m is PhysicallyBasedMaterial) _shades[m] = m.emissiveFactor.clone();
      }
    }
    lightNode.addComponent(SpotLightComponent(light));
    fixture.add(lightNode);
    interaction = Interactable(
      node: fixture,
      label: 'Reading light on/off',
      onTap: () {
        _on = !_on;
        _apply();
        onSwitch();
      },
    );
    _apply();
  }

  final Node fixture;
  final VoidCallback onSwitch;

  /// Whether the fixture hangs in room A (at x < 0) rather than room B.
  final bool inRoomA;
  final SpotLight light = SpotLight(
    color: Vector3(1, .82, .6),
    intensity: kReadingLightIntensity,
    range: kReadingLightRange,
    direction: readingLightAim(),
    innerConeAngle: kReadingLightInner,
    outerConeAngle: kReadingLightOuter,
    castsShadow: true,
  );

  final Node lightNode = Node(
    name: 'reading_light_source',
    localTransform: Matrix4.translation(kReadingLightSourceAt),
  )
    ..shadowCastingMode = ShadowCastingMode.off
    ..raycastable = false;
  final Map<PhysicallyBasedMaterial, Vector4> _shades = {};
  late final Interactable interaction;
  bool _on = true;

  void _apply() {
    light.intensity = _on ? kReadingLightIntensity : 0;
    for (final e in _shades.entries) {
      e.key.emissiveFactor = _on ? _shadeGlow.clone() : e.value.clone();
    }
  }

  void dispose() {
    fixture.remove(lightNode);
    for (final e in _shades.entries) {
      e.key.emissiveFactor = e.value;
    }
    _shades.clear();
  }
}

bool _isUnder(Node node, Node? root) {
  for (Node? n = node; n != null; n = n.parent) {
    if (identical(n, root)) return true;
  }
  return false;
}

/// Reading spot lights: a cone from each brass reading light over the beds,
/// shadowed in the camera's room, tappable on and off. Default-on because it
/// owns the taps.
class SpotLightsFeature extends HotelFeature {
  @override
  String get id => 'spot_lights';
  @override
  String get label => 'Reading spot lights (shadowed)';
  @override
  CostTier get tier => CostTier.mid;

  final List<_ReadingLight> _lights = [];

  @override
  Future<void> mount(HotelContext ctx) async {
    for (final fixture in [
      ...ctx.nodesNamed('reading_light_left'),
      ...ctx.nodesNamed('reading_light_right'),
    ]) {
      final l = _ReadingLight(
        fixture,
        inRoomA: _isUnder(fixture, ctx.rooms[RoomId.a]),
        onSwitch: () => ctx.lightingRevision.value++,
      );
      _lights.add(l);
      ctx.interactions.register(l.interaction);
    }
    _shadowCameraRoom(ctx);
    if (_lights.isNotEmpty) ctx.lightingRevision.value++;
  }

  @override
  void tick(HotelContext ctx, double dt) => _shadowCameraRoom(ctx);

  /// Only the camera's room's reading lights cast shadows. Spot shadows take
  /// sun-sized tiles (2048) in the sun's shadow atlas: two cascades and four
  /// spots make it 12288 wide, past the 8192 texture limit, and the frame
  /// fails to draw. The other room's lights are behind a wall, or seen
  /// through the connecting door, where their shadows barely show.
  void _shadowCameraRoom(HotelContext ctx) {
    final cameraInA = ctx.camera.position.x < 0;
    for (final l in _lights) {
      l.light.castsShadow = l.inRoomA == cameraInA;
    }
  }

  @override
  void unmount(HotelContext ctx) {
    final hadLights = _lights.isNotEmpty;
    for (final l in _lights) {
      ctx.interactions.unregister(l.interaction);
      l.dispose();
    }
    _lights.clear();
    if (hadLights) ctx.lightingRevision.value++;
  }
}
