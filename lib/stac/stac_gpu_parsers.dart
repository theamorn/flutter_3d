import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart' show SceneView;
import 'package:stac/stac.dart';

import '../home/home_page.dart' show BackdropBuilder, shaderBackdrop;
import '../home/shader_backdrop.dart';
import 'stac_3d_scene.dart';
import 'stac_host_bridge.dart';

const List<String> kWaveNames = ['Calm', 'Breeze', 'Swell', 'Rough', 'Storm'];

bool _stacInitialized = false;
BackdropBuilder _activeBackdropBuilder = shaderBackdrop;

/// Initializes Stac and registers the custom 3D turntable parser, shader box
/// parser, and two-way host action parser. Safe to call multiple times.
Future<void> ensureStacInitialized({BackdropBuilder? backdropBuilder}) async {
  if (backdropBuilder != null) {
    _activeBackdropBuilder = backdropBuilder;
  }
  if (_stacInitialized) return;
  _stacInitialized = true;
  await Stac.initialize(
    parsers: const [
      Stac3dTurntableParser(),
      StacShaderBoxParser(),
    ],
    actionParsers: const [StacSendToHostActionParser()],
  );
}

/// Model for `"type": "interactive_3d_turntable"` in Stac JSON.
class Stac3dTurntableModel {
  const Stac3dTurntableModel({
    required this.modelKind,
    required this.edition,
    required this.discountPercent,
    required this.promoCode,
    required this.height,
    required this.editions,
    required this.characterAnim,
    required this.autoSpinSpeed,
    required this.holoScanLoop,
  });

  factory Stac3dTurntableModel.fromJson(Map<String, dynamic> json) {
    final rawEditions = json['editions'];
    final parsedEditions = rawEditions is List
        ? rawEditions.map((e) => e.toString()).toList()
        : const ['Midnight', 'Sunset Gold', 'Emerald'];
    return Stac3dTurntableModel(
      modelKind: Stac3dModelKind.fromString(json['model'] as String?),
      edition: (json['edition'] as String?) ?? 'Sunset Gold',
      discountPercent: (json['discountPercent'] as num?)?.toInt() ?? 20,
      promoCode: (json['promoCode'] as String?) ?? 'STAC20',
      height: (json['height'] as num?)?.toDouble() ?? 320.0,
      editions: parsedEditions,
      characterAnim: (json['characterAnim'] as String?) ?? 'idle',
      autoSpinSpeed: (json['autoSpinSpeed'] as num?)?.toDouble() ?? 0.35,
      holoScanLoop: (json['holoScanLoop'] as bool?) ?? false,
    );
  }

  final Stac3dModelKind modelKind;
  final String edition;
  final int discountPercent;
  final String promoCode;
  final double height;
  final List<String> editions;
  final String characterAnim;
  final double autoSpinSpeed;
  final bool holoScanLoop;
}

/// Custom `StacParser` that renders an interactive 3D turntable (`flutter_scene`
/// 3D Island Diorama or 3D Nimbus Headphones) + `.fmat` Holographic Laser-Scan
/// Wireframe Shader + `water.glsl` Ocean Fragment Shader inside Stac JSON.
class Stac3dTurntableParser extends StacParser<Stac3dTurntableModel> {
  const Stac3dTurntableParser();

  @override
  String get type => 'interactive_3d_turntable';

  @override
  Stac3dTurntableModel getModel(Map<String, dynamic> json) =>
      Stac3dTurntableModel.fromJson(json);

  @override
  Widget parse(BuildContext context, Stac3dTurntableModel model) {
    return _Interactive3dTurntableWidget(model: model);
  }
}

class _Interactive3dTurntableWidget extends StatefulWidget {
  const _Interactive3dTurntableWidget({required this.model});

  final Stac3dTurntableModel model;

  @override
  State<_Interactive3dTurntableWidget> createState() =>
      _Interactive3dTurntableWidgetState();
}

