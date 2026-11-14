import 'package:flutter/foundation.dart';

/// Structured value sent from an interactive Stac 3D / Shader widget or
/// `send_to_host` Stac action back to the host application (Flutter or Native).
@immutable
class StacHostSelection {
  const StacHostSelection({
    required this.edition,
    required this.discountPercent,
    required this.promoCode,
    this.waveLevel = 'Breeze',
    this.yawDegrees = 0.0,
  });

  final String edition;
  final int discountPercent;
  final String promoCode;
  final String waveLevel;
  final double yawDegrees;

  int applyDiscountThb(int baseNightlyThb) {
    final clamped = discountPercent.clamp(0, 90);
    return ((baseNightlyThb * (100 - clamped)) / 100).round();
  }

  Map<String, dynamic> toMap() => {
    'edition': edition,
    'discountPercent': discountPercent,
    'promoCode': promoCode,
    'waveLevel': waveLevel,
    'yawDegrees': yawDegrees,
  };
}

/// Shared bridge receiving live updates from Stac 3D / Shader widgets and
/// `send_to_host` actions. In Pure Flutter (`flutter_3d`), `HomePage` listens
/// to [instance]; in Native Add-to-App (`flutter-inapp-ios`), [onForwardToHost]
/// forwards the map over `MethodChannel` to UIKit / Jetpack Compose.
class StacHostBridge extends ValueNotifier<StacHostSelection?> {
  StacHostBridge._() : super(null);

  static final StacHostBridge instance = StacHostBridge._();

  void Function(Map<String, dynamic> payload)? onForwardToHost;

  void updateFromMap(Map<String, dynamic> map) {
    final current = value;
    final next = StacHostSelection(
      edition: (map['edition'] as String?) ?? current?.edition ?? 'Midnight',
      discountPercent:
          (map['discountPercent'] as num?)?.toInt() ??
          current?.discountPercent ??
          0,
      promoCode: (map['promoCode'] as String?) ?? current?.promoCode ?? '',
      waveLevel: (map['waveLevel'] as String?) ?? current?.waveLevel ?? 'Breeze',
      yawDegrees:
          (map['yawDegrees'] as num?)?.toDouble() ?? current?.yawDegrees ?? 0.0,
    );
    value = next;
    onForwardToHost?.call(next.toMap());
  }

  void reset() {
    value = null;
  }
}
