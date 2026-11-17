import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodfeed/data/store.dart';
import 'package:moodfeed/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Store> freshStore([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  return Store(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('first launch returns a default profile and a weekday schedule',
      () async {
    final store = await freshStore();
    final data = await store.load();

    expect(data.profiles.map((p) => p.name), ['Work', 'Public', 'Private', 'Relax']);
    expect(data.profiles.where((p) => p.isDefault).length, 1);
    expect(data.settings.defaultProfileId, 'relax');
    expect(data.schedules.length, 1);
    expect(data.schedules.single.profileId, 'work');
    expect(data.schedules.single.startMinute, 540);
    expect(data.schedules.single.endMinute, 1020);
    expect(data.settings.protectionDefaults, {
      Category.relationshipConflict,
      Category.breakup,
      Category.angerAggression,
    });
  });

  test('round-trips profiles, schedules, pin and protection', () async {
    final store = await freshStore();
    final defaults = MoodData.defaults();
    final data = MoodData(
      profiles: [
        const Profile(
          id: 'work',
          name: 'Deep Work',
          icon: 1,
          color: 0xff112233,
          categoryLevels: {Category.breakup: Level.hide, Category.comedy: Level.reduce},
          surfaces: {Surface.feed: Level.hide, Surface.stories: Level.allow},
          followingOnly: true,
          isDefault: true,
        ),
      ],
      schedules: [
        Schedule(
          id: 's1',
          profileId: 'work',
          daysOfWeek: {DateTime.monday, DateTime.friday},
          startMinute: 1320,
          endMinute: 420,
          priority: 3,
          enabled: false,
          updatedAt: DateTime(2026, 11, 16, 7, 30),
        ),
      ],
      pin: Pin(
        profileId: 'work',
        startedAt: DateTime(2026, 11, 16, 8),
        expiresAt: DateTime(2026, 11, 16, 17),
      ),
      protection: Protection(
        expiresAt: DateTime(2026, 11, 16, 21),
        softenedCategories: {Category.angerAggression},
      ),
      settings: Settings(
        defaultProfileId: 'work',
        gateEnabled: false,
        protectionDefaults: {Category.breakup},
        counterOptIn: true,
      ),
      gateEvents: [
        GateEvent(
          ts: DateTime(2026, 11, 16, 9, 15),
          packageName: 'com.instagram.android',
          action: 'closed',
          profileId: 'work',
          protectionOn: true,
        ),
      ],
    );
    expect(data.schedules.single.daysOfWeek, {DateTime.monday, DateTime.friday});
    expect(defaults.schedules.length, 1);

    await store.save(data);
    final again = await store.load();

    expect(again.profiles.single.name, 'Deep Work');
    expect(again.profiles.single.categoryLevels[Category.breakup], Level.hide);
    expect(again.profiles.single.surfaces[Surface.feed], Level.hide);
    expect(again.profiles.single.followingOnly, true);
    expect(again.schedules.single.daysOfWeek, {DateTime.monday, DateTime.friday});
    expect(again.schedules.single.startMinute, 1320);
    expect(again.schedules.single.enabled, false);
    expect(again.pin!.expiresAt, DateTime(2026, 11, 16, 17));
    expect(again.protection!.softenedCategories, {Category.angerAggression});
    expect(again.settings.gateEnabled, false);
    expect(again.settings.counterOptIn, true);
    expect(again.gateEvents.single.action, 'closed');
  });

  test('corrupt JSON returns defaults and does not throw', () async {
    final store = await freshStore({'moodfeed.v1': '{not json'});
    final data = await store.load();
    expect(data.profiles.length, 4);
    expect(data.settings.defaultProfileId, 'relax');
  });

  test('partial JSON keeps what it can and fills the rest', () async {
    final store = await freshStore({'moodfeed.v1': '{"profiles":[]}'});
    final data = await store.load();
    expect(data.profiles, isEmpty);
    expect(data.schedules.length, 1);
    expect(data.settings.defaultProfileId, 'relax');
    expect(jsonEncode(data.toJson()), isNotEmpty);
  });
}