class _Interactive3dTurntableWidgetState
    extends State<_Interactive3dTurntableWidget> {
  late Stac3dModelKind _modelKind = widget.model.modelKind;
  late String _edition = widget.model.edition;
  late String _characterAnim = widget.model.characterAnim;
  late double _autoSpinSpeed = widget.model.autoSpinSpeed;
  late bool _holoLoop = widget.model.holoScanLoop;
  double _yawRadians = 0.55;
  static const double _pitchRadians = 0.14;

  StacTurntableSceneController? _sceneController;
  bool _sceneLoaded = false;

  late final ValueNotifier<SeaInput> _seaNotifier = ValueNotifier<SeaInput>((
    look: _yawRadians * 0.45,
    height: _seaHeightForEdition(_edition),
  ));

  bool get _isHeadlessTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    if (!_isHeadlessTest) {
      _init3dScene();
    }
  }

  Future<void> _init3dScene() async {
    final (primary, _, _) = _paletteFor(_edition);
    final controller = StacTurntableSceneController(
      initialModel: _modelKind,
      initialAccent: primary,
    );
    _sceneController = controller;
    try {
      await controller.load();
      if (!mounted) {
        controller.dispose();
        return;
      }
      controller.setCharacterAnimMode(_characterAnim);
      controller.scanRig.setLooping(_holoLoop);
      setState(() => _sceneLoaded = true);
    } on Object {
      // Fallback to CustomPaint in environments without FlutterGPU.
    }
  }

  void _onSceneTick(double dt) {
    final clampedDt = dt.clamp(0.0, 0.05);
    _yawRadians += clampedDt * _autoSpinSpeed;
    _sceneController?.tick(
      clampedDt,
      yaw: _yawRadians,
      pitch: _pitchRadians,
    );
    _seaNotifier.value = (
      look: _yawRadians * 0.45,
      height: _seaHeightForEdition(_edition),
    );
  }

  @override
  void didUpdateWidget(covariant _Interactive3dTurntableWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model.modelKind != widget.model.modelKind) {
      _modelKind = widget.model.modelKind;
      _sceneController?.setModel(_modelKind, triggerScan: true);
    }
    if (oldWidget.model.edition != widget.model.edition) {
      _edition = widget.model.edition;
      final (primary, _, _) = _paletteFor(_edition);
      _sceneController?.applyEditionColor(primary, triggerScan: true);
    }
    if (oldWidget.model.characterAnim != widget.model.characterAnim) {
      _characterAnim = widget.model.characterAnim;
      _sceneController?.setCharacterAnimMode(_characterAnim);
    }
    if (oldWidget.model.autoSpinSpeed != widget.model.autoSpinSpeed) {
      _autoSpinSpeed = widget.model.autoSpinSpeed;
    }
    if (oldWidget.model.holoScanLoop != widget.model.holoScanLoop) {
      _holoLoop = widget.model.holoScanLoop;
      _sceneController?.scanRig.setLooping(_holoLoop);
    }
  }

  @override
  void dispose() {
    _sceneController?.dispose();
    _seaNotifier.dispose();
    super.dispose();
  }

  double get _yawDegrees =>
      ((_yawRadians * 180 / math.pi) % 360 + 360) % 360;

  double _seaHeightForEdition(String edition) {
    final lower = edition.toLowerCase();
    if (lower.contains('gold') || lower.contains('sunset')) return 0.55;
    if (lower.contains('emerald') || lower.contains('green')) return 0.40;
    return 0.72;
  }

  void _notifyHost() {
    StacHostBridge.instance.updateFromMap({
      'edition': '${_modelKind.label} · $_edition',
      'discountPercent': widget.model.discountPercent,
      'promoCode': widget.model.promoCode,
      'yawDegrees': double.parse(_yawDegrees.toStringAsFixed(1)),
    });
  }

  (Color, Color, Color) _paletteFor(String edition) {
    final lower = edition.toLowerCase();
    if (lower.contains('gold') || lower.contains('sunset')) {
      return (
        const Color(0xFFF59E0B),
        const Color(0xFFD97706),
        const Color(0xFFFEF3C7),
      );
    }
    if (lower.contains('emerald') || lower.contains('green')) {
      return (
        const Color(0xFF10B981),
        const Color(0xFF047857),
        const Color(0xFFD1FAE5),
      );
    }
    return (
      const Color(0xFF00E5FF),
      const Color(0xFF1E3A8A),
      const Color(0xFFCFFAFE),
    );
  }

  void _selectModel(Stac3dModelKind nextKind) {
    setState(() => _modelKind = nextKind);
    _sceneController?.setModel(nextKind, triggerScan: true);
    _notifyHost();
  }

  void _triggerOrToggleScan() {
    final controller = _sceneController;
    if (controller == null) return;
    if (!controller.scanRig.isActive) {
      controller.scanRig.triggerSweep();
      controller.triggerCharacterWave();
      setState(() {});
      return;
    }
    setState(() {
      _holoLoop = !_holoLoop;
      controller.scanRig.setLooping(_holoLoop);
    });
  }

  void _cycleCharacterAnim() {
    const order = ['idle', 'walk', 'punch'];
    final idx = order.indexOf(_characterAnim.toLowerCase());
    final next = order[(idx + 1) % order.length];
    setState(() => _characterAnim = next);
    _sceneController?.setCharacterAnimMode(next);
  }

  @override
  Widget build(BuildContext context) {
    final (primary, deep, highlight) = _paletteFor(_edition);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          key: const Key('stac-3d-turntable'),
          behavior: HitTestBehavior.opaque,
          // Horizontal drag only so a vertical drag inside CustomScrollView
          // or Native UITableView / ScrollView still scrolls the page cleanly.
          onHorizontalDragUpdate: (details) {
            setState(() {
              _yawRadians += details.delta.dx * 0.022;
              _seaNotifier.value = (
                look: _yawRadians * 0.45,
                height: _seaHeightForEdition(_edition),
              );
            });
            _sceneController?.tick(
              0.0,
              yaw: _yawRadians,
              pitch: _pitchRadians,
            );
            _notifyHost();
          },
          onTap: () {
            _sceneController?.scanRig.triggerSweep();
            _sceneController?.triggerCharacterWave();
            _notifyHost();
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: widget.model.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Live GPU Ocean Fragment Shader backdrop (`shaders/water.glsl`)
                  // in real simulator/device mode, or fallback in headless tests.
                  if (!_isHeadlessTest)
                    ShaderBackdrop(
                      shader: HomeShader.sea,
                      sea: _seaNotifier,
                    ),
                  // 2. Atmospheric edition color-grade vignette over the ocean shader.
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          deep.withValues(alpha: _sceneLoaded ? 0.32 : 0.85),
                          Colors.black.withValues(
                            alpha: _sceneLoaded ? 0.46 : 0.85,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 3. Real `flutter_scene` 3D SceneView (Island Diorama or
                  // Nimbus Headphones) + `.fmat` Holographic Laser-Scan Shader.
                  if (_sceneLoaded && _sceneController != null)
                    LayoutBuilder(
                      builder: (context, constraints) => SceneView(
                        _sceneController!.scene,
                        camera: _sceneController!.buildCamera(
                          constraints.biggest,
                        ),
                        onTick: (_, dt) => _onSceneTick(dt),
                        warmUp: true,
                      ),
                    )
                  else
                    CustomPaint(
                      painter: _Turntable3dPainter(
                        yaw: _yawRadians,
                        pitch: _pitchRadians,
                        primary: primary,
                        deep: deep,
                        highlight: highlight,
                      ),
                    ),
                  // 4. Interactive HUD controls & Shader triggers.
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _BadgePill(
                                    text: '3D · $_edition',
                                    color: Colors.black54,
                                  ),
                                  _BadgePill(
                                    text: '${_yawDegrees.toStringAsFixed(0)}°',
                                    color: Colors.black45,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _InteractiveOverlayChip(
                                  label: _modelKind == Stac3dModelKind.island
                                      ? '🎧 Headphones'
                                      : '🏝️ 3D Island',
                                  active: true,
                                  accent: primary,
                                  onTap: () => _selectModel(
                                    _modelKind == Stac3dModelKind.island
                                        ? Stac3dModelKind.headphones
                                        : Stac3dModelKind.island,
                                  ),
                                ),
                                if (_modelKind == Stac3dModelKind.island)
                                  _InteractiveOverlayChip(
                                    label: '🏃 ${_characterAnim.toUpperCase()}',
                                    active: _characterAnim != 'idle',
                                    accent: primary,
                                    onTap: _cycleCharacterAnim,
                                  ),
                                _InteractiveOverlayChip(
                                  label: _holoLoop
                                      ? '🕸️ Holo ON'
                                      : '⚡ Laser Scan',
                                  active:
                                      _holoLoop ||
                                      (_sceneController?.scanRig.isActive ??
                                          false),
                                  accent: primary,
                                  onTap: _triggerOrToggleScan,
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                'Drag to orbit 3D + Ocean Shader · Tap for .fmat Laser Scan',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.90),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black87,
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final item in widget.model.editions)
              ChoiceChip(
                label: Text(item),
                selected: _edition == item,
                onSelected: (_) {
                  setState(() => _edition = item);
                  final (accent, _, _) = _paletteFor(item);
                  _sceneController?.applyEditionColor(
                    accent,
                    triggerScan: true,
                  );
                  _seaNotifier.value = (
                    look: _yawRadians * 0.45,
                    height: _seaHeightForEdition(item),
                  );
                  _notifyHost();
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _InteractiveOverlayChip extends StatelessWidget {
  const _InteractiveOverlayChip({
    required this.label,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: active
              ? accent.withValues(alpha: 0.28)
              : Colors.black.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active
                ? accent.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.28),
            width: 1.2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgePill extends StatelessWidget {
  const _BadgePill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

/// Fallback 3D perspective mesh renderer used while the `flutter_scene` GPU
/// pipeline warms up or inside headless widget tests.
class _Turntable3dPainter extends CustomPainter {
  const _Turntable3dPainter({
    required this.yaw,
    required this.pitch,
    required this.primary,
    required this.deep,
    required this.highlight,
  });

  final double yaw;
  final double pitch;
  final Color primary;
  final Color deep;
  final Color highlight;

  (Offset, double) _project(
    double x,
    double y,
    double z,
    Size size,
  ) {
    final cosY = math.cos(yaw);
    final sinY = math.sin(yaw);
    final rx = x * cosY - z * sinY;
    final rz = x * sinY + z * cosY;

    final cosP = math.cos(pitch);
    final sinP = math.sin(pitch);
    final ry = y * cosP - rz * sinP;
    final fz = y * sinP + rz * cosP;

    final distance = 3.6;
    final perspective = distance / (distance + fz);
    final scale = math.min(size.width, size.height) * 0.42;
    return (
      Offset(
        size.width / 2 + rx * scale * perspective,
        size.height * 0.54 - ry * scale * perspective,
      ),
      fz,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bgRect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(deep, Colors.black, 0.55)!,
          Color.lerp(primary, Colors.black, 0.25)!,
        ],
      ).createShader(bgRect);
    canvas.drawRect(bgRect, bgPaint);

    final ringPoints = <Offset>[];
    const segments = 32;
    for (var i = 0; i <= segments; i++) {
      final a = (i / segments) * math.pi * 2;
      final (pt, _) = _project(
        math.cos(a) * 1.15,
        -0.68,
        math.sin(a) * 1.15,
        size,
      );
      ringPoints.add(pt);
    }
    final ringPath = Path()..addPolygon(ringPoints, false);
    canvas.drawPath(
      ringPath,
      Paint()
        ..color = highlight.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    const vertices = <(double, double, double)>[
      (0.0, 0.92, 0.0),
      (-0.78, 0.0, -0.78),
      (0.78, 0.0, -0.78),
      (0.78, 0.0, 0.78),
      (-0.78, 0.0, 0.78),
      (0.0, -0.62, 0.0),
    ];

    const faces = <(int, int, int, double)>[
      (0, 1, 2, 1.0),
      (0, 2, 3, 0.78),
      (0, 3, 4, 0.55),
      (0, 4, 1, 0.85),
      (5, 2, 1, 0.62),
      (5, 3, 2, 0.48),
      (5, 4, 3, 0.38),
      (5, 1, 4, 0.52),
    ];

    final projected = [
      for (final (vx, vy, vz) in vertices) _project(vx, vy, vz, size),
    ];

    final sortedFaces = [
      for (final (i0, i1, i2, shade) in faces)
        (
          i0: i0,
          i1: i1,
          i2: i2,
          shade: shade,
          depth: (projected[i0].$2 + projected[i1].$2 + projected[i2].$2) / 3.0,
        ),
    ]..sort((a, b) => b.depth.compareTo(a.depth));

    for (final face in sortedFaces) {
      final p0 = projected[face.i0].$1;
      final p1 = projected[face.i1].$1;
      final p2 = projected[face.i2].$1;
      final path = Path()
        ..moveTo(p0.dx, p0.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close();

      final faceColor = Color.lerp(deep, highlight, face.shade * 0.75)!;
      canvas.drawPath(path, Paint()..color = faceColor);
      canvas.drawPath(
        path,
        Paint()
          ..color = highlight.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Turntable3dPainter oldDelegate) =>
      oldDelegate.yaw != yaw ||
      oldDelegate.pitch != pitch ||
      oldDelegate.primary != primary;
}

/// Model for `"type": "interactive_shader_box"` in Stac JSON.
class StacShaderBoxModel {
  const StacShaderBoxModel({
    required this.shader,
    required this.initialWaveLevel,
    required this.discountPercent,
    required this.promoCode,
    required this.height,
  });

  factory StacShaderBoxModel.fromJson(Map<String, dynamic> json) {
    final shaderName = (json['shader'] as String?) ?? 'sea';
    return StacShaderBoxModel(
      shader: shaderName == 'sky' ? HomeShader.sky : HomeShader.sea,
      initialWaveLevel:
          ((json['initialWaveLevel'] as num?)?.toInt() ?? 2).clamp(
            0,
            kSeaLevels.length - 1,
          ),
      discountPercent: (json['discountPercent'] as num?)?.toInt() ?? 25,
      promoCode: (json['promoCode'] as String?) ?? 'WAVE25',
      height: (json['height'] as num?)?.toDouble() ?? 260.0,
    );
  }

  final HomeShader shader;
  final int initialWaveLevel;
  final int discountPercent;
  final String promoCode;
  final double height;
}

/// Custom `StacParser` that renders an interactive GPU FragmentShader (`water.glsl`
/// or `sky.glsl`) inside Stac JSON.
class StacShaderBoxParser extends StacParser<StacShaderBoxModel> {
  const StacShaderBoxParser({this.backdropBuilder});

  final BackdropBuilder? backdropBuilder;

  @override
  String get type => 'interactive_shader_box';

  @override
  StacShaderBoxModel getModel(Map<String, dynamic> json) =>
      StacShaderBoxModel.fromJson(json);

  @override
  Widget parse(BuildContext context, StacShaderBoxModel model) {
    return _InteractiveShaderBoxWidget(
      model: model,
      backdropBuilder: backdropBuilder ?? _activeBackdropBuilder,
    );
  }
}

class _InteractiveShaderBoxWidget extends StatefulWidget {
  const _InteractiveShaderBoxWidget({
    required this.model,
    required this.backdropBuilder,
  });

  final StacShaderBoxModel model;
  final BackdropBuilder backdropBuilder;

  @override
  State<_InteractiveShaderBoxWidget> createState() =>
      _InteractiveShaderBoxWidgetState();
}

class _InteractiveShaderBoxWidgetState
    extends State<_InteractiveShaderBoxWidget> {
  late int _level = widget.model.initialWaveLevel;
  late final ValueNotifier<SeaInput> _sea = ValueNotifier((
    look: 0.0,
    height: kSeaLevels[_level],
  ));

  @override
  void dispose() {
    _sea.dispose();
    super.dispose();
  }

  void _cycleWaves() {
    setState(() {
      _level = (_level + 1) % kSeaLevels.length;
      _sea.value = (look: _sea.value.look, height: kSeaLevels[_level]);
    });
    StacHostBridge.instance.updateFromMap({
      'edition': 'Shader · ${kWaveNames[_level]}',
      'waveLevel': kWaveNames[_level],
      'discountPercent': widget.model.discountPercent,
      'promoCode': widget.model.promoCode,
    });
  }

  void _dragLook(DragUpdateDetails details) {
    _sea.value = (
      look: _sea.value.look - details.delta.dx * 0.005,
      height: _sea.value.height,
    );
    StacHostBridge.instance.updateFromMap({
      'edition': 'Shader · ${kWaveNames[_level]}',
      'waveLevel': kWaveNames[_level],
      'discountPercent': widget.model.discountPercent,
      'promoCode': widget.model.promoCode,
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('stac-shader-box'),
      behavior: HitTestBehavior.opaque,
      onTap: _cycleWaves,
      onHorizontalDragUpdate: _dragLook,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: widget.model.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.backdropBuilder(widget.model.shader, _sea),
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _BadgePill(
                      text: 'GLSL · ${kWaveNames[_level]} Waves',
                      color: Colors.black54,
                    ),
                    _BadgePill(
                      text: 'Promo ${widget.model.promoCode}',
                      color: Colors.black45,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom `StacActionParser` for `"actionType": "send_to_host"`.
class StacSendToHostActionParser
    extends StacActionParser<Map<String, dynamic>> {
  const StacSendToHostActionParser();

  @override
  String get actionType => 'send_to_host';

  @override
  Map<String, dynamic> getModel(Map<String, dynamic> json) => json;

  @override
  FutureOr<dynamic> onCall(BuildContext context, Map<String, dynamic> model) {
    StacHostBridge.instance.updateFromMap(model);
    return model;
  }
}
