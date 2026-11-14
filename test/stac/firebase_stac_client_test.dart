import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/stac/firebase_stac_client.dart';
import 'package:flutter_3d/stac/stac_host_bridge.dart';

void main() {
  setUp(() {
    StacHostBridge.instance.reset();
  });

  test('StacHostBridge updates selection from map and computes THB discount', () {
    expect(StacHostBridge.instance.value, isNull);

    StacHostBridge.instance.updateFromMap({
      'edition': 'Sunset Gold',
      'discountPercent': 20,
      'promoCode': 'STAC20',
      'waveLevel': 'Storm',
      'yawDegrees': 135.0,
    });

    final selection = StacHostBridge.instance.value;
    expect(selection, isNotNull);
    expect(selection!.edition, 'Sunset Gold');
    expect(selection.discountPercent, 20);
    expect(selection.promoCode, 'STAC20');
    expect(selection.waveLevel, 'Storm');
    expect(selection.yawDegrees, 135.0);
    expect(selection.applyDiscountThb(5900), 4720);
  });

  test('parseFirebaseSsePayload extracts root JSON map from put event', () {
    const rawSse = 'event: put\n'
        'data: {"path":"/","data":{"type":"interactive_3d_turntable","edition":"Emerald","discountPercent":25}}\n\n';

    final parsed = FirebaseStacClient.parseSseEventData(rawSse);
    expect(parsed, isNotNull);
    expect(parsed!['type'], 'interactive_3d_turntable');
    expect(parsed['edition'], 'Emerald');
    expect(parsed['discountPercent'], 25);
  });

  test('parseFirebaseSsePayload ignores keep-alive and null data frames', () {
    const keepAlive = 'event: keep-alive\ndata: null\n\n';
    const nullPut = 'event: put\ndata: {"path":"/","data":null}\n\n';

    expect(FirebaseStacClient.parseSseEventData(keepAlive), isNull);
    expect(FirebaseStacClient.parseSseEventData(nullPut), isNull);
  });

  test('parseFirebaseSsePayload merges nested path updates into current JSON', () {
    final current = Map<String, dynamic>.from(kDefaultStac3dCardJson);
    const patchEvent = 'event: put\n'
        'data: {"path":"/discountPercent","data":30}\n\n';

    final updated = FirebaseStacClient.applySseChunkToDocument(
      current,
      patchEvent,
    );
    expect(updated, isNotNull);
    expect(updated!['discountPercent'], 30);
  });

  test('applySseChunkToDocument merges array index paths like /child/children/0/label/data', () {
    const arrayPathEvent = 'event: put\n'
        'data: {"path":"/child/children/0/label/data","data":"🔥 DEVFEST BKK FLASH DROP · 75% CLAIMED"}\n\n';

    final updated = FirebaseStacClient.applySseChunkToDocument(
      kDefaultStac3dCardJson,
      arrayPathEvent,
    );
    expect(updated, isNotNull);
    final children = (updated!['child'] as Map<String, dynamic>)['children'] as List<dynamic>;
    final firstChip = children[0] as Map<String, dynamic>;
    final label = firstChip['label'] as Map<String, dynamic>;
    expect(label['data'], '🔥 DEVFEST BKK FLASH DROP · 75% CLAIMED');
  });
}
