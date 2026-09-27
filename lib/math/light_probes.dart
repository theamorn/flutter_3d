import 'package:vector_math/vector_math.dart';

import 'floor_plan.dart';
import 'occlusion.dart' show Cell;

/// A probe box in room A's frame. Higher priority wins where boxes overlap.
typedef ProbeBox = ({Vector3 center, Vector3 halfExtents, double priority});

/// Bedroom and bathroom boxes, mirrored into room B by its parent node.
List<ProbeBox> roomProbeBoxes() {
  const halfHeight = FloorPlan.ceiling / 2;
  return [
    (
      center: Vector3(
        -FloorPlan.roomWidth / 2,
        halfHeight,
        FloorPlan.roomDepth / 2,
      ),
      halfExtents: Vector3(
        FloorPlan.roomWidth / 2,
        halfHeight,
        FloorPlan.roomDepth / 2,
      ),
      priority: 10.0,
    ),
    (
      center: Vector3(
        (-FloorPlan.roomWidth + FloorPlan.bathX1) / 2,
        halfHeight,
        FloorPlan.bathZ1 / 2,
      ),
      halfExtents: Vector3(
        (FloorPlan.bathX1 + FloorPlan.roomWidth) / 2,
        halfHeight,
        FloorPlan.bathZ1 / 2,
      ),
      priority: 20.0,
    ),
  ];
}

/// Which of a room's [roomProbeBoxes] lights a surface in [cell]: the
/// bedroom's, the bathroom's, or none outdoors (the balconies included),
/// where the sky lights it.
int? probeBoxFor(Cell cell) => switch (cell) {
  Cell.roomA || Cell.roomB => 0,
  Cell.bathA || Cell.bathB => 1,
  Cell.outdoors => null,
};

/// Lighting inputs whose meaningful changes trigger another probe capture.
class LightingSignature {
  LightingSignature({
    required this.timeOfDay,
    required this.weather,
    required this.sky,
    required this.revision,
  });

  final double timeOfDay, weather;
  final Object? sky;
  final int revision;

  bool differsFrom(LightingSignature before) =>
      timeOfDay != before.timeOfDay ||
      revision != before.revision ||
      !identical(sky, before.sky) ||
      (weather - before.weather).abs() > 0.05;
}

/// Schedules at most one probe capture per frame while holding occlusion open.
class CaptureQueue {
  CaptureQueue(this.count);

  final int count;
  int _next = -1;

  bool get busy => _next >= 0;

  void start() => _next = 0;

  void cancel() => _next = -1;

  ({int? capture, bool hold}) step() {
    if (_next < 0 || _next >= count) {
      _next = -1;
      return (capture: null, hold: false);
    }
    return (capture: _next++, hold: true);
  }
}
