import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodfeed/data/store.dart';
import 'package:moodfeed/models.dart';
import 'package:moodfeed/state/providers.dart';
import 'package:moodfeed/ui/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> pumpHome(
    WidgetTester tester,
    DateTime now, {
    MoodData? data,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        storeProvider.overrideWithValue(Store(await SharedPreferences.getInstance())),
        initialDataProvider.overrideWithValue(data ?? MoodData.defaults()),
        clockProvider.overrideWith((ref) => Stream.value(now)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: HomeScreen())),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('shows the base mode and why it is active', (tester) async {
    await pumpHome(tester, DateTime(2026, 11, 16, 9));
    expect(
      tester.widget<Text>(find.byKey(const Key('active-mode'))).data,
      'Work',
    );
    expect(find.text('Scheduled'), findsOneWidget);
  });

  testWidgets('shows the protection countdown on the base mode', (tester) async {
    await pumpHome(
      tester,
      DateTime(2026, 11, 16, 18),
      data: MoodData.defaults().copyWith(
        protection: Protection(
          expiresAt: DateTime(2026, 11, 16, 21),
          softenedCategories: {
            Category.relationshipConflict,
            Category.breakup,
            Category.angerAggression,
          },
        ),
      ),
    );
    expect(find.text('Relax — protecting 3 topics'), findsOneWidget);
  });

  testWidgets('shows the base mode after protection expires', (tester) async {
    await pumpHome(
      tester,
      DateTime(2026, 11, 16, 18),
      data: MoodData.defaults().copyWith(
        protection: Protection(
          expiresAt: DateTime(2026, 11, 16, 10),
          softenedCategories: {Category.breakup},
        ),
      ),
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('active-mode'))).data,
      'Relax',
    );
    expect(find.textContaining('protecting'), findsNothing);
  });

  testWidgets('turning protection off is one tap from home', (tester) async {
    final container = await pumpHome(
      tester,
      DateTime(2026, 11, 16, 18),
      data: MoodData.defaults().copyWith(
        protection: Protection(
          expiresAt: DateTime(2026, 11, 16, 21),
          softenedCategories: {Category.breakup},
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('protection-badge')));
    await tester.pumpAndSettle();

    expect(container.read(dataProvider).protection, isNull);
  });

  testWidgets('pinning a mode expires at the next boundary', (tester) async {
    final container = await pumpHome(tester, DateTime(2026, 11, 16, 9));

    await tester.tap(find.text('Private'));
    await tester.pumpAndSettle();

    final pin = container.read(dataProvider).pin;
    expect(pin!.profileId, 'private');
    expect(pin.expiresAt, DateTime(2026, 11, 16, 17));
  });
}
