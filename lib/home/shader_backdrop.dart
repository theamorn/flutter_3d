import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// The Home page's two animated backdrops, from flutter_module's shaders.
enum HomeShader {
  /// A ray-marched Shadertoy sea with its own sky and moving horizon.
  sea('shaders/water.glsl', [Color(0xFF7FB8E6), Color(0xFF0B3D63)]),

  /// A blue sky with drifting clouds.
  sky('shaders/sky.glsl', [Color(0xFF80CCFF), Color(0xFFCCE6FF)]);

  const HomeShader(this.asset, this.fallback);

  final String asset;

  /// Top-to-bottom gradient shown until the shader loads, or if it can't.
  final List<Color> fallback;
}

/// The sea's wave heights (the shader's `SEA_HEIGHT`), calmest to roughest;
/// tapping the hero steps through them. flutter_module used about 0.1 for a
/// calm sea, the original Shadertoy 0.6. Crests reach about 2.54 times this
/// and the camera sits at 3.5, so above 1.0 it would sink under the waves.
const List<double> kSeaLevels = [0.1, 0.3, 0.5, 0.75, 1.0];

/// What the sea's shader takes from the hero: `look` is an extra heading for
/// its camera in radians, `height` its wave height. The sky ignores both.
typedef SeaInput = ({double look, double height});

/// A sea nothing drives: facing ahead, at the second of [kSeaLevels].
const AlwaysStoppedAnimation<SeaInput> kStillSea = AlwaysStoppedAnimation((
  look: 0.0,
  height: 0.3,
));

/// Pixels shaded per logical pixel, at most. The sea is soft, so shading it at
/// half a 3x phone's resolution and stretching the image looks the same for a
/// quarter of the work.
const double kShadeScale = 1.5;

/// The size in pixels of the image a [size] box is shaded into at [scale]:
/// rounded up so it covers the box, and never empty.
(int, int) shadedPixels(Size size, double scale) => (
  math.max(1, (size.width * scale).ceil()),
  math.max(1, (size.height * scale).ceil()),
);

typedef ProgramLoader = Future<ui.FragmentProgram> Function(String asset);

/// Paints [shader] across its box, animated. Its ticker obeys [TickerMode],
/// so it stops while its tab is hidden.
class ShaderBackdrop extends StatefulWidget {
  const ShaderBackdrop({
    super.key,
    required this.shader,
    this.sea = kStillSea,
    this.loader = ui.FragmentProgram.fromAsset,
  });

  final HomeShader shader;

  final ValueListenable<SeaInput> sea;
  final ProgramLoader loader;

  static const Key fallbackKey = Key('shader-backdrop-fallback');

  @override
  State<ShaderBackdrop> createState() => _ShaderBackdropState();
}

class _ShaderBackdropState extends State<ShaderBackdrop>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _seconds = ValueNotifier(0);
  late final Ticker _ticker = createTicker(
    (elapsed) => _seconds.value = elapsed.inMicroseconds / 1e6,
  );
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final program = await widget.loader(widget.shader.asset);
      if (!mounted) return;
      setState(() => _shader = program.fragmentShader());
      _ticker.start();
    } catch (e) {
      debugPrint('home: ${widget.shader.asset} did not load: $e');
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shader?.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    if (shader == null) {
      return DecoratedBox(
        key: ShaderBackdrop.fallbackKey,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: widget.shader.fallback,
          ),
        ),
      );
    }
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ShaderPainter(
          shader,
          widget.shader,
          _seconds,
          widget.sea,
          math.min(kShadeScale, MediaQuery.devicePixelRatioOf(context)),
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _ShaderPainter extends CustomPainter {
  _ShaderPainter(this.shader, this.kind, this.seconds, this.sea, this.scale)
    : super(repaint: Listenable.merge([seconds, sea]));

  final ui.FragmentShader shader;
  final HomeShader kind;
  final ValueNotifier<double> seconds;
  final ValueListenable<SeaInput> sea;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final (w, h) = shadedPixels(size, scale);
    final shaded = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
    // Uniform order, as the .glsl declares it: iResolution (2 floats),
    // iTime, then SEA_HEIGHT and uLook for the sea.
    shader
      ..setFloat(0, shaded.width)
      ..setFloat(1, shaded.height)
      ..setFloat(2, seconds.value);
    if (kind == HomeShader.sea) {
      shader
        ..setFloat(3, sea.value.height)
        ..setFloat(4, sea.value.look);
    }
    // The cost is per shaded pixel: shade a smaller image, then stretch it.
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(shaded, Paint()..shader = shader);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(w, h);
    picture.dispose();
    canvas.drawImageRect(
      image,
      shaded,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.low,
    );
    image.dispose();
  }

  @override
  bool shouldRepaint(_ShaderPainter old) =>
      old.shader != shader || old.sea != sea || old.scale != scale;
}
