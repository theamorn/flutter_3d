import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import '../features/entrance_feature.dart';
import '../features/interactions_feature.dart';
import '../features/player_feature.dart';
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
            child: SceneView(
              hotel.scene,
              camera: hotel.ctx.camera,
              onTick: (_, dt) => hotel.tick(dt),
            ),
          ),
          // Feature overlays (joystick, look pad, crosshair, screens, Book now).
          PlayerFeature.overlay(hotel.ctx),
          InteractionsFeature.overlay(hotel.ctx),
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
              child: const Text('🎛 Effects'),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Row(children: [
              const Text('🕑', style: TextStyle(fontSize: 20)),
              Expanded(
                child: ValueListenableBuilder<double>(
                  valueListenable: hotel.ctx.timeOfDay,
                  builder: (_, t, _) => Slider(
                      min: 0,
                      max: 24,
                      value: t,
                      label: '${t.floor()}:00',
                      onChanged: (v) => hotel.ctx.timeOfDay.value = v),
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: hotel.ctx.rainRequested,
                builder: (_, on, _) => IconButton(
                    icon: Text(on ? '🌧' : '☀️',
                        style: const TextStyle(fontSize: 22)),
                    onPressed: () => hotel.ctx.rainRequested.value = !on),
              ),
            ]),
          ),
          if (snap.connectionState != ConnectionState.done)
            const Center(child: CircularProgressIndicator()),
        ]),
      ),
    );
  }
}
