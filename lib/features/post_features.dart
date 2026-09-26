import '../hotel/feature.dart';
import '../hotel/hotel_context.dart';
import '../hotel/look.dart';

/// A post effect that is one LookState flag: on while mounted, off after.
/// composeLook() rebuilds the whole EnvironmentSettings, so the sky survives
/// every toggle (engine rule 1).
abstract class LookFlagFeature extends HotelFeature {
  /// Writes this feature's flag.
  void setFlag(LookState look, bool on);

  @override
  Future<void> mount(HotelContext ctx) async {
    setFlag(ctx.look, true);
    ctx.applyLook();
  }

  @override
  void unmount(HotelContext ctx) {
    setFlag(ctx.look, false);
    ctx.applyLook();
  }
}

class ToneMappingFeature extends LookFlagFeature {
  @override
  String get id => 'tone_mapping';
  @override
  String get label => 'ACES tone mapping';
  @override
  CostTier get tier => CostTier.free;
  @override
  void setFlag(LookState look, bool on) => look.toneMapping = on;
}

class FogFeature extends LookFlagFeature {
  @override
  String get id => 'fog';
  @override
  String get label => 'Atmospheric fog';
  @override
  CostTier get tier => CostTier.cheap;
  @override
  void setFlag(LookState look, bool on) => look.fog = on;
}

class BloomFeature extends LookFlagFeature {
  @override
  String get id => 'bloom';
  @override
  String get label => 'Bloom + lens flare';
  @override
  CostTier get tier => CostTier.expensive;
  @override
  bool get defaultOn => false;
  @override
  void setFlag(LookState look, bool on) => look.bloom = on;
}

class AoFeature extends LookFlagFeature {
  @override
  String get id => 'ao';
  @override
  String get label => 'GTAO ambient occlusion';
  @override
  CostTier get tier => CostTier.expensive;
  @override
  bool get defaultOn => false;
  @override
  void setFlag(LookState look, bool on) => look.ao = on;
}

class GodRaysFeature extends LookFlagFeature {
  @override
  String get id => 'god_rays';
  @override
  String get label => 'God rays';
  @override
  CostTier get tier => CostTier.expensive;
  @override
  bool get defaultOn => false;
  @override
  void setFlag(LookState look, bool on) => look.godRays = on;
}

class SsrFeature extends LookFlagFeature {
  @override
  String get id => 'ssr';
  @override
  String get label => 'Screen-space reflections';
  @override
  CostTier get tier => CostTier.expensive;
  @override
  bool get defaultOn => false;
  @override
  void setFlag(LookState look, bool on) => look.ssr = on;
}
