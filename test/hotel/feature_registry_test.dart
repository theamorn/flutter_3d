import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_3d/hotel/feature.dart';
import 'package:flutter_3d/hotel/feature_registry.dart';

class _Fake extends HotelFeature {
  _Fake(this.id, {this.delay = Duration.zero});
  @override final String id;
  final Duration delay;
  int mounts = 0, unmounts = 0;
  @override String get label => id;
  @override CostTier get tier => CostTier.cheap;
  // Parameter widened to Object? (a legal override) so tests can pass null.
  @override Future<void> mount(Object? ctx) async { await Future.delayed(delay); mounts++; }
  @override void unmount(Object? ctx) { unmounts++; }
}

void main() {
  test('setEnabled mounts then unmounts', () async {
    final f = _Fake('a');
    final r = FeatureRegistry([f], mountContext: null);
    await r.setEnabled('a', true);
    expect(r.isEnabled('a'), true);
    expect(f.mounts, 1);
    await r.setEnabled('a', false);
    expect(r.isEnabled('a'), false);
    expect(f.unmounts, 1);
  });

  test('later toggle supersedes an in-flight mount', () async {
    final f = _Fake('a', delay: const Duration(milliseconds: 50));
    final r = FeatureRegistry([f], mountContext: null);
    final first = r.setEnabled('a', true);
    final second = r.setEnabled('a', false); // user flips it back before mount finishes
    await first;
    await second;
    expect(r.isEnabled('a'), false);
    // the late mount must be undone: mounted count == unmounted count
    expect(f.mounts, f.unmounts);
  });

  test('on/off/on quickly leaves exactly one mount', () async {
    final f = _Fake('a', delay: const Duration(milliseconds: 20));
    final r = FeatureRegistry([f], mountContext: null);
    unawaited(r.setEnabled('a', true));
    unawaited(r.setEnabled('a', false));
    await r.setEnabled('a', true);
    await Future.delayed(const Duration(milliseconds: 80));
    expect(r.isEnabled('a'), true);
    expect(f.mounts - f.unmounts, 1);
  });

  test('a throwing mount does not poison later toggles', () async {
    final f = _Flaky('a');
    final r = FeatureRegistry([f], mountContext: null);
    await r.setEnabled('a', true); // fails; must not throw to the caller
    expect(r.isEnabled('a'), false); // the switch falls back to off
    expect(r.isMounted('a'), false);
    expect(f.unmounts, 1); // whatever mount attached is cleaned up
    await r.setEnabled('a', true); // a retry still reaches mount
    expect(r.isMounted('a'), true);
    expect(f.mounts, 1);
  });

  test('mountDefaults carries on past a failing feature', () async {
    final bad = _Flaky('bad'), ok = _Fake('ok');
    final r = FeatureRegistry([bad, ok], mountContext: null);
    await r.mountDefaults();
    expect(r.isMounted('ok'), true);
  });

  test('a toggle made while defaults are still mounting is kept', () async {
    final slow = _Fake('slow', delay: const Duration(milliseconds: 30));
    final fog = _Fake('fog');
    final r = FeatureRegistry([slow, fog], mountContext: null);
    final boot = r.mountDefaults();
    await Future.delayed(const Duration(milliseconds: 5));
    await r.setEnabled('fog', false); // user switches fog off during loading
    await boot;
    expect(r.isEnabled('fog'), false);
    expect(fog.mounts - fog.unmounts, 0);
  });

  test('non-toggleable feature cannot be disabled', () async {
    final f = _Base();
    final r = FeatureRegistry([f], mountContext: null);
    await r.setEnabled('base', true);
    await r.setEnabled('base', false);
    expect(r.isEnabled('base'), true);
  });
}

class _Base extends _Fake {
  _Base() : super('base');
  @override bool get toggleable => false;
}

/// Mount throws on the first attempt only.
class _Flaky extends _Fake {
  _Flaky(super.id);
  int attempts = 0;
  @override
  Future<void> mount(Object? ctx) async {
    attempts++;
    if (attempts == 1) throw StateError('asset failed to load');
    mounts++;
  }
}
