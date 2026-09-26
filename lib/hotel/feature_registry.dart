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
    return _enqueue(f);
  }

  /// Runs a reconcile after any pending one for [f]. [_reconcile] never
  /// throws, so one failure can't poison the chain for later toggles.
  Future<void> _enqueue(HotelFeature f) {
    final next = (_chain[f.id] ?? Future.value()).then((_) => _reconcile(f));
    _chain[f.id] = next;
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
    try {
      if (want && !have) {
        try {
          await feature.mount(ctx);
        } catch (_) {
          // Undo whatever the failed mount attached, and show the switch off.
          _wanted.remove(f.id);
          try {
            feature.unmount(ctx);
          } catch (_) {}
          rethrow;
        }
        _mounted.add(f.id);
      } else if (!want && have) {
        feature.unmount(ctx);
        _mounted.remove(f.id);
      }
    } catch (e, st) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: st,
        library: 'hotel feature registry',
        context: ErrorDescription(
            'while ${want ? 'mounting' : 'unmounting'} feature "${f.id}"'),
      ));
    }
    notifyListeners();
  }

  /// Mounts the default features in catalog order. All of them are marked
  /// wanted up front, so a toggle the user makes while loading is kept
  /// instead of being switched back when its turn comes.
  Future<void> mountDefaults() async {
    final defaults = [
      for (final f in features)
        if (f.defaultOn || !f.toggleable) f
    ];
    _wanted.addAll(defaults.map((f) => f.id));
    notifyListeners();
    for (final f in defaults) {
      await _enqueue(f);
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
