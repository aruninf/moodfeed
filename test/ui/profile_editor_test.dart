import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodfeed/data/store.dart';
import 'package:moodfeed/models.dart';
import 'package:moodfeed/state/providers.dart';
import 'package:moodfeed/ui/profiles_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> pumpProfiles(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        storeProvider.overrideWithValue(Store(await SharedPreferences.getInstance())),
        initialDataProvider.overrideWithValue(MoodData.defaults()),
        clockProvider.overrideWith((ref) => Stream.value(DateTime(2026, 11, 16, 9))),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: ProfilesScreen())),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Profile profileOf(ProviderContainer container, String id) =>
      container.read(dataProvider).profiles.firstWhere((p) => p.id == id);

  testWidgets('lists the four modes', (tester) async {
    await pumpProfiles(tester);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Public'), findsOneWidget);
    expect(find.text('Private'), findsOneWidget);
    expect(find.text('Relax'), findsOneWidget);
  });

  testWidgets('editing a surface level persists it', (tester) async {
    final container = await pumpProfiles(tester);

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('surface-feed')),
        matching: find.text('Allow'),
      ),
    );
    await tester.pumpAndSettle();

    expect(profileOf(container, 'work').surfaces[Surface.feed], Level.allow);
  });

  testWidgets('setting a new default clears the previous one', (tester) async {
    final container = await pumpProfiles(tester);

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('make-default')));
    await tester.pumpAndSettle();

    final defaults =
        container.read(dataProvider).profiles.where((p) => p.isDefault).toList();
    expect(defaults.length, 1);
    expect(defaults.single.id, 'work');
    expect(container.read(dataProvider).settings.defaultProfileId, 'work');
  });

  testWidgets('following-only is its own switch, not a surface level',
      (tester) async {
    final container = await pumpProfiles(tester);
    final before = profileOf(container, 'work').surfaces;

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('following-only')));
    await tester.pumpAndSettle();

    final after = profileOf(container, 'work');
    expect(after.followingOnly, true);
    expect(after.surfaces, before);
  });
}
