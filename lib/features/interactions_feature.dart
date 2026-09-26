import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' show Ray;
import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import '../math/picking.dart';
import 'interaction_registry.dart';

/// You interact within arm's reach-ish: no lamps from across two rooms.
const double kReach = 6;

/// Seconds between crosshair-label probes (engine rule 4: no per-frame rays).
const double _probeInterval = 0.2;

typedef Raycast = SceneRaycastHit? Function(Ray ray, {required double maxDistance});

/// Makes [n] and everything under it hit-testable by `Scene.raycast`.
void markRaycastable(Node n) {
  n.raycastable = true;
  for (final c in n.children) {
    markRaycastable(c);
  }
}

/// The interactable a ray points at: the nearest mesh within [kReach], if it
/// belongs to one. A nearer ordinary mesh (a wall) blocks the ones behind.
Interactable? pick(InteractionRegistry registry, Ray ray, Raycast raycast) {
  final hit = raycast(ray, maxDistance: kReach);
  return hit == null ? null : registry.forNode(hit.node);
}

/// Scene raycast with `includeInvisible` left false, so portal-culled rooms
/// (hidden by Task 17) are never picked.
Raycast _sceneRaycast(Scene scene) =>
    (ray, {required maxDistance}) => scene.raycast(ray, maxDistance: maxDistance);

class InteractionsFeature extends HotelFeature {
  @override
  String get id => 'interactions';
  @override
  String get label => 'Tap to interact';
  @override
  CostTier get tier => CostTier.free;
  @override
  bool get toggleable => false;

  /// Label of whatever the crosshair is on, refreshed every 0.2 s.
  static final ValueNotifier<String?> aimedLabel = ValueNotifier(null);

  double _sinceProbe = 0;
  VoidCallback? _markAll;

  @override
  Future<void> mount(HotelContext ctx) async {
    void markAll() {
      for (final i in ctx.interactions.all) {
        markRaycastable(i.node);
      }
    }

    _markAll = markAll;
    ctx.interactions.addListener(markAll);
    markAll();
  }

  @override
  void unmount(HotelContext ctx) {
    final m = _markAll;
    if (m != null) ctx.interactions.removeListener(m);
    _markAll = null;
    aimedLabel.value = null;
  }

  @override
  void tick(HotelContext ctx, double dt) {
    _sinceProbe += dt;
    if (_sinceProbe < _probeInterval) return;
    _sinceProbe = 0;
    final cam = ctx.camera;
    aimedLabel.value = pick(ctx.interactions, Ray.originDirection(cam.position, cam.forward),
            _sceneRaycast(ctx.scene))
        ?.label;
  }

  /// Taps whatever is under [screen] in a view of [viewport] size.
  static void tapAt(HotelContext ctx, Offset screen, Size viewport) {
    final cam = ctx.camera;
    final r = screenRay(
        screen: screen,
        viewport: viewport,
        eye: cam.position,
        target: cam.target,
        up: cam.up,
        fovY: cam.fovRadiansY);
    pick(ctx.interactions, Ray.originDirection(r.origin, r.direction), _sceneRaycast(ctx.scene))
        ?.onTap();
  }

  /// Full-screen tap layer (placed below the joystick and look pad, which
  /// win drags) plus the crosshair and its label.
  static Widget overlay(HotelContext ctx) => LayoutBuilder(
        builder: (context, box) => Stack(children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: (d) => tapAt(ctx, d.localPosition, box.biggest),
            ),
          ),
          const IgnorePointer(
            child: Center(child: Icon(Icons.add, color: Colors.white70)),
          ),
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, 34),
                child: ValueListenableBuilder<String?>(
                  valueListenable: aimedLabel,
                  builder: (_, label, _) => label == null
                      ? const SizedBox.shrink()
                      : DecoratedBox(
                          decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            child: Text(label,
                                style: const TextStyle(color: Colors.white, fontSize: 13)),
                          ),
                        ),
                ),
              ),
            ),
          ),
        ]),
      );
}
