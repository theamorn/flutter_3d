import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'nimbus_headphones.dart';

/// The park: Poly Haven's "Symmetrical Garden 02", CC0 (see
/// `assets/environments/CREDITS.txt`).
const String parkEnvironmentAsset =
    'assets/environments/symmetrical_garden_02_1k.hdr';

/// Radians about Y that bring the park's garden path behind the model.
const double parkRotation = math.pi / 2;

/// The Nimbus One headphones on a turntable for Slide 05.
///
/// The camera and park stay put while the procedural 3D model turns, so
/// trees, hedges, and sky slide across the spun metal and chrome as it moves.
class ProductScene {
  /// Seconds without a touch before the slow showroom spin starts.
  static const double idleDelay = 2.0;

  /// The idle spin, in radians per second: one turn in about 25 seconds.
  static const double idleSpinSpeed = 0.25;

  /// How fast a fling dies out, per second.
  static const double flingDecay = 4.0;

  /// Tilt limits, in radians, so the model never turns upside down.
  static const double maxPitch = 1.0;

  /// The tilt the idle spin settles back to: a little from above.
  static const double restPitch = 0.18;

  /// Initial three-quarter showroom angle.
  static const double restYaw = -0.6;

  Scene? _scene;
  Scene get scene => _scene!;

  Node? _model;

  bool _loaded = false;
  bool get loaded => _loaded;

  bool _autoSpin = true;
  bool get autoSpin => _autoSpin;

  // A three-quarter view: the band and the right ear cup's spun-metal plate.
  double _yaw = restYaw;
  double _pitch = restPitch;
  double _idleSeconds = idleDelay;
  double _spin = 1.0;
  vm.Vector2 _flingVelocity = vm.Vector2.zero();
  bool _dragging = false;

  /// Current yaw normalized to `[-180, 180]` degrees for telemetry display.
  int get yawDegrees {
    var deg = (_yaw * vm.radians2Degrees) % 360;
    if (deg > 180) deg -= 360;
    if (deg < -180) deg += 360;
    return deg.round();
  }

  Future<void> load() async {
    final createdScene = Scene();
    _scene = createdScene;

    // Sheen, clearcoat, and anisotropy use the physical material variants.
    await Scene.preload(physicalMaterials: true);

    createdScene
      ..renderScale = 1.0
      ..antiAliasingMode = AntiAliasingMode.msaa
      ..maxGpuFramesInFlight = 2;

    final park = await EnvironmentMap.fromEquirectImageAsset(
      assetPath: parkEnvironmentAsset,
      maxWidth: 512,
    );
    createdScene.environmentSettings = EnvironmentSettings(
      environment: park,
      // Turns the park so its garden path and pergola sit behind the model.
      environmentTransform: vm.Matrix3.rotationY(parkRotation),
      skybox: Skybox(EnvironmentSkySource(blurriness: 0.0)),
      skyEnvironment: null,
      toneMapping: ToneMappingMode.aces,
      exposure: 1.0,
      bloomEnabled: true,
      bloomThreshold: 1.4,
      bloomIntensity: 0.15,
      bloomScatter: 0.65,
    );
    // Soft daylight from above and behind the camera; the park's own sky
    // lights everything else.
    createdScene.directionalLight = DirectionalLight(
      direction: vm.Vector3(-0.3, -1.0, 0.4),
      intensity: 1.6,
    );

    final model = await buildNimbusHeadphones();
    _model = model;
    createdScene.add(model);
    _applyPose();

    final camera =
        Node(
          name: 'camera',
          localTransform: Node.lookAtTransform(
            vm.Vector3(0, 0.22, -3.4),
            vm.Vector3(0, 0.07, 0),
          ),
        )..addComponent(
          CameraComponent(
            projection: PerspectiveProjection(
              fovRadiansY: 35 * vm.degrees2Radians,
              near: 0.1,
              far: 20.0,
            ),
            activateOnMount: true,
          ),
        );
    createdScene.add(camera);
    _loaded = true;
  }

  void dragStart() {
    _dragging = true;
    _flingVelocity = vm.Vector2.zero();
    _idleSeconds = 0;
    _spin = 0;
  }

  /// [delta] is in logical pixels; [viewportHeight] scales it so a
  /// full-height drag is half a turn.
  void dragUpdate(Offset delta, double viewportHeight) {
    final k = math.pi / math.max(viewportHeight, 1);
    _turnBy(delta.dx * k, delta.dy * k);
  }

  /// [velocity] is the release velocity in logical pixels per second.
  void dragEnd(Offset velocity, double viewportHeight) {
    _dragging = false;
    final k = math.pi / math.max(viewportHeight, 1);
    _flingVelocity = vm.Vector2(velocity.dx * k, velocity.dy * k);
    _idleSeconds = 0;
  }

  void toggleAutoSpin() {
    _autoSpin = !_autoSpin;
    if (_autoSpin) {
      _idleSeconds = idleDelay;
    } else {
      _spin = 0;
    }
  }

  void resetPose() {
    _dragging = false;
    _flingVelocity = vm.Vector2.zero();
    _yaw = restYaw;
    _pitch = restPitch;
    _idleSeconds = idleDelay;
    _spin = _autoSpin ? 1.0 : 0.0;
    _applyPose();
  }

  void tick(double dt) {
    if (!_loaded || _dragging) return;
    if (_flingVelocity.length2 > 1e-6) {
      _turnBy(_flingVelocity.x * dt, _flingVelocity.y * dt);
      _flingVelocity *= math.exp(-flingDecay * dt);
    }
    _idleSeconds += dt;
    if (_autoSpin && _idleSeconds > idleDelay) {
      _spin = math.min(_spin + dt * 0.5, 1.0);
      _pitch += (restPitch - _pitch) * (1 - math.exp(-1.5 * dt));
      _turnBy(idleSpinSpeed * _spin * dt, 0);
    }
  }

  void _turnBy(double yaw, double pitch) {
    _yaw = (_yaw + yaw) % (2 * math.pi);
    _pitch = (_pitch + pitch).clamp(-maxPitch, maxPitch);
    _applyPose();
  }

  /// Yaw about the model's own vertical, then tilt toward the camera, which
  /// looks along +Z, so a drag down tips the top of the band toward it.
  void _applyPose() {
    final model = _model;
    if (model == null) return;
    final rotation =
        vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), -_pitch) *
        vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), _yaw);
    model.localTransform = vm.Matrix4.compose(
      vm.Vector3.zero(),
      rotation,
      vm.Vector3.all(1),
    );
  }

  void dispose() {
    _scene?.dispose();
    try {
      releaseTransientRenderTargets();
    } catch (_) {
      // Safe no-op in headless environments without a Flutter GPU context.
    }
  }
}
