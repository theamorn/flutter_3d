import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Color;
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Which 3D showcase model the Stac turntable renders.
enum Stac3dModelKind {
  island('island', '3D Island'),
  headphones('headphones', '3D Headphones');

  const Stac3dModelKind(this.id, this.label);
  final String id;
  final String label;

  static Stac3dModelKind fromString(String? raw) {
    if (raw == null) return Stac3dModelKind.island;
    final normalized = raw.trim().toLowerCase();
    if (normalized.contains('headphone') || normalized.contains('nimbus')) {
      return Stac3dModelKind.headphones;
    }
    return Stac3dModelKind.island;
  }
}

/// Evaluates the leading laser front (`wireFront`) and trailing vanish front
/// (`fadeFront`) for normalized [progress] in `0..1` across `[minY, maxY]`.
({
  double wireFront,
  double fadeFront,
  double edgeWidth,
  double fadeWidth,
  bool active,
}) evaluateStacMaterializeSweep(
  double progress, {
  required double minY,
  required double maxY,
  double edgeWidth = 0.38,
  double fadeLag = 0.34,
  double fadeWidth = 0.68,
  double noisePad = 0.32,
}) {
  if (progress <= 0.0 || progress >= 1.0) {
    return (
      wireFront: minY - edgeWidth - noisePad,
      fadeFront: minY - edgeWidth - fadeWidth - noisePad,
      edgeWidth: edgeWidth,
      fadeWidth: fadeWidth,
      active: false,
    );
  }
  final t = progress.clamp(0.0, 1.0);
  final eased = t * t * (3.0 - 2.0 * t);
  final span = (maxY - minY).abs() < 1e-3 ? 1.0 : (maxY - minY);
  final startY = minY - noisePad;
  final endY = maxY + span * fadeLag + fadeWidth + edgeWidth + noisePad;
  final wireFront = startY + (endY - startY) * eased;
  final fadeFront = wireFront - span * fadeLag;
  return (
    wireFront: wireFront,
    fadeFront: fadeFront,
    edgeWidth: edgeWidth,
    fadeWidth: fadeWidth,
    active: true,
  );
}

/// Self-contained holographic wireframe laser-scan rig driven by
/// `assets/materials/materialize_wireframe.fmat`.
class StacMaterializeScanRig {
  StacMaterializeScanRig({
    this.minY = -1.35,
    this.maxY = 2.15,
    this.durationSeconds = 1.85,
    this.edgeWidth = 0.38,
    this.fadeLag = 0.34,
    this.fadeWidth = 0.68,
    this.lineWidth = 0.009,
  });

  final double minY;
  final double maxY;
  final double durationSeconds;
  final double edgeWidth;
  final double fadeLag;
  final double fadeWidth;
  final double lineWidth;

  PreprocessedMaterial? _material;
  final List<Node> _wireNodes = <Node>[];
  double _elapsed = 0.0;
  bool _running = false;
  bool _looping = false;

  bool get isActive => _running || _looping;
  bool get isLooping => _looping;

  /// Recursively extracts unique edges from readable meshes under [roots] and
  /// attaches `LineSegmentsGeometry` wireframe overlays.
  Future<void> attachToHierarchy(
    Iterable<Node> roots, {
    Color? accentColor,
  }) async {
    detach();
    PreprocessedMaterial material;
    try {
      material = _material ??= await loadFmatMaterial(
        'assets/materials/materialize_wireframe.fmat',
      );
    } on Object {
      return;
    }

    if (accentColor != null) {
      updateAccentColor(accentColor);
    }

    void visit(Node node) {
      if (node.name.endsWith('_holo_wire') || node.name == 'island_sea_disc') {
        return;
      }
      final childrenSnapshot = List<Node>.of(node.children);
      final mesh = node.mesh;
      if (mesh != null) {
        final parts = <MeshData>[
          for (final p in mesh.primitives)
            if (p.geometry.isReadable) p.geometry.extractMeshData(),
        ];
        if (parts.isNotEmpty) {
          final merged =
              parts.length == 1 ? parts.first : MeshData.merge(parts);
          final edges = merged.extractEdges();
          final wireGeom = LineSegmentsGeometry(
            edges,
            width: lineWidth,
            normalOffset: 0.0025,
          );
          final wireNode = Node(
            name: '${node.name}_holo_wire',
            mesh: Mesh(wireGeom, material),
          )
            ..shadowCastingMode = ShadowCastingMode.off
            ..visible = false;
          node.add(wireNode);
          _wireNodes.add(wireNode);
        }
      }
      for (final child in childrenSnapshot) {
        visit(child);
      }
    }

    for (final root in roots) {
      visit(root);
    }
    _syncMaterial(0.0);
  }

  void updateAccentColor(Color accent) {
    final mat = _material;
    if (mat == null) return;
    final r = (accent.r * 255.0).round().clamp(0, 255) / 255.0;
    final g = (accent.g * 255.0).round().clamp(0, 255) / 255.0;
    final b = (accent.b * 255.0).round().clamp(0, 255) / 255.0;
    mat.parameters
      ..setVec4('wire_color', vm.Vector4(r, g, b, 1.0))
      ..setVec4(
        'glow_color',
        vm.Vector4(
          (r + 0.35).clamp(0.0, 1.0),
          (g + 0.35).clamp(0.0, 1.0),
          (b + 0.35).clamp(0.0, 1.0),
          1.0,
        ),
      );
  }

