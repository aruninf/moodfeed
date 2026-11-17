import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodfeed/data/store.dart';
import 'package:moodfeed/state/providers.dart';
import 'package:moodfeed/ui/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> pumpSettings(
    WidgetTester tester, {
    bool packInstalled = false,
    bool usageAccess = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        storeProvider.overrideWithValue(Store(await SharedPreferences.getInstance())),
        initialDataProvider.overrideWithValue(MoodData.defaults()),
        clockProvider.overrideWith((ref) => Stream.value(DateTime(2026, 11, 16, 9))),
        packInstalledProvider.overrideWith((ref) async => packInstalled),
        usageAccessProvider.overrideWith((ref) async => usageAccess),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('keeps the gate toggle whether or not the pack is installed',
      (tester) async {
    await pumpSettings(tester);
    expect(find.text('App-open reminder'), findsOneWidget);

    await pumpSettings(tester, packInstalled: true);
    expect(find.text('App-open reminder'), findsOneWidget);
  });

  testWidgets('names the pack as installed without hiding anything',
      (tester) async {
    await pumpSettings(tester, packInstalled: true);
    expect(find.text('MoodFeed pack'), findsOneWidget);
    expect(find.text('Installed'), findsOneWidget);
    expect(find.text('App-open reminder'), findsOneWidget);
  });

  testWidgets('shows the honest degraded-mode line when usage access is missing',
      (tester) async {
    await pumpSettings(tester, usageAccess: false);
    expect(
      find.textContaining('cannot tell when Instagram opens'),
      findsOneWidget,
    );
  });
}
