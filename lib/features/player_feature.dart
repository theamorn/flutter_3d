import 'package:flutter/widgets.dart';
import 'package:flutter_scene/kit.dart' show VirtualJoystick;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import '../math/colliders.dart';
import '../math/floor_plan.dart';
import '../math/fp_movement.dart';
import '../ui/look_pad.dart';

/// Collision radius of the walker, metres.
const double kPlayerRadius = 0.25;

/// Walls and furniture never move, so build them once.
final List<Box2> _staticColliders = FloorPlan.staticColliders();

/// Everything the player collides with: the static plan plus the boxes
/// features add at runtime (the door leaf, Task 17).
List<Box2> playerColliders(Map<String, List<Box2>> dynamicColliders) =>
    dynamicColliders.isEmpty
        ? _staticColliders
        : [..._staticColliders, for (final b in dynamicColliders.values) ...b];

/// One frame: apply the look drag, then walk with sliding collision. Standing
/// still still pushes the player out of a box that appeared on top of them.
FpState stepPlayer(FpState s,
    {required Offset stick,
    required Offset look,
    required double dt,
    required Iterable<Box2> colliders}) {
  final looked = applyLook(s, look);
  final want = desiredStep(looked, stick, dt);
  return FpState(
      moveCircle(looked.xz, want, kPlayerRadius, colliders), looked.yaw, looked.pitch);
}

/// Puts the camera at eye height, looking along the player's facing.
void aimCamera(PerspectiveCamera camera, FpState s) {
  final eye = Vector3(s.xz.x, FloorPlan.eyeHeight, s.xz.y);
  camera.position = eye;
  camera.target = eye + forwardOf(s.yaw, s.pitch);
}

class PlayerFeature extends HotelFeature {
  @override
  String get id => 'player';
  @override
  String get label => 'First-person walk';
  @override
  CostTier get tier => CostTier.free;
  @override
  bool get toggleable => false;

  /// Joystick: x = strafe right, y = forward (+1 = pushed up).
  static final ValueNotifier<Offset> stick = ValueNotifier(Offset.zero);

  /// Look-pad drag accumulated since the last frame, logical pixels.
  static Offset pendingLook = Offset.zero;

  double _pitch = 0;

  FpState _state(HotelContext ctx) => FpState(ctx.playerXZ, ctx.playerYaw, _pitch);

  @override
  Future<void> mount(HotelContext ctx) async => aimCamera(ctx.camera, _state(ctx));

  @override
  void unmount(HotelContext ctx) {}

  @override
  void tick(HotelContext ctx, double dt) {
    final s = stepPlayer(_state(ctx),
        stick: stick.value,
        look: pendingLook,
        dt: dt,
        colliders: playerColliders(ctx.dynamicColliders));
    pendingLook = Offset.zero;
    ctx.playerXZ = s.xz;
    ctx.playerYaw = s.yaw;
    _pitch = s.pitch;
    aimCamera(ctx.camera, s);
  }

  /// Joystick bottom-left, look pad on the right half (above the time bar).
  static Widget overlay(HotelContext ctx) => LayoutBuilder(
        builder: (context, box) => Stack(children: [
          Positioned(
            left: 24,
            bottom: 90,
            // The joystick reports screen space (up = −y); forward is +y.
            child: VirtualJoystick(onChanged: (v) => stick.value = Offset(v.x, -v.y)),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 150,
            width: box.maxWidth / 2,
            child: LookPad(onDrag: (d) => pendingLook += d),
          ),
        ]),
      );
}