  void triggerSweep() {
    if (_wireNodes.isEmpty) return;
    _elapsed = 0.0;
    _running = true;
    for (final node in _wireNodes) {
      node.visible = true;
    }
    _syncMaterial(0.02);
  }

  void setLooping(bool loop) {
    if (_looping == loop) return;
    _looping = loop;
    if (loop) {
      _elapsed = 0.0;
      for (final node in _wireNodes) {
        node.visible = true;
      }
      _syncMaterial(0.02);
    } else if (!_running) {
      for (final node in _wireNodes) {
        node.visible = false;
      }
    }
  }

  void tick(double dt) {
    if (!isActive || _wireNodes.isEmpty) return;
    _elapsed += dt;
    final progress = _elapsed / durationSeconds;
    if (_looping) {
      final cycle = progress % 1.0;
      _syncMaterial(cycle.clamp(0.02, 0.98));
      return;
    }
    if (progress >= 1.0) {
      _running = false;
      for (final node in _wireNodes) {
        node.visible = false;
      }
      _syncMaterial(0.0);
      return;
    }
    _syncMaterial(progress);
  }

  void _syncMaterial(double progress) {
    final mat = _material;
    if (mat == null) return;
    final s = evaluateStacMaterializeSweep(
      progress,
      minY: minY,
      maxY: maxY,
      edgeWidth: edgeWidth,
      fadeLag: fadeLag,
      fadeWidth: fadeWidth,
    );
    mat.parameters.setVec4(
      'sweep',
      vm.Vector4(s.wireFront, s.fadeFront, s.edgeWidth, s.fadeWidth),
    );
  }

  void detach() {
    _running = false;
    _looping = false;
    for (final node in _wireNodes) {
      node.detach();
    }
    _wireNodes.clear();
  }
}

/// Manages the real `flutter_scene` 3D showcase inside the Stac card,
/// supporting both the 3D Mini-Island Diorama and the 3D Nimbus Headphones
/// with `.fmat` shaders (`materialize_wireframe.fmat` + `ember_bed.fmat`).
class StacTurntableSceneController {
  StacTurntableSceneController({
    required Stac3dModelKind initialModel,
    required Color initialAccent,
  }) : _activeModel = initialModel,
       _accentColor = initialAccent;

  final Scene scene = Scene();
  final StacMaterializeScanRig scanRig = StacMaterializeScanRig();

  Stac3dModelKind _activeModel;
  Stac3dModelKind get activeModel => _activeModel;

  Color _accentColor;
  Color get accentColor => _accentColor;

  final Node turntableRoot = Node(name: 'stac_turntable_root');
  final Node islandRoot = Node(name: 'stac_island_root');
  final Node headphonesRoot = Node(name: 'stac_headphones_root');

  late final DirectionalLight keyLight;
  late final DirectionalLight rimLight;
  late final PointLight campfirePointLight;

  // Dynamic materials that react to the selected Stac edition.
  final PhysicallyBasedMaterial _headphoneCupMat = PhysicallyBasedMaterial()
    ..metallicFactor = 0.90
    ..roughnessFactor = 0.24
    ..clearcoat = 0.88
    ..clearcoatRoughness = 0.08;

  final PhysicallyBasedMaterial _headphonePlateMat = PhysicallyBasedMaterial()
    ..metallicFactor = 0.94
    ..roughnessFactor = 0.16
    ..clearcoat = 0.65
    ..clearcoatRoughness = 0.10;

  final PhysicallyBasedMaterial _islandHoloRingMat = PhysicallyBasedMaterial()
    ..metallicFactor = 0.85
    ..roughnessFactor = 0.18
    ..clearcoat = 0.90;

  final PhysicallyBasedMaterial _seaMat = PhysicallyBasedMaterial()
    ..baseColorFactor = vm.Vector4(0.04, 0.22, 0.36, 1.0)
    ..metallicFactor = 0.15
    ..roughnessFactor = 0.12
    ..clearcoat = 0.92
    ..clearcoatRoughness = 0.06;

  PreprocessedSky? _skyShader;
  PreprocessedMaterial? _emberBedMat;
  Node? _seagullPivot;
  Node? _holoRingOuter;
  Node? _holoRingInner;
  AnimationClip? _characterIdleClip;
  AnimationClip? _characterWalkClip;
  AnimationClip? _characterActionClip;
  AnimationClip? _seagullFlyClip;
  String _characterAnimMode = 'idle';
  String get characterAnimMode => _characterAnimMode;
  double _actionTimer = 0.0;
  double _elapsed = 0.0;
  bool _loaded = false;
  bool get isLoaded => _loaded;

  final Map<UnlitMaterial, PhysicallyBasedMaterial> _relitUnlitCache =
      <UnlitMaterial, PhysicallyBasedMaterial>{};

