import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stac/stac.dart';

import 'package:flutter_3d/home/shader_backdrop.dart';
import 'package:flutter_3d/stac/firebase_stac_client.dart';
import 'package:flutter_3d/stac/stac_3d_scene.dart';
import 'package:flutter_3d/stac/stac_gpu_parsers.dart';
import 'package:flutter_3d/stac/stac_host_bridge.dart';

Widget _testBackdrop(HomeShader shader, ValueListenable<SeaInput> sea) =>
    ColoredBox(
      key: Key('stac-backdrop-${shader.name}'),
      color: Colors.blue,
      child: ValueListenableBuilder<SeaInput>(
        valueListenable: sea,
        builder: (_, input, _) => Text(
          '${shader.name} h=${input.height.toStringAsFixed(2)} l=${input.look.toStringAsFixed(2)}',
        ),
      ),
    );

void main() {
  setUp(() async {
    StacHostBridge.instance.reset();
    await ensureStacInitialized(backdropBuilder: _testBackdrop);
  });

  testWidgets(
    'Stac renders interactive_3d_turntable from JSON and sends spin + edition to host',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Builder(
                builder: (context) =>
                    Stac.fromJson(kDefaultStac3dCardJson, context) ??
                    const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Stac + Firebase Live 3D & Shader Studio'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('stac-3d-turntable')), findsOneWidget);

      // Dragging the 3D turntable horizontally rotates the 3D model and updates host bridge
      await tester.ensureVisible(find.byKey(const Key('stac-3d-turntable')));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('stac-3d-turntable')),
        const Offset(120, 0),
      );
      await tester.pumpAndSettle();

      expect(StacHostBridge.instance.value, isNotNull);
      expect(StacHostBridge.instance.value!.yawDegrees, isNot(0.0));

      // Tapping an edition chip updates the selected edition on the host bridge
      await tester.ensureVisible(find.text('Emerald'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Emerald'));
      await tester.pumpAndSettle();
      expect(StacHostBridge.instance.value!.edition, '3D Island · Emerald');

      // Tapping the model toggle switches to 3D Headphones
      await tester.ensureVisible(find.text('🎧 Headphones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('🎧 Headphones'));
      await tester.pumpAndSettle();
      expect(StacHostBridge.instance.value!.edition, '3D Headphones · Emerald');

      // Tapping the Stac filledButton triggers send_to_host action parser
      await tester.ensureVisible(find.text('Apply Stac 3D Offer (-20%)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply Stac 3D Offer (-20%)'));
      await tester.pumpAndSettle();
      expect(StacHostBridge.instance.value!.promoCode, 'STAC20');
      expect(StacHostBridge.instance.value!.discountPercent, 20);
    },
  );

  test('evaluateStacMaterializeSweep computes bottom-to-top laser bounds', () {
    final idle = evaluateStacMaterializeSweep(0.0, minY: -1.0, maxY: 2.0);
    expect(idle.active, isFalse);

    final mid = evaluateStacMaterializeSweep(0.5, minY: -1.0, maxY: 2.0);
    expect(mid.active, isTrue);
    expect(mid.wireFront, greaterThan(mid.fadeFront));
  });

  testWidgets(
    'Stac renders interactive_shader_box from JSON and sends wave level to host',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) =>
                  Stac.fromJson(kDefaultStacShaderCardJson, context) ??
                  const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Stac + Firebase Water Shader Promo'), findsOneWidget);
      expect(find.byKey(const Key('stac-shader-box')), findsOneWidget);

      await tester.tap(find.byKey(const Key('stac-shader-box')));
      await tester.pumpAndSettle();

      expect(StacHostBridge.instance.value, isNotNull);
      expect(StacHostBridge.instance.value!.promoCode, 'WAVE25');
      expect(StacHostBridge.instance.value!.discountPercent, 25);
    },
  );
}
