# flutter_scene 0.24 follow-up: scene effects design

Status: draft for user review. Planning only.
Date: 2026-10-06.
Depends on the controls design and its completed implementation.
Spec chain: 2026-10-06-flutter-scene-0.24-controls-design.md.

## Intent

Adopt the requested shader hooks, additive/coverage materials, explicit ordering,
draw selectors, shadow masks, screen distortion and public custom-reflection API
in useful existing scenes. These are scene enhancements enabled by default in
the named modes. Previous renderer/material choices remain comparison controls.

Apply all controls-spec constraints: pinned package/SDK, no new dependencies,
GPU-free logic tests, shader precision, honest fps and hardware performance evidence.
Diagnostic views stay user-triggered. New Effects labels describe visual behavior.

## Material lighting hooks

Two scoped targets make all requested hook capabilities useful:
- Hotel Ultra bedding: cloth_hooks.fmat replaces decorative jacquard-pillow/wool-throw shading using the
  existing base-colour and normal textures. Light provides a mild wrapped diffuse
  response, Ambient retains and scales engine IBL, Composite sums the lobes and
  premultiplies alpha exactly once. Lower presets retain existing materials.
- Island Super Ultra firepit stones: campfire_stone.fmat uses environment_lighting:
  false and supplies a small sky/ground gradient through uniforms in Composite.
  Light still handles actual sun/moon/campfire illumination. This scopes the custom
  indirect model to a small rough object rather than replacing the whole sky/GI.

Use the engine signatures:
LightTerms Light(MaterialInputs material, LightContext light);
void Ambient(MaterialInputs material, inout AmbientContext ambient);
highp vec4 Composite(MaterialInputs material, LightingResult result).

LightContext.radiance already includes attenuation and shadow; do not apply either
again. Custom cloth wrap is 0.2, specular contribution capped through roughness
rather than an unbounded gain. Stone indirect comes from the current sky and ambient
schedule, not a fixed self-lit white floor. Standard bedding and engine-indirect
stone options remain visible comparisons. Preserve imported materials and restore
them by swapping the mounted mesh, not assigning primitive.material in place.

The hotel bed is one mesh with primitives grouped by Finish, not named pillow nodes.
Add BeddingMaterialRole {none, jacquardPillow, woolThrow} to Finish metadata in
placeholder_rooms.dart; tag only _pillowJacquard and _throwWool. The room builder
publishes BeddingMaterialTargets with the bed node, primitive indices and original
materials/textures through HotelContext. Cloth bindings clone/swap only the tagged
primitives, preserving sleeping linen and unrelated bed finishes. Bind the firepit
material only to the imported campfire_stones node/material stone under each placed
campfire parent; other imported materials retain their authored shading.

## Additive glow, alpha coverage, ordering

Replace the island fire's additive core sprite with a camera-facing additive_glow.fmat
card using blending additive, depth_write false and a procedural radial falloff.
Match the current core glow's overall HDR energy first; avoid an extra duplicate glow.
It is default-on with Super Ultra fire VFX, and turns off with the fire.

Add grass_coverage.fmat as the default Super Ultra grass material. Keep current blade
geometry, world animation and instancing. Add a small edge/tip coverage ramp in the
existing UV domain; alpha_to_coverage true, blending opaque. MSAA uses sample
coverage; other backends/modes use the package dither fallback. Preserve grass.fmat
as the comparison. Do not promise lower triangle count from this material change.

Use Node.renderOrder only on the local glow/haze/smoke stack: core -20, haze -10,
smoke 0. The 0.24 encoder compares these values in ascending order within a pass;
they cannot reorder draws across different passes. The intended order puts glow
before the haze's scene-colour capture so haze can refract it; smoke
must occlude background content rather than being forcibly composited over everything.
A runtime capture proves the resolved order. Save/restore authored ordering on reset.
One explicit order setting cannot fix arbitrary intersecting transparent geometry.

## Draw selectors and shadow channels

Super Ultra grass instances receive a deterministic spatially distributed prefix
ordering, then an InstancedMesh.drawSelector:
use the GPU-free project enum QualityLevel {low, medium, high}, mapped from the
engine's effective tier by the adapter;
high tier draws all, medium 75%, low 50% (round up; never exceed available instances).
Colour and depth passes choose the same prefix. Returning the full range remains the
comparison. Do not sort individual instances by camera distance each frame.
The selector receives MeshDrawContext, including pass, cameraPosition and primaryView,
and returns MeshDrawSelection(instanceCount: ...). It must not retain the reused context.
Generated grass is currently shadowCastingMode.off; preserve that unless separately
reviewed, so the plan makes no claim of grass shadow-pass savings.

