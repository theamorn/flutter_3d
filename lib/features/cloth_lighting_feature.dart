import 'dart:async';

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import '../render/material_binding_policy.dart';
import '../render/prewarm.dart';
import 'placeholder_rooms.dart';

/// The bedding comparison: the room builder's physical fabric material
/// (sheen layer), or `cloth_hooks.fmat` lighting the same textures through
/// the 0.24 material hooks. Hooks in Ultra; the switch is this feature.
enum ClothLightingMode {
  standard,
  hooks;

  static const ClothLightingMode initial = ClothLightingMode.hooks;
}

const String kClothHooksFmat = 'assets/materials/cloth_hooks.fmat';

/// Relights the bed's decorative jacquard pillows and wool throw in both
/// rooms with [kClothHooksFmat] (wrapped diffuse, broad highlight, a soft
/// pile rim). Only the tagged primitives change: the bed node gets a new
/// [Mesh] over the same geometry, and its authored mesh (with every
/// original material) goes back on when the feature turns off or the rooms
/// remount.
class ClothLightingFeature extends HotelFeature {
  @override
  String get id => 'cloth_lighting';
  @override
  String get label => 'Bedding cloth lighting (material hooks)';
  @override
  CostTier get tier => CostTier.cheap;
  @override
  bool get defaultOn => false;

  ClothLightingMode get mode =>
      _policy.bound.isEmpty ? ClothLightingMode.standard : ClothLightingMode.hooks;

  /// One material per bedding role (its own colour and textures), shared by
  /// both rooms. Loaded once and kept across toggles.
  final Map<BeddingMaterialRole, PreprocessedMaterial> _materials = {};
  final MaterialBindingPolicy<Node, Mesh> _policy = MaterialBindingPolicy();

  /// The target list last reconciled; the rooms feature replaces the list on
  /// every mount, so identity tells a remount.
  List<BeddingMaterialTarget>? _seen;

  @override
  Future<void> mount(HotelContext ctx) async {
    for (final role in [BeddingMaterialRole.jacquardPillow, BeddingMaterialRole.woolThrow]) {
      _materials[role] ??= await loadFmatMaterial(kClothHooksFmat);
    }
    _seen = null;
    _sync(ctx);
  }

  @override
  void tick(HotelContext ctx, double dt) => _sync(ctx);

  void _sync(HotelContext ctx) {
    final targets = ctx.beddingTargets;
    if (identical(targets, _seen)) return;
    _seen = targets;
    final byNode = {for (final t in targets) t.node: t};
    final changes = _policy.reconcile(byNode.keys);
    for (final (node, own) in changes.release) {
      if (!identical(node.mesh, own)) node.mesh = own;
    }
    for (final node in changes.bind) {
      final own = node.mesh;
      if (own == null) continue;
      node.mesh = _dress(own, byNode[node]!);
      _policy.bind(node, own);
    }
    // The bed is often out of view when this switches on; compile its new
    // pipeline now rather than on the frame it first turns up.
    if (changes.bind.isNotEmpty) unawaited(prewarmPipelines(ctx.scene, ctx.camera));
  }

  /// [own] with each bedding slot's material swapped for its cloth material.
  Mesh _dress(Mesh own, BeddingMaterialTarget target) {
    final bySlot = <int, Material>{};
    for (var k = 0; k < target.slots.length; k++) {
      final slot = target.slots[k];
      final material = _materials[slot.role];
      if (material == null) continue;
      _style(material, slot.finish, target.colorTextures[k], target.normalTextures[k]);
      bySlot[slot.primitive] = material;
    }
    final primitives = own.primitives;
    return Mesh.primitives(primitives: [
      for (var i = 0; i < primitives.length; i++)
        // Same geometry, so the engine keeps the render items and only
        // swaps the material.
        MeshPrimitive(primitives[i].geometry, bySlot[i] ?? primitives[i].material)
          ..visible = primitives[i].visible
          ..castsShadow = primitives[i].castsShadow,
    ]);
  }

  /// The [finish]'s colour, roughness and pile strength, and its photo
  /// textures with their own samplers (the texture source owns them).
  static void _style(PreprocessedMaterial material, Finish finish,
      TextureSource? color, TextureSource? normal) {
    final p = material.parameters
      ..setVec4('base_color_factor', Vector4(finish.r, finish.g, finish.b, finish.alpha))
      ..setVec4('cloth', Vector4(finish.roughness, normal == null ? 0 : 1, 0.5, 0.5 * finish.layer))
      ..setVec4('ambient_scale', Vector4(1.0, 0.35, 0, 0));
    final colorTexture = color?.sampledTexture;
    if (colorTexture != null) {
      p.setTexture('base_color_texture', colorTexture, sampler: color!.sampledSampler);
    }
    final normalTexture = normal?.sampledTexture;
    if (normalTexture != null) {
      p.setTexture('normal_texture', normalTexture, sampler: normal!.sampledSampler);
    }
  }

  @override
  void unmount(HotelContext ctx) {
    for (final (node, own) in _policy.releaseAll()) {
      if (!identical(node.mesh, own)) node.mesh = own;
    }
    _seen = null;
  }
}
