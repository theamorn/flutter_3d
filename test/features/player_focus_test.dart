import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter_scene/kit.dart' show VirtualJoystick;
import 'package:flutter_scene/scene.dart' show PerspectiveCamera;
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart';
import 'package:flutter_3d/features/player_feature.dart';
import 'package:flutter_3d/hotel/hotel_context.dart';
import 'package:flutter_3d/math/colliders.dart';
import 'package:flutter_3d/ui/look_pad.dart';

// Replace only the GPU-owning context (Scene() needs the GPU); the camera and
// the player's state are real.
class _Context extends Fake implements HotelContext {
  @override
  final PerspectiveCamera camera = PerspectiveCamera(fovRadiansY: 60 * degrees2Radians);
  @override
  Vector2 playerXZ = Vector2(-4, 3);
  @override
  double playerYaw = 0;
  @override
  final Map<String, List<Box2>> dynamicColliders = {};
}

void main() {
  tearDown(() {
    PlayerFeature.focusLocked = false;
    PlayerFeature.stick.value = Offset.zero;
    PlayerFeature.pendingLook = Offset.zero;
  });

  test('locking and unlocking both drop held stick and queued look', () {
    PlayerFeature.stick.value = const Offset(0, 1);
    PlayerFeature.pendingLook = const Offset(80, 0);
    PlayerFeature.focusLocked = true;
    expect(PlayerFeature.stick.value, Offset.zero);
    expect(PlayerFeature.pendingLook, Offset.zero);

    // Anything that sneaks in while locked (the VM service can write these)
    // is gone on release, so the camera can't jump when the player resumes.
    PlayerFeature.stick.value = const Offset(1, 0);
    PlayerFeature.pendingLook = const Offset(0, 40);
    PlayerFeature.focusLocked = false;
    expect(PlayerFeature.stick.value, Offset.zero);
    expect(PlayerFeature.pendingLook, Offset.zero);
  });

  test('a locked player neither walks, turns nor moves the camera', () {
    final ctx = _Context();
    final player = PlayerFeature();
    player.tick(ctx, 1 / 60);
    final eye = ctx.camera.position.clone(), target = ctx.camera.target.clone();

    PlayerFeature.focusLocked = true;
    ctx.camera.position = Vector3(1, 2, 3); // another feature owns the camera
    ctx.camera.target = Vector3(1, 2, 4);
    PlayerFeature.stick.value = const Offset(0, 1);
    PlayerFeature.pendingLook = const Offset(120, 0);
    for (var i = 0; i < 30; i++) {
      player.tick(ctx, 1 / 60);
    }
    expect(ctx.playerXZ.x, closeTo(-4, 1e-6));
    expect(ctx.playerXZ.y, closeTo(3, 1e-6));
    expect(ctx.playerYaw, 0);
    expect(ctx.camera.position, Vector3(1, 2, 3));
    expect(ctx.camera.target, Vector3(1, 2, 4));

    // Released: the player resumes exactly where it stood, facing the same way.
    PlayerFeature.focusLocked = false;
    player.tick(ctx, 1 / 60);
    expect((ctx.camera.position - eye).length, lessThan(1e-6));
    expect((ctx.camera.target - target).length, lessThan(1e-6));
  });

  testWidgets('look pad and joystick input is ignored while locked', (tester) async {
    await tester.pumpWidget(MaterialApp(home: PlayerFeature.overlay(_Context())));
    final pad = tester.getCenter(find.byType(LookPad));
    final stick = tester.getCenter(find.byType(VirtualJoystick));

    // Drags the look pad, then pushes the joystick up and holds it
    // (releasing re-centres it, which would hide what it reported).
    Future<TestGesture> dragBoth() async {
      await tester.dragFrom(pad, const Offset(-120, 0));
      final hold = await tester.startGesture(stick);
      await hold.moveBy(const Offset(0, -20));
      await hold.moveBy(const Offset(0, -20));
      await tester.pump();
      return hold;
    }

    PlayerFeature.focusLocked = true;
    var hold = await dragBoth();
    expect(PlayerFeature.pendingLook, Offset.zero);
    expect(PlayerFeature.stick.value, Offset.zero);
    await hold.up();

    // Control: the same input unlocked does reach the player.
    PlayerFeature.focusLocked = false;
    hold = await dragBoth();
    expect(PlayerFeature.pendingLook.dx, lessThan(-50));
    expect(PlayerFeature.stick.value.dy, greaterThan(0));
    await hold.up();
  });
}
