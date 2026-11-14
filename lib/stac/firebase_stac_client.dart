import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Default Firebase Realtime Database JSON endpoint for the Stac + 3D card.
/// Set via `--dart-define=STAC_FIREBASE_URL=https://your-db.firebaseio.com/stac_card.json`
/// or pass a custom URL to [FirebaseStacClient].
const String kDefaultFirebaseRtdbUrl = String.fromEnvironment(
  'STAC_FIREBASE_URL',
  defaultValue: '',
);

/// Default Stac JSON payload combining:
/// 1) Simple Stac (100% built-in Stac widgets: `chip`, `linearProgressIndicator`,
///    `form`, `textFormField`, `divider`) for live marketing & form updates, and
/// 2) Advanced Animated Stac (`interactive_3d_turntable` with JSON-driven
///    `characterAnim`, `autoSpinSpeed`, `holoScanLoop`, 3D models & `.fmat` shaders).
const Map<String, dynamic> kDefaultStac3dCardJson = {
  'type': 'container',
  'padding': {'left': 16, 'top': 16, 'right': 16, 'bottom': 16},
  'child': {
    'type': 'column',
    'mainAxisSize': 'min',
    'crossAxisAlignment': 'start',
    'children': [
      {
        'type': 'chip',
        'backgroundColor': '#FEF3C7',
        'label': {
          'type': 'text',
          'data': '🔥 DEVFEST BKK FLASH DROP · 78% CLAIMED',
          'style': {
            'fontSize': 11,
            'fontWeight': 'bold',
            'color': '#B45309',
          },
        },
      },
      {'type': 'sizedBox', 'height': 8},
      {
        'type': 'text',
        'data': 'Stac + Firebase Live 3D & Shader Studio',
        'style': {'fontSize': 18, 'fontWeight': 'bold'},
      },
      {'type': 'sizedBox', 'height': 6},
      {
        'type': 'linearProgressIndicator',
        'value': 0.78,
        'color': '#F59E0B',
        'backgroundColor': '#FDE68A',
        'minHeight': 6.0,
      },
      {'type': 'sizedBox', 'height': 10},
      {
        'type': 'form',
        'child': {
          'type': 'textFormField',
          'id': 'vip_code',
          'initialValue': 'DEVFEST2026',
          'decoration': {
            'labelText': 'VIP Member / Promo Code (Simple Stac Form)',
            'hintText': 'Edit in Firebase RTDB or type here',
          },
        },
      },
      {'type': 'sizedBox', 'height': 10},
      {'type': 'divider'},
      {'type': 'sizedBox', 'height': 6},
      {
        'type': 'text',
        'data':
            'Advanced Stac below: edit characterAnim ("idle" | "walk" | "punch"), autoSpinSpeed, or holoScanLoop in Firebase RTDB!',
        'style': {'fontSize': 12},
      },
      {'type': 'sizedBox', 'height': 10},
      {
        'type': 'interactive_3d_turntable',
        'model': 'island',
        'edition': 'Sunset Gold',
        'characterAnim': 'idle',
        'autoSpinSpeed': 0.35,
        'holoScanLoop': false,
        'discountPercent': 20,
        'promoCode': 'STAC20',
        'height': 320,
      },
      {'type': 'sizedBox', 'height': 12},
      {
        'type': 'filledButton',
        'onPressed': {
          'actionType': 'send_to_host',
          'edition': 'Sunset Gold',
          'discountPercent': 20,
          'promoCode': 'STAC20',
        },
        'child': {'type': 'text', 'data': 'Apply Stac 3D Offer (-20%)'},
      },
    ],
  },
};

