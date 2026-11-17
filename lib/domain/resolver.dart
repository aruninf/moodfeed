import '../models.dart';

/// The only place the active state is decided. Pure: same inputs, same answer.
///
/// Derived, never stored — killing the app, changing the clock or rebooting
/// cannot corrupt it, and the next switch needs no scheduler.
ActiveState resolveActiveState({
  required DateTime now,
  required List<Profile> profiles,
  required List<Schedule> schedules,
  required String defaultProfileId,
  Pin? pin,
  Protection? protection,
}) {
  final activePin =
      pin != null && (pin.expiresAt == null || pin.expiresAt!.isAfter(now))
          ? pin
          : null;
  final activeProtection =
      protection != null && protection.expiresAt.isAfter(now)
          ? protection
          : null;

  final byId = {for (final p in profiles) p.id: p};
  final matching = schedules
      .where((s) => s.enabled && byId.containsKey(s.profileId))
      .where((s) => _contains(s, now))
      .toList()
    ..sort((a, b) {
      final byPriority = b.priority.compareTo(a.priority);
      return byPriority != 0 ? byPriority : b.updatedAt.compareTo(a.updatedAt);
    });

  final Profile base;
  final Reason reason;
  if (activePin != null && byId.containsKey(activePin.profileId)) {
    base = byId[activePin.profileId]!;
    reason = Reason.pinned;
  } else if (matching.isNotEmpty) {
    base = byId[matching.first.profileId]!;
    reason = Reason.scheduled;
  } else {
    base = byId[defaultProfileId] ?? profiles.first;
    reason = Reason.defaultProfile;
  }

  return ActiveState(
    baseProfile: base,
    reason: reason,
    protection: activeProtection,
    nextChangeAt: _nextChangeAt(now, schedules, activePin, activeProtection),
  );
}

/// A wrapping window (start > end) belongs to the earlier weekday before
/// midnight and to that same weekday after midnight.
bool _contains(Schedule s, DateTime now) {
  final minute = now.hour * 60 + now.minute;
  final today = now.weekday;
  final yesterday = today == DateTime.monday ? DateTime.sunday : today - 1;

  if (s.startMinute < s.endMinute) {
    return s.daysOfWeek.contains(today) &&
        minute >= s.startMinute &&
        minute < s.endMinute;
  }
  if (s.startMinute > s.endMinute) {
    return (s.daysOfWeek.contains(today) && minute >= s.startMinute) ||
        (s.daysOfWeek.contains(yesterday) && minute < s.endMinute);
  }
  return false;
}

DateTime? _nextChangeAt(
  DateTime now,
  List<Schedule> schedules,
  Pin? pin,
  Protection? protection,
) {
  DateTime? next;

  void consider(DateTime? candidate) {
    if (candidate != null && candidate.isAfter(now)) {
      if (next == null || candidate.isBefore(next!)) next = candidate;
    }
  }

  for (final s in schedules.where((s) => s.enabled)) {
    for (var day = 0; day < 9; day++) {
      final date = DateTime(now.year, now.month, now.day + day);
      final previousWeekday =
          date.weekday == DateTime.monday ? DateTime.sunday : date.weekday - 1;

      if (s.startMinute < s.endMinute) {
        if (s.daysOfWeek.contains(date.weekday)) {
          consider(DateTime(date.year, date.month, date.day,
              s.startMinute ~/ 60, s.startMinute % 60));
          consider(DateTime(date.year, date.month, date.day,
              s.endMinute ~/ 60, s.endMinute % 60));
        }
      } else if (s.startMinute > s.endMinute) {
        // The window opens on an active day and closes on the following one.
        if (s.daysOfWeek.contains(date.weekday)) {
          consider(DateTime(date.year, date.month, date.day,
              s.startMinute ~/ 60, s.startMinute % 60));
        }
        if (s.daysOfWeek.contains(previousWeekday)) {
          consider(DateTime(date.year, date.month, date.day,
              s.endMinute ~/ 60, s.endMinute % 60));
        }
      }
    }
  }
  consider(pin?.expiresAt);
  consider(protection?.expiresAt);

  return next;
}