Hotel lamp-fixture self-shadow exclusion uses an isolated node light-channel bit
0x02 and per-light shadowCasterChannelMask 0xFD; ordinary scene nodes use bit 0x01.
Lighting channelMask remains 0xFF so receivers continue to be lit. Apply masks to the
actual eligible fixture descendants; node masks are not inherited. Keep structural
walls, doorframes, pillows and externally visible occluders in the shadow maps.
A UI comparison temporarily restores 0xFF casting masks. Default exclusion applies
to verified source-enclosing fixture pieces only; scene inspection records the exact
parts. The camera-room spot selection and atlas-overflow telemetry remain active.

## Lightning screen distortion

Add a bounded shared ShockwavePool for hotel lightning and island storms.
One pulse per new strike, not one per brightness oscillation. Default duration 0.65 s,
radius 0 to 0.6 screen units, thickness 0.06, peak strength 0.008 fading to zero,
chromaticAberration 0.15, capacity 4. The oldest pulse is reused at capacity.
A strike already under way finishes normally; disabling shockwaves clears the pool.

StrikeId contains scheduler generation and strike number. Advance generation when
a scheduler is replaced; strike number increments within that generation. Store
only the last accepted (generation, number) watermark, not an ever-growing consumed
ID set; reject older/duplicate IDs. Clearing the pool resets this watermark.
ShockwaveSample contains centerX/Y, radius,
thickness, strength and chromaticAberration. For normalized age t, radius=0.6*t
and strength=0.008*(1-t)^2; expired samples are removed.

Pulse center comes from the actual strike position projected through the active
camera and current logical viewport. Drop behind-camera or outside-view strikes;
do not clamp those to a screen edge. Existing flash cadence and brightness remain.
Projection is called at an actual new-strike event; counters alone must not retrigger
a pulse on remount. Add an explicit strike callback to each scheduler's interface,
then drive the shared pool with the scene tick.

Shockwaves are default-on with hotel High/Ultra lightning and island Super Ultra
storm. Turning rain/storm off, leaving the quality mode or hiding the scene clears
screenDistortion.pulses and disables the pass. An Events preview button triggers
a single test pulse for visual verification without waiting for randomness.

## Custom bathroom reflections

Add a CustomMirrorFeature alongside the existing MirrorFeature. Both share exclusive
group bathroom_reflection; Hotel Ultra selects mirror_custom by default. Built-in
mirror is the comparison and the sea's existing PlanarReflectorComponent remains.

Each active bathroom mirror owns one RenderTexture(linearColor: true), a RenderView
in Scene.views, and a mirror_capture.fmat sampling that target with a capture VP matrix.
Use public PlanarReflectionCamera(source: active camera, plane: transformed mirror
plane, clipBias: 0.001). Derive plane normal through the inverse transpose for room B.
Start with 512 x 512; resize to maintain the mirror viewport aspect with a maximum
dimension 512, minimum 64. Bind camera and sampled-texture/matrix together per completed
capture; never cache the first GPU texture from the target ring.

mirror_capture.fmat is unlit and tone-mapped once in the screen view; target content
is linear HDR. It declares its own sampler/matrix rather than pretending to receive
a built-in planar_reflection binding. Until a capture is ready it uses the saved
base material appearance. Exclude custom mirror receivers from their own/all custom
captures using a dedicated render layer bit 1<<5.

Default refresh is every rendered scene frame while the mirror is front-facing and
visible. Remove dormant views from Scene.views; disabling/remounting disposes the
old target/listener and restores original mesh/layers before reattaching.
Use Scene.views for offscreen targets; preserve the hotel's existing SceneView
camera/input route and interactive WidgetComponents.

The current hotel occlusion feature must include active custom-reflection cameras
in its visibility union. Add those cameras to HotelContext, remove them when dormant,
and test this ownership model. A reflected object behind the screen camera must
remain available to the capture. No unbounded recursion or hidden second capture.

## Acceptance

- Bedding and firepit shading look correct by day/night, respond to real lights,
  and retain shadows without multiplying shadow attenuation twice.
- Grass card coverage works under MSAA and the non-MSAA fallback; no flickering/hard tip squares.
- New glow respects occlusion and ordered captures; no glow doubles or white flood.
- Grass selector colour/depth prefixes match, with no clumps from nondistributed ordering.
- Shadow masks remove eligible self-occluders while floor/wall/pillow shadows remain.
- One strike produces one short pulse; turning modes off removes the distortion pass.
- Custom mirrors reflect both mirrored rooms with correct handedness and a single tone curve.
- Hide/show, resize, rapid backend switching and room remount restore resources and input.
- Performance is recorded from the same view/quality at paired hardware profile runs.
