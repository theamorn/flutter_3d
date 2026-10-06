import 'package:flutter_scene/scene.dart';

/// Compiles the pipelines of everything attached to [scene], on screen or
/// not, as seen through [camera]: call it after swapping in a new material
/// so its first visible frame does not stall on a shader compile. Encodes
/// tiny offscreen frames, at most [sliceBudget] of new pipeline builds each,
/// so the page keeps answering input meanwhile.
Future<void> prewarmPipelines(
  Scene scene,
  Camera camera, {
  Duration sliceBudget = const Duration(milliseconds: 6),
}) =>
    scene.warmUp(
      [RenderView(camera: camera)],
      includeOffscreen: true,
      sliceBudget: sliceBudget,
    );
