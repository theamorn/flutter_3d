import 'feature.dart';
import '../features/rooms_feature.dart';
import '../features/player_feature.dart';
import '../features/interactions_feature.dart';
import '../features/sky_feature.dart';
import '../features/ocean_feature.dart';
import '../features/post_features.dart';
import '../features/render_features.dart';
import '../features/lamps_feature.dart';
import '../features/bath_shadow_feature.dart';
import '../features/door_feature.dart';
import '../features/curtains_feature.dart';
import '../features/water_fx_feature.dart';
import '../features/rain_feature.dart';
import '../features/rain_glass_feature.dart';
import '../features/lightning_feature.dart';
import '../features/reflection_features.dart';
import '../features/screens_feature.dart';
import '../features/books_feature.dart';
import '../features/instancing_feature.dart';
import '../features/entrance_feature.dart';
import '../features/light_probes_feature.dart';
import '../features/dynamic_gi_feature.dart';
import '../features/auto_exposure_feature.dart';
import '../features/static_shadows_feature.dart';
import '../features/spot_lights_feature.dart';
import '../features/area_lights_feature.dart';
import '../features/volumetric_fog_feature.dart';
import '../features/occlusion_feature.dart';

/// Mount order matters: rooms first (others look nodes up by name), and
/// occlusion last (it ticks after everything that moves the camera or a
/// node).
List<HotelFeature> buildCatalog() => [
      RoomsFeature(), PlayerFeature(), InteractionsFeature(),
      SkyFeature(), OceanFeature(),
      ToneMappingFeature(), FogFeature(), BloomFeature(), AoFeature(),
      GodRaysFeature(), SsrFeature(),
      ShadowsFeature(), MsaaFeature(),
      LampsFeature(), BathShadowFeature(), DoorFeature(), PortalCullingFeature(), CurtainsFeature(),
      WaterFxFeature(), RainFeature(), RainGlassFeature(), LightningFeature(),
      MirrorFeature(), SeaReflectionFeature(),
      ScreensFeature(), BooksFeature(), InstancingFeature(), EntranceFeature(),
      LightProbesFeature(), DynamicGiFeature(), AutoExposureFeature(), StaticShadowsFeature(),
      FxaaFeature(), SmaaFeature(), TaaFeature(),
      RenderScale85Feature(), RenderScale75Feature(), GpuPacing2Feature(),
      SpotLightsFeature(), AreaLightsFeature(), VolumetricFogFeature(),
      OcclusionFeature(),
    ];
