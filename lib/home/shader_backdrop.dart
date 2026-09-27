import 'dart:ui' as ui;

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

/// The sea's wave height (the shader's `SEA_HEIGHT`). flutter_module used
/// about 0.1 for a calm sea; the original Shadertoy uses 0.6.
const double kSeaHeight = 0.3;

typedef ProgramLoader = Future<ui.FragmentProgram> Function(String asset);

/// Paints [shader] across its box, animated. Its ticker obeys [TickerMode],
/// so it stops while its tab is hidden.
class ShaderBackdrop extends StatefulWidget {
  const ShaderBackdrop({
    super.key,
    required this.shader,
    this.loader = ui.FragmentProgram.fromAsset,
  });

  final HomeShader shader;
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
    return CustomPaint(
      painter: _ShaderPainter(shader, widget.shader, _seconds),
      size: Size.infinite,
    );
  }
}

class _ShaderPainter extends CustomPainter {
  _ShaderPainter(this.shader, this.kind, this.seconds) : super(repaint: seconds);

  final ui.FragmentShader shader;
  final HomeShader kind;
  final ValueNotifier<double> seconds;

  @override
  void paint(Canvas canvas, Size size) {
    // Uniform order, as the .glsl declares it: iResolution (2 floats),
    // iTime, then SEA_HEIGHT for the sea.
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, seconds.value);
    if (kind == HomeShader.sea) shader.setFloat(3, kSeaHeight);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_ShaderPainter old) => old.shader != shader;
}
