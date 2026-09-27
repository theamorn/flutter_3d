import 'dart:math' as math;

import 'package:flutter/material.dart' hide Matrix4;
import 'package:flutter_scene/scene.dart' show MeshData;
import 'package:vector_math/vector_math.dart' hide Colors;

/// Engine rule 7: a WebView can't become a mesh texture, so a focused screen
/// shows its page in a platform view laid over the screen's projected quad.
/// Everything here but [ScreenOverlay] is pure maths (unit-tested).

/// Closest the focus pose gets to a screen, metres.
const double kMinFocusDistance = 0.9;

/// Largest share of the viewport's width or height a focused screen fills,
/// leaving room around it for the close button.
const double kFocusFill = 0.85;

/// Seconds the camera takes to glide to or from a screen.
const double kFocusEaseSeconds = 0.6;

/// Where [p] lands on screen (logical px, origin top-left), or null when it
/// is at or behind the camera. The exact inverse of `screenRay`, with
/// flutter_scene's view basis: right = up × forward, so facing +Z with +Y
/// up, world +X is screen-right.
Offset? projectToScreen(
  Vector3 p, {
  required Vector3 eye,
  required Vector3 target,
  Vector3? up,
  required double fovY,
  required Size viewport,
}) {
  final fwd = (target - eye).normalized();
  final right = (up ?? Vector3(0, 1, 0)).cross(fwd).normalized();
  final camUp = fwd.cross(right).normalized();
  final rel = p - eye;
  final depth = rel.dot(fwd);
  if (depth <= 0 || viewport.isEmpty) return null;
  final t = math.tan(fovY / 2);
  final ndcX = rel.dot(right) / (depth * t * viewport.width / viewport.height);
  final ndcY = rel.dot(camUp) / (depth * t);
  return Offset((ndcX + 1) / 2 * viewport.width, (1 - ndcY) / 2 * viewport.height);
}

/// Axis-aligned bounds of [corners] on screen, or null if any is behind the
/// camera.
Rect? projectedBounds(
  Iterable<Vector3> corners, {
  required Vector3 eye,
  required Vector3 target,
  Vector3? up,
  required double fovY,
  required Size viewport,
}) {
  Rect? bounds;
  for (final c in corners) {
    final p = projectToScreen(c, eye: eye, target: target, up: up, fovY: fovY, viewport: viewport);
    if (p == null) return null;
    final dot = Rect.fromLTWH(p.dx, p.dy, 0, 0);
    bounds = bounds?.expandToInclude(dot) ?? dot;
  }
  return bounds;
}

/// A vertical flat screen in world space.
class ScreenQuad {
  ScreenQuad._(this.corners, this.normal, this.width, this.height);

  /// Reads the screen from its mesh ([mesh] in node space) and the node's
  /// world transform: every vertex goes to world space, so a mirrored room B
  /// or a quad offset from its node origin both come out right. The normal
  /// (the side the picture is seen from) is the first vertex normal under the
  /// inverse transpose.
  factory ScreenQuad.fromMesh(MeshData mesh, Matrix4 world) {
    final n = mesh.normals;
    if (n == null || n.length < 3) {
      throw ArgumentError('A screen mesh needs vertex normals to know its front.');
    }
    final normalMatrix = world.getRotation()
      ..invert()
      ..transpose();
    final normal = normalMatrix.transformed(Vector3(n[0], n[1], n[2]))..normalize();
    final p = mesh.positions;
    final points = [
      for (var i = 0; i + 2 < p.length; i += 3) world.transform3(Vector3(p[i], p[i + 1], p[i + 2])),
    ];
    final origin = points.fold(Vector3.zero(), (a, b) => a + b) / points.length.toDouble();
    // A viewer facing the screen looks along −normal, so their right is
    // up × (−normal) = normal × up (the engine's basis) and their up is +Y.
    final right = normal.cross(Vector3(0, 1, 0))..normalize();
    final up = right.cross(normal)..normalize();
    var r0 = double.infinity, r1 = -double.infinity;
    var u0 = double.infinity, u1 = -double.infinity;
    for (final w in points) {
      final r = (w - origin).dot(right), u = (w - origin).dot(up);
      r0 = math.min(r0, r);
      r1 = math.max(r1, r);
      u0 = math.min(u0, u);
      u1 = math.max(u1, u);
    }
    Vector3 at(double r, double u) => origin + right * r + up * u;
    return ScreenQuad._(
        [at(r0, u1), at(r1, u1), at(r1, u0), at(r0, u0)], normal, r1 - r0, u1 - u0);
  }

  /// Top-left, top-right, bottom-right, bottom-left as a viewer in front of
  /// the screen sees them.
  final List<Vector3> corners;

