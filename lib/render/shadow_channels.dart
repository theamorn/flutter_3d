/// Light channels that keep a light's own fixture out of its shadow map.
///
/// flutter_scene 0.24 gives every node an 8-bit `lightChannelMask` and every
/// light two masks: `channelMask` (which nodes it lights) and
/// `shadowCasterChannelMask` (which nodes draw into its shadow map). A lamp
/// shade wrapped around its own bulb would otherwise throw the room into its
/// shadow. So the source-enclosing fixture parts sit alone on
/// [kFixtureSelfShadowChannel], the fixture lights cast with
/// [kFixtureExcludedCasterMask] (every channel but that one), and lighting
/// stays on [kDirectLightMask], so the shades are still lit.
///
/// Ordinary nodes keep the engine default (every channel, which includes
/// [kOrdinaryLightChannel]): walls, door frames, pillows and everything else
/// still cast. Non-default masks have a cost: instanced draws only batch
/// with equal masks, and light culling tests the mask per item, so only the
/// few fixture parts change.
library;

import 'package:vector_math/vector_math.dart';

import '../features/lamps_feature.dart' show kBathLightSourceAt, kLampLightSourceAt;
import '../features/placeholder_rooms.dart' show RoomNode;
import '../features/spot_lights_feature.dart' show kReadingLightSourceAt;

const int kOrdinaryLightChannel = 0x01;
const int kFixtureSelfShadowChannel = 0x02;

/// What a node takes when nobody sets it (`Node.lightChannelMask`).
const int kDefaultLightChannelMask = 0xFF;

/// A fixture light's shadow casters: everything but the fixture parts.
const int kFixtureExcludedCasterMask = 0xFD;

/// The comparison: the fixture parts cast again.
const int kIncludeFixtureCasterMask = 0xFF;

/// Every light keeps lighting every channel.
const int kDirectLightMask = 0xFF;

/// Whether a node on [nodeMask] draws into the shadow map of a light whose
/// shadow casters are [casterMask].
bool castsShadowFor(int nodeMask, int casterMask) => nodeMask & casterMask != 0;

/// Whether a light on [lightMask] lights a node on [nodeMask].
bool litBy(int nodeMask, int lightMask) => nodeMask & lightMask != 0;

/// Where each light-bearing fixture's light sits, in the fixture's frame (the
/// lamps and spot-lights features put their lights there).
final Map<String, Vector3> kFixtureLightSources = {
  'lamp_bedside': kLampLightSourceAt,
  'lamp_floor': kLampLightSourceAt,
  'reading_light_left': kReadingLightSourceAt,
  'reading_light_right': kReadingLightSourceAt,
  'bath_light': kBathLightSourceAt,
};

/// The fixture parts (paths under the room root) that wrap their fixture's
/// light: the bedside lamp's shade, and each reading light's shade, whose
/// rim sits a centimetre above the bulb. The floor lamp's shade is metres
/// from its light and the bath light's disc 10 cm above it: neither encloses.
const Set<String> kSourceEnclosingParts = {
  'lamp_bedside/lamp_shade',
  'reading_light_left/reading_light_shade',
  'reading_light_right/reading_light_shade',
};

/// Whether [part]'s geometry wraps a light at [source] (in the frame of the
/// part's parent fixture): the source lies inside the bounds of the part's
/// parts, grown by [margin] metres.
bool encloses(RoomNode part, Vector3 source, {double margin = 0.02}) {
  final local = Matrix4.inverted(part.localTransform).transformed3(source);
  for (final p in part.parts) {
    final b = p.bounds;
    final grown = Aabb3.minMax(
      b.min - Vector3.all(margin),
      b.max + Vector3.all(margin),
    );
    if (grown.containsVector3(local)) return true;
  }
  return false;
}
