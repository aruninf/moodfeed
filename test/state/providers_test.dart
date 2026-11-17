import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodfeed/data/store.dart';
import 'package:moodfeed/models.dart';
import 'package:moodfeed/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> containerAt(DateTime now, {Store? store}) async {
    SharedPreferences.setMockInitialValues({});
    final resolved = store ?? Store(await SharedPreferences.getInstance());
    return ProviderContainer(
      overrides: [
        storeProvider.overrideWithValue(resolved),
        initialDataProvider.overrideWithValue(MoodData.defaults()),
        clockProvider.overrideWith((ref) => Stream.value(now)),
      ],
    );
  }

  test('active state is derived from the clock and the store', () async {
    final container = await containerAt(DateTime(2026, 11, 16, 9));
    addTearDown(container.dispose);
    final sub = container.listen(activeStateProvider, (_, _) {});
    addTearDown(sub.close);

    await container.read(clockProvider.future);

    final state = container.read(activeStateProvider);
    expect(state.reason, Reason.scheduled);
    expect(state.baseProfile.id, 'work');
  });

  test('update persists through the store', () async {
    final container = await containerAt(DateTime(2026, 11, 16, 9));
    addTearDown(container.dispose);

    await container.read(dataProvider.notifier).update(
          (data) => data.copyWith(
            settings: data.settings.copyWith(gateEnabled: false),
          ),
        );

    expect(container.read(dataProvider).settings.gateEnabled, false);
    final reloaded = await container.read(storeProvider).load();
    expect(reloaded.settings.gateEnabled, false);
  });
}