  /// Unit normal on the picture side.
  final Vector3 normal;

  /// Metres.
  final double width, height;

  Vector3 get centre => (corners[0] + corners[2]) * 0.5;

  /// [distance] metres in front of the centre, looking straight at it.
  CameraPose focusPose(double distance) => CameraPose(centre + normal * distance, centre);
}

/// How far in front of [quad] the camera stops: [kMinFocusDistance], or
/// further when the screen would overflow [kFocusFill] of the viewport
/// (a 1.2 m TV in a portrait phone's narrow horizontal view).
double focusDistance(ScreenQuad quad, {required double fovY, required Size viewport}) =>
    fitDistance(quad.width, quad.height,
        fovY: fovY, viewport: viewport, min: kMinFocusDistance, fill: kFocusFill);

/// How far from the camera a facing [width] × [height] rectangle (metres)
/// fills at most [fill] of [viewport] in both directions, but no nearer
/// than [min].
double fitDistance(double width, double height,
    {required double fovY, required Size viewport, required double min, required double fill}) {
  if (viewport.isEmpty) return min;
  final halfH = math.tan(fovY / 2), halfW = halfH * viewport.width / viewport.height;
  return math.max(min, math.max(width / (2 * halfW * fill), height / (2 * halfH * fill)));
}

/// A camera eye and the point it looks at.
class CameraPose {
  CameraPose(this.eye, this.target);
  final Vector3 eye, target;
}

enum FocusPhase { idle, entering, focused, leaving }

/// The camera's glide to a screen and back: idle → entering → focused →
/// leaving → idle, easing position and target together over
/// [kFocusEaseSeconds]. Pure state; the caller applies the poses and owns
/// `PlayerFeature.focusLocked` for the whole non-idle span.
class FocusEase {
  FocusPhase get phase => _phase;
  FocusPhase _phase = FocusPhase.idle;
  CameraPose? _home, _from, _to;
  double _elapsed = 0;

  /// Starts gliding from [home] to [focus]. Only from idle.
  bool enter(CameraPose home, CameraPose focus) {
    if (_phase != FocusPhase.idle) return false;
    _home = home;
    _start(home, focus, FocusPhase.entering);
    return true;
  }

  /// Starts gliding back to the pose [enter] came from. Only once focused.
  bool leave() {
    if (_phase != FocusPhase.focused) return false;
    _start(_to!, _home!, FocusPhase.leaving);
    return true;
  }

  /// Advances [dt] seconds and returns the camera pose to show, or null when
  /// not gliding (idle or focused: nothing to write). The last step returns
  /// the destination exactly.
  CameraPose? step(double dt) {
    final from = _from, to = _to;
    if (from == null || to == null) return null;
    _elapsed += dt;
    final t = (_elapsed / kFocusEaseSeconds).clamp(0.0, 1.0);
    if (t >= 1) {
      _from = null;
      if (_phase == FocusPhase.leaving) {
        _phase = FocusPhase.idle;
        _home = _to = null;
      } else {
        _phase = FocusPhase.focused;
      }
      return to;
    }
    final s = t * t * (3 - 2 * t); // smoothstep: soft start and stop
    return CameraPose(
        from.eye + (to.eye - from.eye) * s, from.target + (to.target - from.target) * s);
  }

  /// Abandons any focus at once. Returns the pose [enter] came from if the
  /// ease wasn't idle (so the caller can put the camera back), else null.
  CameraPose? reset() {
    final home = _phase == FocusPhase.idle ? null : _home;
    _phase = FocusPhase.idle;
    _home = _from = _to = null;
    return home;
  }

  void _start(CameraPose from, CameraPose to, FocusPhase phase) {
    _from = from;
    _to = to;
    _elapsed = 0;
    _phase = phase;
  }
}

/// A page placed over a focused screen's projected [bounds], with a close
/// button on its top-right corner. A transparent barrier under it keeps
/// taps off the scene (and its other interactables) while it is up.
class ScreenOverlay extends StatelessWidget {
  const ScreenOverlay({super.key, required this.bounds, required this.onClose, required this.child});

  final Rect bounds;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) => Stack(children: [
          const Positioned.fill(child: ModalBarrier(dismissible: false)),
          Positioned.fromRect(rect: bounds, child: child),
          Positioned(
            // Centred on the page's corner, but never off screen.
            left: (bounds.right - 24).clamp(8.0, math.max(8.0, box.maxWidth - 56)),
            top: (bounds.top - 24).clamp(8.0, math.max(8.0, box.maxHeight - 56)),
            child: Material(
              color: Colors.black87,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Close screen',
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: onClose,
              ),
            ),
          ),
        ]),
      );
}
