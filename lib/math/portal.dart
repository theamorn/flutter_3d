import 'floor_plan.dart';

/// Keep the far room drawn until the leaf is fully seated in the frame.
bool doorwayExposed(double hingeAngle) => hingeAngle > 0;

/// The camera room is always shown; an exposed doorway shows both rooms.
Set<RoomId> visibleRooms({
  required RoomId cameraRoom,
  required bool doorOpen,
  required bool cullingEnabled,
}) => cullingEnabled && !doorOpen ? {cameraRoom} : RoomId.values.toSet();