  Future<void> load() async {
    await Scene.preload(physicalMaterials: true, smaa: false);

    scene.environmentIntensity = 1.15;
    scene.postProcess.bloom
      ..enabled = true
      ..threshold = 1.15
      ..intensity = 0.28;

    try {
      _skyShader = await loadFmatSky('assets/materials/island_sky.fmat');
      scene.skybox = Skybox(_skyShader!);
    } on Object {
      // Fallback if sky .fmat is unavailable in headless tests.
    }

    // Warm key light + edition-tinted rim light.
    keyLight = DirectionalLight(
      color: vm.Vector3(1.0, 0.96, 0.88),
      intensity: 2.8,
      castsShadow: false,
    );
    final keyNode = Node(name: 'stac_key_light')
      ..addComponent(DirectionalLightComponent(keyLight))
      ..lookAtFrom(vm.Vector3(4.5, 6.2, 5.0), vm.Vector3.zero());
    scene.add(keyNode);

    rimLight = DirectionalLight(
      color: vm.Vector3(0.35, 0.82, 1.0),
      intensity: 1.45,
      castsShadow: false,
    );
    final rimNode = Node(name: 'stac_rim_light')
      ..addComponent(DirectionalLightComponent(rimLight))
      ..lookAtFrom(vm.Vector3(-5.0, 3.0, -4.5), vm.Vector3.zero());
    scene.add(rimNode);

    campfirePointLight = PointLight(
      color: vm.Vector3(1.0, 0.56, 0.18),
      intensity: 3.4,
      range: 3.6,
    );
    final fireLightNode = Node(name: 'stac_campfire_light')
      ..position = vm.Vector3(0.28, 0.25, 0.32)
      ..addComponent(PointLightComponent(campfirePointLight));
    islandRoot.add(fireLightNode);

    await _buildIslandDiorama();
    _buildHeadphonesShowpiece();

    turntableRoot
      ..add(islandRoot)
      ..add(headphonesRoot);
    scene.add(turntableRoot);

    await scanRig.attachToHierarchy(
      <Node>[islandRoot, headphonesRoot],
      accentColor: _accentColor,
    );

    _syncModelVisibility();
    applyEditionColor(_accentColor, triggerScan: true);
    _loaded = true;
  }

