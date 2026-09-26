import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/features/post_features.dart';
import 'package:flutter_3d/hotel/feature.dart';
import 'package:flutter_3d/hotel/look.dart';

typedef Flags = ({bool tone, bool fog, bool bloom, bool ao, bool godRays, bool ssr});

Flags flags(LookState s) => (
      tone: s.toneMapping,
      fog: s.fog,
      bloom: s.bloom,
      ao: s.ao,
      godRays: s.godRays,
      ssr: s.ssr,
    );

LookState allOff() => LookState()
  ..toneMapping = false
  ..fog = false
  ..bloom = false
  ..ao = false
  ..godRays = false
  ..ssr = false;

void main() {
  // feature, its catalog row (id, tier, default on), and the one flag it owns.
  final rows = <(LookFlagFeature, String, CostTier, bool, bool Function(LookState))>[
    (ToneMappingFeature(), 'tone_mapping', CostTier.free, true, (s) => s.toneMapping),
    (FogFeature(), 'fog', CostTier.cheap, true, (s) => s.fog),
    (BloomFeature(), 'bloom', CostTier.expensive, false, (s) => s.bloom),
    (AoFeature(), 'ao', CostTier.expensive, false, (s) => s.ao),
    (GodRaysFeature(), 'god_rays', CostTier.expensive, false, (s) => s.godRays),
    (SsrFeature(), 'ssr', CostTier.expensive, false, (s) => s.ssr),
  ];

  for (final (f, id, tier, defaultOn, flag) in rows) {
    test('$id: catalog row and toggleable', () {
      expect(f.id, id);
      expect(f.tier, tier);
      expect(f.defaultOn, defaultOn);
      expect(f.toggleable, true);
    });

    test('$id switches its own look flag, and only that one', () {
      final s = allOff();
      f.setFlag(s, true);
      expect(flag(s), true);
      final expectOthersOff = allOff();
      f.setFlag(expectOthersOff, true);
      final onlyThis = flags(expectOthersOff);
      // Exactly one flag differs from all-off.
      final diff = [
        onlyThis.tone, onlyThis.fog, onlyThis.bloom, onlyThis.ao, onlyThis.godRays, onlyThis.ssr
      ].where((b) => b).length;
      expect(diff, 1);
      f.setFlag(s, false);
      expect(flags(s), flags(allOff()));
    });
  }
}
