import 'package:flutter_test/flutter_test.dart';
import 'package:moodfeed/models.dart';
import 'package:moodfeed/domain/resolver.dart';
import 'package:moodfeed/domain/timeline.dart';

Profile profile(
  String id, {
  bool isDefault = false,
  Map<Category, Level> categoryLevels = const {},
}) =>
    Profile(
      id: id,
      name: id,
      icon: 0,
      color: 0,
      categoryLevels: categoryLevels,
      surfaces: {Surface.feed: Level.hide},
      followingOnly: false,
      isDefault: isDefault,
    );

Schedule schedule({
  required Set<int> days,
  int start = 540,
  int end = 1020,
  String profileId = 'work',
}) =>
    Schedule(
      id: 's',
      profileId: profileId,
      daysOfWeek: days,
      startMinute: start,
      endMinute: end,
      priority: 0,
      enabled: true,
      updatedAt: DateTime(2026, 11, 1),
    );

void main() {
  test('starts at now and stops when no boundary remains', () {
    final now = DateTime(2026, 11, 16, 8);
    final entries = buildTimeline(
      now: now,
      profiles: [profile('work', isDefault: true)],
      schedules: const [],
      defaultProfileId: 'work',
    );
    expect(entries.length, 1);
    expect(entries.first.effectiveAt, now);
  });

  test('adds one entry per boundary across a week', () {
    final now = DateTime(2026, 11, 16, 8);
    final entries = buildTimeline(
      now: now,
      profiles: [profile('work', isDefault: true)],
      schedules: [
        schedule(days: {DateTime.monday, DateTime.wednesday}),
      ],
      defaultProfileId: 'work',
    );
    expect(entries.length, greaterThan(10));
    expect(entries[1].effectiveAt, DateTime(2026, 11, 16, 9));
    expect(entries[2].effectiveAt, DateTime(2026, 11, 16, 17));
    expect(entries[3].effectiveAt, DateTime(2026, 11, 18, 9));
  });

  test('includes the post-expiry state when protection ends', () {
    final entries = buildTimeline(
      now: DateTime(2026, 11, 16, 9),
      profiles: [profile('work', isDefault: true)],
      schedules: [schedule(days: {DateTime.monday})],
      defaultProfileId: 'work',
      protection: Protection(
        expiresAt: DateTime(2026, 11, 16, 18),
        softenedCategories: {Category.breakup},
      ),
    );
    final atExpiry =
        entries.firstWhere((e) => e.effectiveAt == DateTime(2026, 11, 16, 18));
    expect(atExpiry.state.protection, isNull);
    expect(entries[1].state.protection, isNotNull);
  });

  test('filter categories are the profile levels plus protection', () {
    final state = resolveActiveState(
      now: DateTime(2026, 11, 16, 9),
      profiles: [
        profile('work', isDefault: true, categoryLevels: {Category.breakup: Level.hide}),
      ],
      schedules: const [],
      defaultProfileId: 'work',
      protection: Protection(
        expiresAt: DateTime(2026, 11, 16, 23),
        softenedCategories: {Category.angerAggression},
      ),
    );
    expect(resolveFilterCategories(state),
        {Category.breakup, Category.angerAggression});
  });

  test('filter categories are empty when nothing is reduced or hidden', () {
    final state = resolveActiveState(
      now: DateTime(2026, 11, 16, 9),
      profiles: [
        profile('work', isDefault: true, categoryLevels: {Category.breakup: Level.allow}),
      ],
      schedules: const [],
      defaultProfileId: 'work',
    );
    expect(resolveFilterCategories(state), isEmpty);
  });

  test('serialises to the spec payload shape', () {
    final now = DateTime(2026, 11, 16, 9);
    final entries = buildTimeline(
      now: now,
      profiles: [
        profile('work', isDefault: true, categoryLevels: {Category.breakup: Level.hide}),
      ],
      schedules: const [],
      defaultProfileId: 'work',
    );
    final json = timelineToJson(entries);
    expect(json['v'], 1);
    expect(json['generatedAt'], now.millisecondsSinceEpoch);
    final first = json['states'][0] as Map<String, dynamic>;
    expect(first['surfaces']['feed'], 'hide');
    expect(first['filterCategories'], ['breakup']);
    expect(first['protection'], isNull);
  });
}
