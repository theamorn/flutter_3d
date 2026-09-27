import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart';
import 'placeholder_rooms.dart';

/// The photo textures the rooms' finishes name, each loaded once and shared
/// by both rooms (room B is built from the same finishes).
class RoomTextures {
  RoomTextures._(this._color, this._normal);

  final Map<String, Texture2D> _color, _normal;

  Texture2D? color(TextureRef t) => _color[t.id];
  Texture2D? normal(TextureRef t) => _normal[t.id];

  /// Loads every distinct texture in [refs]. One that fails to load is
  /// logged and left out: its parts fall back to their plain colour rather
  /// than taking the whole room down.
  static Future<RoomTextures> load(Iterable<TextureRef> refs) async {
    final color = <String, Texture2D>{}, normal = <String, Texture2D>{};
    Future<void> into(Map<String, Texture2D> out, String id, String asset,
        TextureContent content) async {
      try {
        out[id] = await Texture2D.fromAsset(asset, content: content);
      } catch (e) {
        debugPrint('room texture $asset failed to load: $e');
      }
    }

    final unique = {for (final r in refs) r.id: r}.values;
    await Future.wait([
      for (final r in unique) ...[
        into(color, r.id, r.colorAsset, TextureContent.color),
        if (r.hasNormal) into(normal, r.id, r.normalAsset, TextureContent.normal),
      ],
    ]);
    return RoomTextures._(color, normal);
  }
}