  Future<void> _buildIslandDiorama() async {
    // 1. Floating terraced island base (readable procedural geometry so
    // MaterializeScanRig always extracts rich 3D wireframe lines).
    final grassMat = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.18, 0.54, 0.28, 1.0)
      ..metallicFactor = 0.0
      ..roughnessFactor = 0.82;
    final sandMat = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.84, 0.72, 0.48, 1.0)
      ..metallicFactor = 0.0
      ..roughnessFactor = 0.76;
    final cliffMat = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.34, 0.27, 0.22, 1.0)
      ..metallicFactor = 0.05
      ..roughnessFactor = 0.88;

    final capNode = Node(
      name: 'island_grass_cap',
      mesh: Mesh(
        CylinderGeometry(
          topRadius: 1.55,
          bottomRadius: 1.62,
          height: 0.24,
          radialSegments: 36,
        ),
        grassMat,
      ),
    )..position = vm.Vector3(0, -0.12, 0);

    final sandRing = Node(
      name: 'island_sand_ring',
      mesh: Mesh(
        TorusGeometry(
          radius: 1.56,
          tubeRadius: 0.09,
          radialSegments: 36,
          tubularSegments: 14,
        ),
        sandMat,
      ),
    )..position = vm.Vector3(0, -0.05, 0);

    final cliffCone = Node(
      name: 'island_cliff_cone',
      mesh: Mesh(
        CylinderGeometry(
          topRadius: 1.52,
          bottomRadius: 0.42,
          height: 0.92,
          radialSegments: 28,
        ),
        cliffMat,
      ),
    )..position = vm.Vector3(0, -0.68, 0);

    final seaDisc = Node(
      name: 'island_sea_disc',
      mesh: Mesh(
        DiscGeometry(radius: 9.5, segments: 48),
        _seaMat,
      ),
    )..position = vm.Vector3(0, -0.46, 0);

    // Orbiting holographic energy rings around the pedestal.
    _holoRingOuter = Node(
      name: 'island_holo_ring_outer',
      mesh: Mesh(
        TorusGeometry(
          radius: 1.82,
          tubeRadius: 0.016,
          radialSegments: 48,
          tubularSegments: 12,
        ),
        _islandHoloRingMat,
      ),
    )..position = vm.Vector3(0, 0.02, 0);

    _holoRingInner = Node(
      name: 'island_holo_ring_inner',
      mesh: Mesh(
        TorusGeometry(
          radius: 1.32,
          tubeRadius: 0.012,
          radialSegments: 40,
          tubularSegments: 10,
        ),
        _islandHoloRingMat,
      ),
    )..position = vm.Vector3(0, -0.35, 0);

    islandRoot
      ..add(seaDisc)
      ..add(capNode)
      ..add(sandRing)
      ..add(cliffCone)
      ..add(_holoRingOuter!)
      ..add(_holoRingInner!);

    // 2. Glowing `.fmat` EmberBed shader disc under the campfire.
    try {
      _emberBedMat = await loadFmatMaterial('assets/materials/ember_bed.fmat');
      _emberBedMat!.parameters.setVec4(
        'bed',
        vm.Vector4(0.28, 0.32, 0.36, 1.0),
      );
      final emberDisc = Node(
        name: 'island_ember_bed',
        mesh: Mesh(
          DiscGeometry(radius: 0.36, segments: 28),
          _emberBedMat!,
        ),
      )..position = vm.Vector3(0.28, 0.015, 0.32);
      islandRoot.add(emberDisc);
    } on Object {
      // Fallback if .fmat is unavailable in headless tests.
    }

    // 3. Load precompiled `.glb` / `.fsceneb` 3D props & animated characters.
    await _tryAddGlbProp(
      'assets/models/tree_palm.glb',
      name: 'palm_main',
      position: vm.Vector3(-0.62, 0.0, -0.42),
      scale: 1.18,
      yaw: 0.6,
    );
    await _tryAddGlbProp(
      'assets/models/tree_palm.glb',
      name: 'palm_secondary',
      position: vm.Vector3(0.72, 0.0, -0.48),
      scale: 0.92,
      yaw: -1.8,
    );
    await _tryAddGlbProp(
      'assets/models/tree_pine.glb',
      name: 'pine_back',
      position: vm.Vector3(0.05, 0.0, -0.88),
      scale: 0.95,
      yaw: 0.4,
    );
    await _tryAddGlbProp(
      'assets/models/campfire.glb',
      name: 'campfire_prop',
      position: vm.Vector3(0.28, 0.0, 0.32),
      scale: 0.72,
      yaw: -0.2,
    );
    await _tryAddGlbProp(
      'assets/models/rock_large.glb',
      name: 'rock_prop',
      position: vm.Vector3(-0.88, 0.0, 0.42),
      scale: 0.48,
      yaw: 1.2,
    );
    await _tryAddGlbProp(
      'assets/models/bush.glb',
      name: 'bush_prop',
      position: vm.Vector3(0.86, 0.0, 0.36),
      scale: 0.52,
      yaw: 0.8,
    );

    // Animated 3D character on the island.
    try {
      final charModel = await loadScene('assets/models/character.glb');
      _relightImportedMaterials(charModel);
      final charNode = Node(name: 'stac_character')
        ..position = vm.Vector3(-0.28, 0.0, 0.38)
        ..scale = vm.Vector3.all(0.42)
        ..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), 0.35)
        ..add(charModel);
      islandRoot.add(charNode);

      final idle = charModel.findAnimationByName('idle');
      if (idle != null) {
        _characterIdleClip = charModel.createAnimationClip(idle)
          ..loop = true
          ..weight = 1.0
          ..play();
      }
      final walk = charModel.findAnimationByName('walk');
      if (walk != null) {
        _characterWalkClip = charModel.createAnimationClip(walk)
          ..loop = true
          ..weight = 0.0
          ..play();
      }
      final punch = charModel.findAnimationByName('attack-melee-right');
      if (punch != null) {
        _characterActionClip = charModel.createAnimationClip(punch)
          ..loop = false
          ..weight = 0.0;
      }
      setCharacterAnimMode(_characterAnimMode);
    } on Object {
      // Skip if character asset is unavailable.
    }

    // Orbiting animated 3D seagull above the palm trees.
    try {
      final gullModel = await loadScene('assets/models/seagull.glb');
      _relightImportedMaterials(gullModel);
      final flight = gullModel.findAnimationByName('Fast_Flying');
      if (flight != null) {
        _seagullFlyClip = gullModel.createAnimationClip(flight)
          ..loop = true
          ..playbackTimeScale = 1.05
          ..play();
      }
      final gullInner = Node(name: 'stac_seagull_inner')
        ..scale = vm.Vector3.all(0.18)
        ..position = vm.Vector3(1.05, 1.35, 0.0)
        ..add(gullModel);
      _seagullPivot = Node(name: 'stac_seagull_pivot')..add(gullInner);
      islandRoot.add(_seagullPivot!);
    } on Object {
      // Skip if seagull asset is unavailable.
    }
  }

  Future<void> _tryAddGlbProp(
    String assetPath, {
    required String name,
    required vm.Vector3 position,
    required double scale,
    required double yaw,
  }) async {
    try {
      final model = await loadScene(assetPath);
      _relightImportedMaterials(model);
      final wrapper = Node(name: name)
        ..position = position
        ..scale = vm.Vector3.all(scale)
        ..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), yaw)
        ..add(model);
      islandRoot.add(wrapper);
    } on Object {
      // Ignore missing prop in test environments.
    }
  }

  void _buildHeadphonesShowpiece() {
    final bandMat = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.88, 0.90, 0.94, 1.0)
      ..metallicFactor = 0.88
      ..roughnessFactor = 0.22
      ..clearcoat = 0.45;
    final chromeMat = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.96, 0.97, 0.99, 1.0)
      ..metallicFactor = 0.98
      ..roughnessFactor = 0.06
      ..clearcoat = 0.95;
    final leatherMat = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.06, 0.07, 0.10, 1.0)
      ..metallicFactor = 0.0
      ..roughnessFactor = 0.42
      ..sheenColor = vm.Vector4(0.12, 0.13, 0.16, 1.0)
      ..sheenRoughness = 0.35
      ..clearcoat = 0.25;
    final fabricMat = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(0.04, 0.05, 0.08, 1.0)
      ..metallicFactor = 0.0
      ..roughnessFactor = 0.92;

    final body = Node(
      name: 'nimbus_body',
      localTransform: _pose(vm.Vector3(0, 0.12, 0)),
    )..scale = vm.Vector3.all(1.18);

    body
      ..add(_buildHeadband(bandMat, leatherMat))
      ..add(
        _buildEarCup(
          side: 1,
          cupMat: _headphoneCupMat,
          plateMat: _headphonePlateMat,
          chromeMat: chromeMat,
          leatherMat: leatherMat,
          fabricMat: fabricMat,
        ),
      )
      ..add(
        _buildEarCup(
          side: -1,
          cupMat: _headphoneCupMat,
          plateMat: _headphonePlateMat,
          chromeMat: chromeMat,
          leatherMat: leatherMat,
          fabricMat: fabricMat,
        ),
      );

    headphonesRoot.add(body);
  }

  static const double _bandCenterY = 0.12;
  static const double _bandRadius = 0.71;
  static const double _cupX = 0.62;
  static const double _cupY = -0.42;
  static const double _yokeRadius = 0.345;
  static const double _yokeOffset = 0.09;

  Node _buildHeadband(Material bandMat, Material leatherMat) {
    const overshoot = 0.06;
    final band = _revolve(
      _superellipse(
        center: vm.Vector2(_bandRadius, 0),
        radius: vm.Vector2(0.022, 0.075),
        exponent: 6,
        points: 32,
      ),
      closed: true,
      caps: true,
      start: -math.pi - overshoot,
      sweep: math.pi + 2 * overshoot,
      segments: 64,
    );
    const padInset = 0.45;
    final pad = _revolve(
      _superellipse(
        center: vm.Vector2(0.668, 0),
        radius: vm.Vector2(0.026, 0.06),
        exponent: 3,
        points: 28,
      ),
      closed: true,
      caps: true,
      start: -math.pi + padInset,
      sweep: math.pi - 2 * padInset,
      segments: 48,
    );
    return Node(
      name: 'headband',
      localTransform: _pose(
        vm.Vector3(0, _bandCenterY, 0),
        vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), math.pi / 2),
      ),
    )
      ..add(Node(name: 'band', mesh: Mesh(band, bandMat)))
      ..add(Node(name: 'band_pad', mesh: Mesh(pad, leatherMat)));
  }

  Node _buildEarCup({
    required int side,
    required Material cupMat,
    required Material plateMat,
    required Material chromeMat,
    required Material leatherMat,
    required Material fabricMat,
  }) {
    final group = Node(name: side > 0 ? 'cup_right' : 'cup_left');
    final cup = Node(
      name: 'cup_body_$side',
      localTransform: _pose(
        vm.Vector3(side * _cupX, _cupY, 0),
        vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), -side * math.pi / 2),
      ),
    );
    group.add(cup);

    const shellRadius = 0.30, shellDepth = 0.20, shellExponent = 3.5;
    const plateRadius = 0.236;
    final plateT = math.acos(
      math.pow(plateRadius / shellRadius, shellExponent / 2).toDouble(),
    );
    final plateH =
        shellDepth * math.pow(math.sin(plateT), 2 / shellExponent).toDouble();
    final shell = <vm.Vector2>[
      for (var i = 0; i <= 24; i++)
        _superellipsePoint(
          vm.Vector2.zero(),
          vm.Vector2(shellRadius, shellDepth),
          shellExponent,
          plateT * i / 24,
        ),
    ];
    cup.add(
      Node(
        name: 'shell_$side',
        mesh: Mesh(_revolve(shell, segments: 56), cupMat),
      ),
    );

    final plate = <vm.Vector2>[
      for (var i = 0; i <= 16; i++)
        () {
          final r = plateRadius * (1 - i / 16);
          final f = r / plateRadius;
          return vm.Vector2(r, plateH - 0.002 + 0.014 * (1 - f * f));
        }(),
    ];
    cup
      ..add(
        Node(
          name: 'cap_plate_$side',
          mesh: Mesh(_revolve(plate, segments: 56), plateMat),
        ),
      )
      ..add(
        Node(
          name: 'cap_ring_$side',
          localTransform: _pose(vm.Vector3(0, plateH, 0)),
          mesh: Mesh(
            TorusGeometry(
              radius: 0.238,
              tubeRadius: 0.009,
              radialSegments: 56,
              tubularSegments: 12,
            ),
            chromeMat,
          ),
        ),
      )
      ..add(
        Node(
          name: 'cushion_$side',
          mesh: Mesh(
            _revolve(
              _superellipse(
                center: vm.Vector2(0.215, -0.048),
                radius: vm.Vector2(0.09, 0.052),
                exponent: 3,
                points: 28,
              ),
              closed: true,
              segments: 56,
            ),
            leatherMat,
          ),
        ),
      )
      ..add(
        Node(
          name: 'baffle_$side',
          mesh: Mesh(
            _revolve(
              [vm.Vector2(0, 0.004), vm.Vector2(0.30, 0.004)],
              segments: 36,
            ),
            fabricMat,
          ),
        ),
      );

    final yokeX = side * (_cupX + _yokeOffset);
    final yoke = TubeGeometry(
      PolylinePath([
        for (var i = 0; i <= 36; i++)
          vm.Vector3(
            yokeX,
            _cupY + _yokeRadius * math.sin(math.pi * i / 36),
            _yokeRadius * math.cos(math.pi * i / 36),
          ),
      ]),
      radius: 0.016,
      radialSegments: 16,
      stations: 48,
    );
    group.add(Node(name: 'yoke_$side', mesh: Mesh(yoke, chromeMat)));

    final crownY = _cupY + _yokeRadius;
    final bandEndY = _bandCenterY - _bandRadius * math.sin(0.06);
    group.add(
      Node(
        name: 'hinge_$side',
        localTransform: _pose(
          vm.Vector3(yokeX, crownY + 0.01, 0),
          vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), math.pi / 2),
        ),
        mesh: Mesh(
          CapsuleGeometry(radius: 0.026, height: 0.075, radialSegments: 20),
          cupMat,
        ),
      ),
    );
    for (final z in [0.032, -0.032]) {
      final length = bandEndY + 0.02 - crownY;
      group.add(
        Node(
          name: 'slider_${side}_$z',
          localTransform: _pose(vm.Vector3(yokeX, crownY + length / 2, z)),
          mesh: Mesh(
            CylinderGeometry(
              bottomRadius: 0.011,
              topRadius: 0.011,
              height: length,
              radialSegments: 16,
            ),
            chromeMat,
          ),
        ),
      );
    }
    return group;
  }

  void setModel(Stac3dModelKind kind, {bool triggerScan = true}) {
    if (_activeModel == kind && islandRoot.visible == (kind == Stac3dModelKind.island)) {
      if (triggerScan) {
        scanRig.triggerSweep();
      }
      return;
    }
    _activeModel = kind;
    _syncModelVisibility();
    if (triggerScan) {
      scanRig.triggerSweep();
    }
  }

  void _syncModelVisibility() {
    final isIsland = _activeModel == Stac3dModelKind.island;
    islandRoot.visible = isIsland;
    headphonesRoot.visible = !isIsland;
  }

  /// Updates the 3D PBR materials, rim light, and holographic laser-scan
  /// shader color when the user selects a new colorway edition.
  void applyEditionColor(Color accent, {bool triggerScan = true}) {
    _accentColor = accent;
    final r = (accent.r * 255.0).round().clamp(0, 255) / 255.0;
    final g = (accent.g * 255.0).round().clamp(0, 255) / 255.0;
    final b = (accent.b * 255.0).round().clamp(0, 255) / 255.0;

    // Anodized metallic ear-cup color + subtle emissive sheen.
    _headphoneCupMat
      ..baseColorFactor = vm.Vector4(
        (r * 0.72 + 0.06).clamp(0.0, 1.0),
        (g * 0.72 + 0.06).clamp(0.0, 1.0),
        (b * 0.72 + 0.08).clamp(0.0, 1.0),
        1.0,
      )
      ..emissiveFactor = vm.Vector4(r * 0.14, g * 0.14, b * 0.14, 1.0);

    _headphonePlateMat.baseColorFactor = vm.Vector4(
      (r * 0.45 + 0.52).clamp(0.0, 1.0),
      (g * 0.45 + 0.52).clamp(0.0, 1.0),
      (b * 0.45 + 0.54).clamp(0.0, 1.0),
      1.0,
    );

    _islandHoloRingMat
      ..baseColorFactor = vm.Vector4(r, g, b, 1.0)
      ..emissiveFactor = vm.Vector4(r * 0.65, g * 0.65, b * 0.65, 1.0);

    rimLight.color = vm.Vector3(
      (r * 0.8 + 0.2).clamp(0.0, 1.0),
      (g * 0.8 + 0.2).clamp(0.0, 1.0),
      (b * 0.8 + 0.2).clamp(0.0, 1.0),
    );

    _seaMat.baseColorFactor = vm.Vector4(
      (r * 0.22 + 0.03).clamp(0.0, 1.0),
      (g * 0.28 + 0.14).clamp(0.0, 1.0),
      (b * 0.32 + 0.24).clamp(0.0, 1.0),
      1.0,
    );

    final sky = _skyShader;
    if (sky != null) {
      final isGold = r > 0.7 && g > 0.4;
      final isEmerald = g > 0.55 && r < 0.3;
      if (isGold) {
        // Golden-hour sunset sky with glowing low sun disc.
        sky.parameters
          ..setVec4(
            'sun_direction',
            vm.Vector4(0.22, 0.14, -0.96, 0.038),
          )
          ..setVec4('rayleigh', vm.Vector4(0.42, 0.34, 0.52, 2.2))
          ..setVec4('sky_params', vm.Vector4(11.0, 0.82, 1.15, 0.18));
      } else if (isEmerald) {
        // Tropical emerald lagoon sky.
        sky.parameters
          ..setVec4(
            'sun_direction',
            vm.Vector4(-0.24, 0.34, -0.91, 0.032),
          )
          ..setVec4('rayleigh', vm.Vector4(0.14, 0.48, 0.52, 2.1))
          ..setVec4('sky_params', vm.Vector4(9.0, 0.80, 1.10, 0.08));
      } else {
        // Starry midnight sky with glowing moon and Milky Way.
        sky.parameters
          ..setVec4(
            'sun_direction',
            vm.Vector4(0.0, -0.45, -0.89, 0.028),
          )
          ..setVec4(
            'moon_direction',
            vm.Vector4(-0.22, 0.28, -0.93, 0.042),
          )
          ..setVec4('rayleigh', vm.Vector4(0.18, 0.38, 0.68, 2.0))
          ..setVec4('sky_params', vm.Vector4(10.0, 0.80, 0.95, 0.86));
      }
    }

    scanRig.updateAccentColor(accent);
    if (triggerScan) {
      scanRig.triggerSweep();
      triggerCharacterWave();
    }
  }

  /// Switches the 3D character's continuous skeletal animation mode
  /// (`"idle"`, `"walk"`, or `"punch"`) driven by Stac JSON / Firebase RTDB.
  void setCharacterAnimMode(String rawMode) {
    final normalized = rawMode.trim().toLowerCase();
    _characterAnimMode = switch (normalized) {
      'walk' || 'run' => 'walk',
      'punch' || 'attack' || 'action' => 'punch',
      _ => 'idle',
    };
    if (_characterAnimMode == 'walk') {
      _characterIdleClip?.weight = 0.0;
      _characterActionClip?.weight = 0.0;
      _characterWalkClip
        ?..loop = true
        ..weight = 1.0
        ..play();
    } else if (_characterAnimMode == 'punch') {
      _characterIdleClip?.weight = 0.0;
      _characterWalkClip?.weight = 0.0;
      _characterActionClip
        ?..loop = true
        ..weight = 1.0
        ..play();
    } else {
      _characterWalkClip?.weight = 0.0;
      _characterActionClip
        ?..loop = false
        ..weight = 0.0;
      _characterIdleClip
        ?..loop = true
        ..weight = 1.0
        ..play();
    }
  }

  void triggerCharacterWave() {
    if (_characterAnimMode != 'idle') return;
    final action = _characterActionClip;
    if (action == null) return;
    _actionTimer = 0.45;
    action
      ..loop = false
      ..stop()
      ..weight = 1.0
      ..play();
  }

  /// Advances animations, holographic wireframe scan, campfire flicker, and
  /// turntable rotation.
  void tick(
    double dt, {
    required double yaw,
    required double pitch,
  }) {
    if (!_loaded) return;
    _elapsed += dt;

    // Rotate the 3D turntable smoothly.
    final qYaw = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), yaw);
    final qPitch = vm.Quaternion.axisAngle(
      vm.Vector3(1, 0, 0),
      pitch.clamp(-0.45, 0.45),
    );
    turntableRoot.rotation = qPitch * qYaw;

    // Gentle floating bob for the headphones showpiece.
    if (_activeModel == Stac3dModelKind.headphones) {
      headphonesRoot.position = vm.Vector3(
        0,
        math.sin(_elapsed * 2.1) * 0.045,
        0,
      );
    } else {
      // Animate island campfire flicker, ember bed shader, holo rings & seagull.
      final flicker =
          2.9 +
          math.sin(_elapsed * 11.0) * 0.45 +
          math.cos(_elapsed * 17.3) * 0.25;
      campfirePointLight.intensity = flicker;
      _emberBedMat?.parameters.setFloat('time', _elapsed);

      _holoRingOuter?.rotation = vm.Quaternion.axisAngle(
        vm.Vector3(0.18, 1.0, 0.08)..normalize(),
        _elapsed * 0.85,
      );
      _holoRingInner?.rotation = vm.Quaternion.axisAngle(
        vm.Vector3(-0.15, 1.0, 0.22)..normalize(),
        -_elapsed * 1.25,
      );

      _seagullPivot?.rotation = vm.Quaternion.axisAngle(
        vm.Vector3(0, 1, 0),
        _elapsed * 1.15,
      );
      _seagullFlyClip?.advance(dt);

      if (_characterAnimMode == 'walk') {
        _characterWalkClip?.advance(dt);
      } else if (_characterAnimMode == 'punch') {
        _characterActionClip?.advance(dt);
      } else if (_actionTimer > 0) {
        _actionTimer = math.max(0.0, _actionTimer - dt);
        _characterActionClip?.advance(dt);
        final w = (_actionTimer / 0.45).clamp(0.0, 1.0);
        _characterActionClip?.weight = w;
        _characterIdleClip?.weight = 1.0 - w;
      } else {
        _characterIdleClip?.advance(dt);
      }
    }

    scanRig.tick(dt);
    _skyShader?.parameters.setVec4(
      'extras',
      vm.Vector4(_elapsed, 2.4, 1.25, 1.15),
    );
  }

  Camera buildCamera(ui.Size viewportSize) {
    final isIsland = _activeModel == Stac3dModelKind.island;
    final eye = isIsland
        ? vm.Vector3(0.0, 1.55, 4.15)
        : vm.Vector3(0.0, 0.18, 2.75);
    final target = isIsland
        ? vm.Vector3(0.0, 0.18, 0.0)
        : vm.Vector3(0.0, 0.02, 0.0);
    return PerspectiveCamera(
      position: eye,
      target: target,
      up: vm.Vector3(0, 1, 0),
      fovRadiansY: 42.0 * math.pi / 180.0,
      fovNear: 0.1,
      fovFar: 40.0,
    );
  }

  void _relightImportedMaterials(Node node) {
    final mesh = node.mesh;
    if (mesh != null) {
      for (final primitive in mesh.primitives) {
        final material = primitive.material;
        if (material is PhysicallyBasedMaterial) {
          material.metallicFactor = 0.0;
          material.roughnessFactor = math.max(material.roughnessFactor, 0.75);
        } else if (material is UnlitMaterial) {
          primitive.material = _relitUnlitCache.putIfAbsent(
            material,
            () => PhysicallyBasedMaterial()
              ..baseColorTexture = material.baseColorTexture
              ..baseColorFactor = material.baseColorFactor
              ..metallicFactor = 0.0
              ..roughnessFactor = 0.85,
          );
        }
      }
    }
    for (final child in node.children) {
      _relightImportedMaterials(child);
    }
  }

  void dispose() {
    scanRig.detach();
    scene.dispose();
  }
}

