import 'package:flutter/foundation.dart';
import 'feature.dart';
import 'hotel_context.dart';

/// Owns which features are mounted. Requests for one feature are serialised
/// through a per-feature chain; each step reconciles "mounted" with the
/// latest "wanted", so a quick on/off/on ends in exactly the last state.
class FeatureRegistry extends ChangeNotifier {
  FeatureRegistry(this.features, {required this.mountContext});

  final List<HotelFeature> features;

  /// Null only in tests.
  final HotelContext? mountContext;

  final Set<String> _mounted = {};
  final Set<String> _wanted = {};
  final Map<String, Future<void>> _chain = {};

  HotelFeature byId(String id) => features.firstWhere((f) => f.id == id);
  bool isEnabled(String id) => _wanted.contains(id);
  bool isMounted(String id) => _mounted.contains(id);

  Future<void> setEnabled(String id, bool on) {
    final f = byId(id);
    if (!on && !f.toggleable) return Future.value();
    on ? _wanted.add(id) : _wanted.remove(id);
    notifyListeners();
    final next = (_chain[id] ?? Future.value()).then((_) => _reconcile(f));
    _chain[id] = next;
    return next;
  }

  Future<void> _reconcile(HotelFeature f) async {
    // mountContext is null only in tests, whose fakes accept Object?. A typed
    // call `f.mount(null as dynamic)` would cast at the call site and throw,
    // so dispatch dynamically and let the override's own parameter type check.
    final ctx = mountContext;
    final dynamic feature = f;
    final want = _wanted.contains(f.id);
    final have = _mounted.contains(f.id);
    if (want && !have) {
      await feature.mount(ctx);
      _mounted.add(f.id);
    } else if (!want && have) {
      feature.unmount(ctx);
      _mounted.remove(f.id);
    }
    notifyListeners();
  }

  Future<void> mountDefaults() async {
    for (final f in features) {
      if (f.defaultOn || !f.toggleable) await setEnabled(f.id, true);
    }
  }

  void tick(double dt) {
    final ctx = mountContext;
    if (ctx == null) return;
    for (final f in features) {
      if (_mounted.contains(f.id)) f.tick(ctx, dt);
    }
  }
}
