import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodfeed/data/store.dart';
import 'package:moodfeed/state/providers.dart';
import 'package:moodfeed/ui/protection_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 11, 16, 20);

  Future<ProviderContainer> openSheet(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        storeProvider.overrideWithValue(Store(await SharedPreferences.getInstance())),
        initialDataProvider.overrideWithValue(MoodData.defaults()),
        clockProvider.overrideWith((ref) => Stream.value(now)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showProtectionSheet(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('offers 30m, 2h, 4h and until morning', (tester) async {
    await openSheet(tester);
    expect(find.text('30m'), findsOneWidget);
    expect(find.text('2h'), findsOneWidget);
    expect(find.text('4h'), findsOneWidget);
    expect(find.text('Until morning'), findsOneWidget);
  });

  testWidgets('preselects the stored default categories', (tester) async {
    await openSheet(tester);
    for (final label in [
      'Relationship conflict',
      'Breakup',
      'Anger aggression',
    ]) {
      final tile = tester.widget<CheckboxListTile>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(CheckboxListTile),
        ),
      );
      expect(tile.value, true, reason: label);
    }
  });

  testWidgets('romantic and suggestive are absent, not disabled',
      (tester) async {
    await openSheet(tester);
    expect(find.text('Romantic'), findsNothing);
    expect(find.text('Suggestive'), findsNothing);
  });

  testWidgets('confirming writes an expiry and leaves the base mode alone',
      (tester) async {
    final container = await openSheet(tester);
    final before = container.read(dataProvider);

    await tester.tap(find.widgetWithText(ChoiceChip, '4h'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Protect'));
    await tester.pumpAndSettle();

    final after = container.read(dataProvider);
    expect(after.protection!.expiresAt, now.add(const Duration(hours: 4)));
    expect(after.protection!.softenedCategories.length, 3);
    expect(after.settings.defaultProfileId, before.settings.defaultProfileId);
    expect(after.profiles.length, before.profiles.length);
  });
}
