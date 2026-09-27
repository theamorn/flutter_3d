import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import '../features/entrance_feature.dart';
import '../features/interactions_feature.dart';
import '../features/player_feature.dart';
import '../features/rain_feature.dart';
import '../features/screens_feature.dart';
import '../hotel/hotel_scene.dart';
import 'effects_sheet.dart';
import 'hud.dart';

class HotelPage extends StatefulWidget {
  const HotelPage({super.key});
  @override
  State<HotelPage> createState() => _HotelPageState();
}

class _HotelPageState extends State<HotelPage> {
  final hotel = HotelScene();
  late final Future<void> _ready = hotel.start();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder(
        future: _ready,
        // expand: the overlay stubs are zero-sized, and a Stack sized by its
        // non-positioned children would collapse to 0x0 and hide everything.
        builder: (context, snap) => Stack(fit: StackFit.expand, children: [
          Positioned.fill(
            child: TickerMode(
              enabled: ModalRoute.of(context)?.isCurrent ?? true,
              child: RepaintBoundary(
                key: EntranceFeature.scenePreviewKey,
                child: SceneView(
                  hotel.scene,
                  camera: hotel.ctx.camera,
                  onTick: (_, dt) => hotel.tick(dt),
                ),
              ),
            ),
          ),
          // Feature overlays. Interactions (full-screen tap layer, crosshair)
          // sits BELOW the player's joystick and look pad (Task 11).
          InteractionsFeature.overlay(hotel.ctx),
          PlayerFeature.overlay(hotel.ctx),
          ScreensFeature.overlay(hotel.ctx),
          EntranceFeature.overlay(hotel.ctx),
          Positioned(top: 48, left: 12, child: Hud(scene: hotel.scene)),
          Positioned(
            top: 48,
            right: 12,
            child: FilledButton.tonal(
              onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => EffectsSheet(registry: hotel.registry)),
              child: const Text('Effects'),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                ValueListenableBuilder<double>(
                  valueListenable: hotel.ctx.timeOfDay,
                  builder: (_, t, _) => Text(
                    'Time: ${t.floor().toString().padLeft(2, '0')}:00',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ValueListenableBuilder<double>(
                    valueListenable: hotel.ctx.timeOfDay,
                    builder: (_, t, _) => Slider(
                      min: 0,
                      max: 24,
                      value: t,
                      label: '${t.floor()}:00',
                      onChanged: (v) => hotel.ctx.timeOfDay.value = v,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<bool>(
                  valueListenable: hotel.ctx.rainRequested,
                  builder: (_, on, _) => FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => requestRain(hotel.registry, hotel.ctx.rainRequested, !on),
                    child: Text(
                      on ? 'Rain: ON' : 'Rain: OFF',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          if (snap.connectionState != ConnectionState.done)
            const Center(child: CircularProgressIndicator()),
        ]),
      ),
    );
  }
}