vm.Matrix4 _pose(vm.Vector3 position, [vm.Quaternion? rotation]) =>
    vm.Matrix4.compose(
      position,
      rotation ?? vm.Quaternion.identity(),
      vm.Vector3.all(1),
    );

List<vm.Vector2> _superellipse({
  required vm.Vector2 center,
  required vm.Vector2 radius,
  double exponent = 4,
  int points = 32,
}) => [
  for (var i = 0; i < points; i++)
    _superellipsePoint(center, radius, exponent, 2 * math.pi * i / points),
];

vm.Vector2 _superellipsePoint(
  vm.Vector2 c,
  vm.Vector2 r,
  double n,
  double t,
) {
  double f(double v) => v.sign * math.pow(v.abs(), 2 / n).toDouble();
  return vm.Vector2(c.x + r.x * f(math.cos(t)), c.y + r.y * f(math.sin(t)));
}

MeshGeometry _revolve(
  List<vm.Vector2> profile, {
  double start = 0,
  double sweep = 2 * math.pi,
  int segments = 56,
  bool closed = false,
  bool caps = false,
}) {
  final rows = profile.length;
  final positions = <double>[];
  final normals = <double>[];
  final tangents = <double>[];
  final uvs = <double>[];
  final indices = <int>[];

  vm.Vector2 profileNormal(int i) {
    final prev = closed
        ? profile[(i - 1 + rows) % rows]
        : profile[math.max(i - 1, 0)];
    final next = closed
        ? profile[(i + 1) % rows]
        : profile[math.min(i + 1, rows - 1)];
    final t = (next - prev)..normalize();
    return vm.Vector2(t.y, -t.x);
  }

  final columns = segments + 1;
  for (var i = 0; i < rows; i++) {
    final p = profile[i];
    final n = profileNormal(i);
    for (var j = 0; j < columns; j++) {
      final a = start + sweep * j / segments;
      final c = math.cos(a), s = math.sin(a);
      positions.addAll([p.x * c, p.y, p.x * s]);
      normals.addAll([n.x * c, n.y, n.x * s]);
      tangents.addAll([-s, 0, c, 1]);
      uvs.addAll([j / segments, i / (rows - 1)]);
    }
  }
  final bands = closed ? rows : rows - 1;
  for (var i = 0; i < bands; i++) {
    final i1 = (i + 1) % rows;
    for (var j = 0; j < segments; j++) {
      final a = i * columns + j, b = a + 1;
      final c = i1 * columns + j, d = c + 1;
      indices.addAll([a, c, b, b, c, d]);
    }
  }

  if (caps) {
    final centroid = vm.Vector2.zero();
    for (final p in profile) {
      centroid.add(p);
    }
    centroid.scale(1 / rows);
    for (final end in [0, 1]) {
      final a = start + sweep * end;
      final c = math.cos(a), s = math.sin(a);
      final facing = vm.Vector3(-s, 0, c)..scale(end == 0 ? -1.0 : 1.0);
      vm.Vector3 at(vm.Vector2 p) => vm.Vector3(p.x * c, p.y, p.x * s);
      final base = positions.length ~/ 3;
      for (final p in [centroid, ...profile]) {
        final v = at(p);
        positions.addAll([v.x, v.y, v.z]);
        normals.addAll([facing.x, facing.y, facing.z]);
        tangents.addAll([c, 0, s, 1]);
        uvs.addAll([0.5, 0.5]);
      }
      for (var k = 0; k < rows; k++) {
        final p0 = at(profile[k]), p1 = at(profile[(k + 1) % rows]);
        final winding = (p0 - at(centroid))
            .cross(p1 - at(centroid))
            .dot(facing);
        final v0 = base + 1 + k, v1 = base + 1 + (k + 1) % rows;
        indices.addAll(winding >= 0 ? [base, v0, v1] : [base, v1, v0]);
      }
    }
  }

  return MeshGeometry.fromArrays(
    positions: Float32List.fromList(positions),
    normals: Float32List.fromList(normals),
    tangents: Float32List.fromList(tangents),
    texCoords: Float32List.fromList(uvs),
    indices: indices,
  );
}
