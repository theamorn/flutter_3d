import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/home/shader_backdrop.dart';

void main() {
  test('each backdrop names its shader asset', () {
    expect(HomeShader.sea.asset, 'shaders/water.glsl');
    expect(HomeShader.sky.asset, 'shaders/sky.glsl');
  });

  test('the sea has five wave heights, calm to rough, under the camera', () {
    expect(kSeaLevels, hasLength(5));
    for (var i = 1; i < kSeaLevels.length; i++) {
      expect(kSeaLevels[i], greaterThan(kSeaLevels[i - 1]));
    }
    // The camera sits at y = 3.5 and crests reach about 2.54 x SEA_HEIGHT.
    expect(kSeaLevels.last, lessThanOrEqualTo(1.0));
  });

  test('the shaded image covers the box at the render scale', () {
    expect(shadedPixels(const Size(400, 300), 1.5), (600, 450));
    expect(shadedPixels(const Size(100.2, 50.1), 1.5), (151, 76));
    expect(shadedPixels(const Size(0.1, 0.1), 1.5), (1, 1));
  });

  testWidgets('shows the gradient while the shader loads', (tester) async {
    final never = Completer<ui.FragmentProgram>();
    await tester.pumpWidget(
      ShaderBackdrop(shader: HomeShader.sea, loader: (_) => never.future),
    );
    expect(find.byKey(ShaderBackdrop.fallbackKey), findsOneWidget);
  });

  testWidgets('a shader that fails to load leaves the gradient, not an error', (
    tester,
  ) async {
    await tester.pumpWidget(
      ShaderBackdrop(
        shader: HomeShader.sky,
        loader: (_) async => throw Exception('no shader'),
      ),
    );
    await tester.pump();
    expect(find.byKey(ShaderBackdrop.fallbackKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
