import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/math/floor_plan.dart';
import 'package:flutter_3d/math/portal.dart';
import 'package:flutter_3d/math/door_hinge.dart';

void main() {
  test('closed door with culling shows only the camera room', () {
    expect(
      visibleRooms(cameraRoom: RoomId.a, doorOpen: false, cullingEnabled: true),
      {RoomId.a},
    );
    expect(
      visibleRooms(cameraRoom: RoomId.b, doorOpen: false, cullingEnabled: true),
      {RoomId.b},
    );
  });

  test('open door exposes both rooms from either side', () {
    for (final id in RoomId.values) {
      expect(
        visibleRooms(cameraRoom: id, doorOpen: true, cullingEnabled: true),
        {RoomId.a, RoomId.b},
      );
    }
  });

  test('disabling culling exposes both rooms with door closed', () {
    expect(
      visibleRooms(
        cameraRoom: RoomId.a,
        doorOpen: false,
        cullingEnabled: false,
      ),
      {RoomId.a, RoomId.b},
    );
  });

  test('any unseated hinge angle keeps the far room visible', () {
    expect(doorwayExposed(0), false);
    expect(doorwayExposed(0.001), true);
    expect(doorwayExposed(kDoorOpenAngle), true);
  });
}