/// Stac JSON preset showcasing the 3D Nimbus Headphones (`"model": "headphones"`)
/// with anodized PBR metal and `.fmat` holographic laser wireframe scan.
const Map<String, dynamic> kDefaultStacHeadphonesCardJson = {
  'type': 'container',
  'padding': {'left': 16, 'top': 16, 'right': 16, 'bottom': 16},
  'child': {
    'type': 'column',
    'mainAxisSize': 'min',
    'crossAxisAlignment': 'start',
    'children': [
      {
        'type': 'chip',
        'backgroundColor': '#E0E7FF',
        'label': {
          'type': 'text',
          'data': '🎧 VIP AUDIO DROP · 92% CLAIMED',
          'style': {
            'fontSize': 11,
            'fontWeight': 'bold',
            'color': '#1D4ED8',
          },
        },
      },
      {'type': 'sizedBox', 'height': 8},
      {
        'type': 'text',
        'data': 'Stac + 3D Nimbus Headphones Configurator',
        'style': {'fontSize': 18, 'fontWeight': 'bold'},
      },
      {'type': 'sizedBox', 'height': 6},
      {
        'type': 'linearProgressIndicator',
        'value': 0.92,
        'color': '#3B82F6',
        'backgroundColor': '#DBEAFE',
        'minHeight': 6.0,
      },
      {'type': 'sizedBox', 'height': 10},
      {
        'type': 'form',
        'child': {
          'type': 'textFormField',
          'id': 'vip_code',
          'initialValue': 'NIMBUS25',
          'decoration': {
            'labelText': 'Trade-In / Promo Code (Simple Stac Form)',
          },
        },
      },
      {'type': 'sizedBox', 'height': 10},
      {'type': 'divider'},
      {'type': 'sizedBox', 'height': 8},
      {
        'type': 'interactive_3d_turntable',
        'model': 'headphones',
        'edition': 'Midnight',
        'characterAnim': 'idle',
        'autoSpinSpeed': 0.45,
        'holoScanLoop': true,
        'discountPercent': 25,
        'promoCode': 'NIMBUS25',
        'height': 320,
      },
      {'type': 'sizedBox', 'height': 12},
      {
        'type': 'filledButton',
        'onPressed': {
          'actionType': 'send_to_host',
          'edition': 'Midnight',
          'discountPercent': 25,
          'promoCode': 'NIMBUS25',
        },
        'child': {'type': 'text', 'data': 'Claim 3D Headphones Offer (-25%)'},
      },
    ],
  },
};

/// Alternative Stac JSON payload embedding the custom `interactive_shader_box`
/// (`water.glsl` / `sky.glsl`) inside Stac Server-Driven UI.
const Map<String, dynamic> kDefaultStacShaderCardJson = {
  'type': 'container',
  'padding': {'left': 16, 'top': 16, 'right': 16, 'bottom': 16},
  'child': {
    'type': 'column',
    'mainAxisSize': 'min',
    'crossAxisAlignment': 'start',
    'children': [
      {
        'type': 'text',
        'data': 'Stac + Firebase Water Shader Promo',
        'style': {'fontSize': 18, 'fontWeight': 'bold'},
      },
      {'type': 'sizedBox', 'height': 6},
      {
        'type': 'text',
        'data':
            'Tap waves to swell the sea shader or drag sideways. Sends wave level & promo back to Host!',
      },
      {'type': 'sizedBox', 'height': 12},
      {
        'type': 'interactive_shader_box',
        'shader': 'sea',
        'initialWaveLevel': 3,
        'discountPercent': 25,
        'promoCode': 'WAVE25',
        'height': 260,
      },
      {'type': 'sizedBox', 'height': 12},
      {
        'type': 'filledButton',
        'onPressed': {
          'actionType': 'send_to_host',
          'edition': 'Oceanfront Wave Promo',
          'waveLevel': 'Storm',
          'discountPercent': 25,
          'promoCode': 'WAVE25',
        },
        'child': {'type': 'text', 'data': 'Claim Wave Shader Offer (-25%)'},
      },
    ],
  },
};

/// Streams and updates Stac JSON from Firebase Realtime Database using REST +
/// Server-Sent Events (`Accept: text/event-stream`).
class FirebaseStacClient {
  FirebaseStacClient({
    this.url = kDefaultFirebaseRtdbUrl,
    http.Client? httpClient,
  }) : _client = httpClient ?? http.Client();

  final String url;
  final http.Client _client;

  /// Extracts a root JSON map from a Firebase RTDB SSE frame (`event: put`).
  static Map<String, dynamic>? parseSseEventData(String rawEvent) {
    return applySseChunkToDocument(null, rawEvent);
  }

