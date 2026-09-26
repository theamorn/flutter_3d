import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import 'colliders.dart';
import 'floor_plan.dart';

const double kDoorOpenAngle = 100 * degrees2Radians;

/// Advances the hinge toward its target by at most [speed] radians per second.
double stepHinge(double angle, bool open, double dt, {double speed = 2.5}) {
  final step = math.max(0.0, dt * speed);
  return open
      ? math.min(kDoorOpenAngle, math.max(0.0, angle) + step)
      : math.max(0.0, math.min(kDoorOpenAngle, angle) - step);
}

/// Conservative doorway blocker while the leaf still crosses the opening.
List<Box2> doorColliders(double angle) => angle >= 60 * degrees2Radians
    ? const []
    : const [Box2(-0.05, FloorPlan.doorZ0, 0.05, FloorPlan.doorZ1)];
