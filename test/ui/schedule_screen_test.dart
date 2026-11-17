import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodfeed/data/store.dart';
import 'package:moodfeed/models.dart';
import 'package:moodfeed/state/providers.dart';
import 'package:moodfeed/ui/schedule_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Schedule block({
    String id = 's1',
    int start = 540,
    int end = 1020,
    Set<int> days = const {1, 2, 3, 4, 5},
  }) =>
      Schedule(
        id: id,
        profileId: 'work',
        daysOfWeek: days,
        startMinute: start,
        endMinute: end,
        priority: 0,
        enabled: true,
        updatedAt: DateTime(2026, 11, 1),
      );

  Future<ProviderContainer> pumpSchedule(
    WidgetTester tester, {
    List<Schedule>? schedules,
  }) async {
    schedules ??= [block()];
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        storeProvider.overrideWithValue(Store(await SharedPreferences.getInstance())),
        initialDataProvider.overrideWithValue(
          MoodData.defaults().copyWith(schedules: schedules),
        ),
        clockProvider.overrideWith((ref) => Stream.value(DateTime(2026, 11, 16, 9))),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: ScheduleScreen())),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('lists blocks sorted by start time', (tester) async {
    await pumpSchedule(
      tester,
      schedules: [
        block(id: 'late', start: 600, end: 660),
        block(id: 'early', start: 480, end: 510),
      ],
    );

    final early = tester.getTopLeft(find.text('08:00 – 08:30')).dy;
    final late = tester.getTopLeft(find.text('10:00 – 11:00')).dy;
    expect(early, lessThan(late));
  });

  testWidgets('a block shows its days, window and mode', (tester) async {
    await pumpSchedule(tester);
    expect(find.text('Mon–Fri'), findsOneWidget);
    expect(find.text('09:00 – 17:00'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
  });

  testWidgets('disabling a block removes it from resolution', (tester) async {
    final container = await pumpSchedule(tester);

    await tester.tap(find.byKey(const Key('enabled-s1')));
    await tester.pumpAndSettle();

    expect(container.read(dataProvider).schedules.single.enabled, false);
    expect(container.read(activeStateProvider).reason, Reason.defaultProfile);
  });

  testWidgets('a wrapping block is labelled as overnight', (tester) async {
    await pumpSchedule(tester, schedules: [block(start: 1320, end: 420)]);
    expect(find.text('22:00 – 07:00'), findsOneWidget);
    expect(find.text('Overnight'), findsOneWidget);
  });
}