  /// Applies a Firebase RTDB SSE `put` or `patch` frame to [currentDocument].
  static Map<String, dynamic>? applySseChunkToDocument(
    Map<String, dynamic>? currentDocument,
    String rawEvent,
  ) {
    String? eventType;
    final dataLines = <String>[];
    for (final line in rawEvent.split('\n')) {
      final trimmed = line.trimRight();
      if (trimmed.startsWith('event:')) {
        eventType = trimmed.substring('event:'.length).trim();
      } else if (trimmed.startsWith('data:')) {
        dataLines.add(trimmed.substring('data:'.length).trim());
      }
    }
    if (eventType != 'put' && eventType != 'patch') return null;
    if (dataLines.isEmpty) return null;

    final rawData = dataLines.join('\n');
    if (rawData.isEmpty || rawData == 'null') return null;

    try {
      final decoded = jsonDecode(rawData);
      if (decoded is! Map<String, dynamic>) return null;
      final path = decoded['path'] as String? ?? '/';
      final payload = decoded['data'];
      if (payload == null) return null;

      if (path == '/' || path.isEmpty) {
        if (payload is Map<String, dynamic>) {
          return Map<String, dynamic>.from(payload);
        }
        return null;
      }

      if (currentDocument == null) return null;
      final copy =
          jsonDecode(jsonEncode(currentDocument)) as Map<String, dynamic>;
      final segments = path
          .split('/')
          .where((segment) => segment.isNotEmpty)
          .toList();
      if (segments.isEmpty) return null;

      dynamic cursor = copy;
      for (var i = 0; i < segments.length - 1; i++) {
        final seg = segments[i];
        if (cursor is Map<String, dynamic>) {
          cursor = cursor[seg];
        } else if (cursor is List) {
          final index = int.tryParse(seg);
          if (index == null || index < 0 || index >= cursor.length) {
            return null;
          }
          cursor = cursor[index];
        } else {
          return null;
        }
      }

      final lastSeg = segments.last;
      if (cursor is Map<String, dynamic>) {
        if (eventType == 'patch' &&
            payload is Map<String, dynamic> &&
            cursor[lastSeg] is Map<String, dynamic>) {
          (cursor[lastSeg] as Map<String, dynamic>).addAll(payload);
        } else {
          cursor[lastSeg] = payload;
        }
        return copy;
      } else if (cursor is List) {
        final index = int.tryParse(lastSeg);
        if (index == null || index < 0 || index >= cursor.length) {
          return null;
        }
        if (eventType == 'patch' &&
            payload is Map<String, dynamic> &&
            cursor[index] is Map<String, dynamic>) {
          (cursor[index] as Map<String, dynamic>).addAll(payload);
        } else {
          cursor[index] = payload;
        }
        return copy;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Fetches the current JSON once, opens a real-time SSE stream (`text/event-stream`),
  /// and runs a lightweight diff check against Firebase Realtime Database so clicking
  /// Save in the Firebase Console pushes updates immediately on any network/OS.
  Stream<Map<String, dynamic>> watchJson({bool enablePeriodicSync = false}) {
    final controller = StreamController<Map<String, dynamic>>();
    Map<String, dynamic> current = Map<String, dynamic>.from(
      kDefaultStac3dCardJson,
    );
    String lastSerialized = jsonEncode(current);
    StreamSubscription<String>? sseSub;
    Timer? syncTimer;
    bool fetching = false;

    void emitIfChanged(Map<String, dynamic> next) {
      if (controller.isClosed) return;
      final serialized = jsonEncode(next);
      if (serialized != lastSerialized) {
        lastSerialized = serialized;
        current = next;
        controller.add(current);
      }
    }

    Future<void> fetchLatest() async {
      if (url.isEmpty || fetching || controller.isClosed) return;
      fetching = true;
      try {
        final res = await _client.get(
          Uri.parse(url),
          headers: const {'Cache-Control': 'no-cache'},
        );
        if (res.statusCode == 200 &&
            res.body.isNotEmpty &&
            res.body.trim() != 'null') {
          final decoded = jsonDecode(res.body);
          if (decoded is Map<String, dynamic>) {
            emitIfChanged(decoded);
          }
        }
      } catch (_) {
        // Ignore transient network errors.
      } finally {
        fetching = false;
      }
    }

    Future<void> start() async {
      // Emit initial default immediately so the UI renders without blank frame,
      // then overwrite with live Firebase RTDB JSON + real-time SSE updates.
      if (!controller.isClosed) {
        controller.add(current);
      }
      await fetchLatest();

      if (controller.isClosed || url.isEmpty) return;

      if (enablePeriodicSync) {
        syncTimer = Timer.periodic(
          const Duration(milliseconds: 1200),
          (_) => fetchLatest(),
        );
      }

      try {
        final req = http.Request('GET', Uri.parse(url));
        req.headers['Accept'] = 'text/event-stream';
        req.headers['Cache-Control'] = 'no-cache';
        final streamed = await _client.send(req);
        if (streamed.statusCode == 200 && !controller.isClosed) {
          var buffer = '';
          sseSub = streamed.stream
              .transform(utf8.decoder)
              .listen(
                (chunk) {
                  buffer += chunk;
                  while (buffer.contains('\n\n')) {
                    final idx = buffer.indexOf('\n\n');
                    final frame = buffer.substring(0, idx);
                    buffer = buffer.substring(idx + 2);
                    final updated = applySseChunkToDocument(current, frame);
                    if (updated != null) {
                      emitIfChanged(updated);
                    } else if (frame.contains('event: put') ||
                        frame.contains('event: patch')) {
                      fetchLatest();
                    }
                  }
                },
                onError: (_) {},
                cancelOnError: false,
              );
        }
      } catch (_) {
        // Stream open failed (e.g., inside widget tests or before DB URL is configured).
      }
    }

    start();

    controller.onCancel = () async {
      syncTimer?.cancel();
      await sseSub?.cancel();
    };

    return controller.stream;
  }

  /// Writes [jsonMap] directly to Firebase Realtime Database (`PUT <url>`).
  Future<bool> saveJson(Map<String, dynamic> jsonMap) async {
    if (url.isEmpty) return false;
    try {
      final res = await _client.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(jsonMap),
      );
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}
