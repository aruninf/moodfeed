import 'package:flutter_test/flutter_test.dart';
import 'package:moodfeed/models.dart';
import 'package:moodfeed/domain/resolver.dart';

Profile profile(
  String id, {
  bool isDefault = false,
  Map<Category, Level> categoryLevels = const {},
  Map<Surface, Level> surfaces = const {},
}) =>
    Profile(
      id: id,
      name: id,
      icon: 0,
      color: 0,
      categoryLevels: categoryLevels,
      surfaces: surfaces,
      followingOnly: false,
      isDefault: isDefault,
    );

Schedule schedule({
  String id = 's1',
  String profileId = 'work',
  required Set<int> days,
  required int start,
  required int end,
  int priority = 0,
  bool enabled = true,
  DateTime? updatedAt,
}) =>
    Schedule(
      id: id,
      profileId: profileId,
      daysOfWeek: days,
      startMinute: start,
      endMinute: end,
      priority: priority,
      enabled: enabled,
      updatedAt: updatedAt ?? DateTime(2026, 11, 1),
    );

ActiveState resolve(
  DateTime now, {
  List<Profile>? profiles,
  List<Schedule> schedules = const [],
  String defaultProfileId = 'work',
  Pin? pin,
  Protection? protection,
}) =>
    resolveActiveState(
      now: now,
      profiles: profiles ?? [profile('work', isDefault: true), profile('relax')],
      schedules: schedules,
      defaultProfileId: defaultProfileId,
      pin: pin,
      protection: protection,
    );

void main() {
  test('falls through to the default profile when nothing matches', () {
    final state = resolve(DateTime(2026, 11, 16, 9));
    expect(state.reason, Reason.defaultProfile);
    expect(state.baseProfile.id, 'work');
    expect(state.nextChangeAt, isNull);
  });

  test('matches a same-day window', () {
    final state = resolve(
      DateTime(2026, 11, 16, 9),
      schedules: [schedule(days: {DateTime.monday}, start: 540, end: 1020)],
    );
    expect(state.reason, Reason.scheduled);
    expect(state.baseProfile.id, 'work');
  });

  test('matches the pre-midnight part of a wrapping window', () {
    final state = resolve(
      DateTime(2026, 11, 16, 23),
      schedules: [schedule(days: {DateTime.monday}, start: 1320, end: 420)],
    );
    expect(state.reason, Reason.scheduled);
  });

  test('matches the post-midnight part of a wrapping window', () {
    final state = resolve(
      DateTime(2026, 11, 17, 2),
      schedules: [schedule(days: {DateTime.monday}, start: 1320, end: 420)],
    );
    expect(state.reason, Reason.scheduled);
  });

  test('does not match a window owned by the current weekday after midnight',
      () {
    final state = resolve(
      DateTime(2026, 11, 17, 2),
      schedules: [schedule(days: {DateTime.tuesday}, start: 1320, end: 420)],
    );
    expect(state.reason, Reason.defaultProfile);
  });

  test('higher priority wins an overlap', () {
    final state = resolve(
      DateTime(2026, 11, 16, 9),
      profiles: [profile('work'), profile('private'), profile('relax', isDefault: true)],
      defaultProfileId: 'relax',
      schedules: [
        schedule(id: 'a', profileId: 'work', days: {DateTime.monday}, start: 540, end: 1020),
        schedule(
            id: 'b',
            profileId: 'private',
            days: {DateTime.monday},
            start: 540,
            end: 1020,
            priority: 2),
      ],
    );
    expect(state.baseProfile.id, 'private');
  });

  test('most recently edited wins a priority tie', () {
    final state = resolve(
      DateTime(2026, 11, 16, 9),
      profiles: [profile('work'), profile('private'), profile('relax', isDefault: true)],
      defaultProfileId: 'relax',
      schedules: [
        schedule(
            id: 'a',
            profileId: 'work',
            days: {DateTime.monday},
            start: 540,
            end: 1020,
            updatedAt: DateTime(2026, 11, 10)),
        schedule(
            id: 'b',
            profileId: 'private',
            days: {DateTime.monday},
            start: 540,
            end: 1020,
            updatedAt: DateTime(2026, 11, 12)),
      ],
    );
    expect(state.baseProfile.id, 'private');
  });

  test('an active pin beats the schedule', () {
    final state = resolve(
      DateTime(2026, 11, 16, 9),
      profiles: [profile('work'), profile('private'), profile('relax', isDefault: true)],
      defaultProfileId: 'relax',
      schedules: [schedule(days: {DateTime.monday}, start: 540, end: 1020)],
      pin: Pin(
        profileId: 'private',
        startedAt: DateTime(2026, 11, 16, 8),
        expiresAt: DateTime(2026, 11, 16, 17),
      ),
    );
    expect(state.reason, Reason.pinned);
    expect(state.baseProfile.id, 'private');
  });

  test('an expired pin is ignored', () {
    final state = resolve(
      DateTime(2026, 11, 16, 9),
      schedules: [schedule(days: {DateTime.monday}, start: 540, end: 1020)],
      pin: Pin(
        profileId: 'private',
        startedAt: DateTime(2026, 11, 16, 7),
        expiresAt: DateTime(2026, 11, 16, 8),
      ),
    );
    expect(state.reason, Reason.scheduled);
    expect(state.baseProfile.id, 'work');
  });

  test('protection is a modifier, not a profile', () {
    final state = resolve(
      DateTime(2026, 11, 16, 21),
      profiles: [profile('work'), profile('relax', isDefault: true)],
      defaultProfileId: 'relax',
      protection: Protection(
        expiresAt: DateTime(2026, 11, 16, 23),
        softenedCategories: {
          Category.relationshipConflict,
          Category.breakup,
          Category.angerAggression,
        },
      ),
    );
    expect(state.baseProfile.id, 'relax');
    expect(state.protection, isNotNull);
    expect(state.protection!.softenedCategories.length, 3);
  });

  test('expired protection is ignored', () {
    final state = resolve(
      DateTime(2026, 11, 16, 21),
      protection: Protection(
        expiresAt: DateTime(2026, 11, 16, 20),
        softenedCategories: {Category.breakup},
      ),
    );
    expect(state.protection, isNull);
  });

  test('nextChangeAt is the next boundary', () {
    final state = resolve(
      DateTime(2026, 11, 16, 9),
      schedules: [schedule(days: {DateTime.monday}, start: 540, end: 1020)],
    );
    expect(state.nextChangeAt, DateTime(2026, 11, 16, 17));
  });

  test('resolves on both sides of a DST jump without throwing', () {
    final schedules = [
      schedule(days: {DateTime.sunday}, start: 120, end: 180),
    ];
    final before = resolve(DateTime(2026, 3, 29, 1, 30), schedules: schedules);
    final after = resolve(DateTime(2026, 3, 29, 3, 30), schedules: schedules);
    expect(before.baseProfile.id, isNotEmpty);
    expect(after.baseProfile.id, isNotEmpty);
  });
}
