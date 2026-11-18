import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store.dart';
import '../domain/resolver.dart';
import '../models.dart';
import '../platform/gate.dart';
import '../platform/pack_bridge.dart';
import '../platform/usage_channel.dart';

/// Overridden in `main()` once `SharedPreferences` has resolved.
final storeProvider = Provider<Store>(
  (ref) => throw UnimplementedError('storeProvider must be overridden'),
);

/// The document loaded before the first frame, so the app never flashes a
/// default mode while the real one is being read.
final initialDataProvider = Provider<MoodData>((ref) => MoodData.defaults());

final dataProvider = NotifierProvider<DataNotifier, MoodData>(DataNotifier.new);

/// One tick per second. The active state is derived from it, never stored.
final clockProvider = StreamProvider<DateTime>(
  (ref) => Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
);

/// The single read of the resolver. Everything else consumes this.
final activeStateProvider = Provider<ActiveState>((ref) {
  final data = ref.watch(dataProvider);
  final now = ref.watch(clockProvider).value ?? DateTime.now();
  return resolveActiveState(
    now: now,
    profiles: data.profiles,
    schedules: data.schedules,
    defaultProfileId: data.settings.defaultProfileId,
    pin: data.pin,
    protection: data.protection,
  );
});

final packInstalledProvider =
    FutureProvider<bool>((ref) => const MoodFeedPlatform().isPackInstalled());

final packBridgeProvider = Provider<PackBridge>((ref) => const PackBridge());

final usageAccessProvider =
    FutureProvider<bool>((ref) => const MoodFeedPlatform().hasUsageAccess());

final gateProvider = Provider<Gate>((ref) => Gate(ref.watch(storeProvider).prefs));

class TestModeNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(storeProvider).prefs;
    return prefs.getBool('moodfeed.gate.test_mode') ?? false;
  }

  Future<void> toggle(bool value) async {
    state = value;
    await ref.read(storeProvider).prefs.setBool('moodfeed.gate.test_mode', value);
    await ref.read(gateProvider).clearCooldown();
  }
}

final testModeProvider =
    NotifierProvider<TestModeNotifier, bool>(TestModeNotifier.new);

class DataNotifier extends Notifier<MoodData> {
  @override
  MoodData build() => ref.read(initialDataProvider);

  Future<void> update(MoodData Function(MoodData) change) async {
    final next = change(state);
    state = next;
    await ref.read(storeProvider).save(next);
  }
}
