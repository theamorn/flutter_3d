import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:stac/stac.dart';

import '../home/home_page.dart' show BackdropBuilder, shaderBackdrop;
import 'firebase_stac_client.dart';
import 'stac_gpu_parsers.dart';
import 'stac_host_bridge.dart';

/// Live Server-Driven UI card powered by `stac` + Firebase Realtime Database.
///
/// Streams the JSON layout from Firebase RTDB in real time (`Accept: text/event-stream`).
/// When you edit the JSON in Firebase Console and click Save, this card updates
/// immediately on both iOS and Android, and any interaction with the 3D or Shader
/// widget inside Stac updates [StacHostBridge.instance].
class StacLiveSection extends StatefulWidget {
  const StacLiveSection({
    super.key,
    this.firebaseUrl = kDefaultFirebaseRtdbUrl,
    this.backdrop = shaderBackdrop,
  });

  final String firebaseUrl;
  final BackdropBuilder backdrop;

  @override
  State<StacLiveSection> createState() => _StacLiveSectionState();
}

class _StacLiveSectionState extends State<StacLiveSection> {
  late String _url = widget.firebaseUrl;
  late FirebaseStacClient _client = FirebaseStacClient(url: _url);
  StreamSubscription<Map<String, dynamic>>? _sub;
  Map<String, dynamic> _currentJson = kDefaultStac3dCardJson;

  @override
  void initState() {
    super.initState();
    ensureStacInitialized(backdropBuilder: widget.backdrop);
    _subscribe();
  }

  bool get _isHeadlessTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  void _subscribe() {
    _sub?.cancel();
    _client = FirebaseStacClient(url: _url);
    _sub = _client
        .watchJson(enablePeriodicSync: !_isHeadlessTest)
        .listen((nextJson) {
          if (!mounted) return;
          setState(() {
            _currentJson = nextJson;
          });
        });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _openFirebaseConfigSheet() async {
    final urlController = TextEditingController(text: _url);
    final jsonController = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(_currentJson),
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Firebase RTDB + Stac JSON',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'Firebase Realtime Database .json URL',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      jsonController.text = const JsonEncoder.withIndent(
                        '  ',
                      ).convert(kDefaultStac3dCardJson);
                    },
                    child: const Text('Load 3D Island JSON'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      jsonController.text = const JsonEncoder.withIndent(
                        '  ',
                      ).convert(kDefaultStacHeadphonesCardJson);
                    },
                    child: const Text('Load 3D Headphones JSON'),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      jsonController.text = const JsonEncoder.withIndent(
                        '  ',
                      ).convert(kDefaultStacShaderCardJson);
                    },
                    child: const Text('Load Water Shader JSON'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: jsonController,
                maxLines: 8,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(
                  labelText: 'Stac JSON Payload',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  final nextUrl = urlController.text.trim();
                  Map<String, dynamic>? parsed;
                  try {
                    final decoded = jsonDecode(jsonController.text);
                    if (decoded is Map<String, dynamic>) {
                      parsed = decoded;
                    }
                  } catch (_) {}

                  if (nextUrl.isNotEmpty && nextUrl != _url) {
                    setState(() => _url = nextUrl);
                    _subscribe();
                  }
                  if (parsed != null) {
                    setState(() => _currentJson = parsed!);
                    await _client.saveJson(parsed);
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
                child: const Text('Save & Push to Firebase RTDB'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('stac-live-section'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_sync_outlined,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Firebase RTDB · Stac SDUI',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: _openFirebaseConfigSheet,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      child: Text(
                        'JSON / DB',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Builder(
            builder: (ctx) =>
                Stac.fromJson(_currentJson, ctx) ?? const SizedBox.shrink(),
          ),
          ValueListenableBuilder<StacHostSelection?>(
            valueListenable: StacHostBridge.instance,
            builder: (context, selection, _) {
              if (selection == null) return const SizedBox.shrink();
              return DecoratedBox(
                key: const Key('stac-host-readout'),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Text(
                    'Host received from Stac: ${selection.edition} · '
                    '${selection.yawDegrees.toStringAsFixed(0)}° · '
                    'Promo ${selection.promoCode} (-${selection.discountPercent}%)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
