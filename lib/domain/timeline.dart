import '../models.dart';
import 'resolver.dart';

/// One resolved state and the instant it takes effect.
class TimelineEntry {
  const TimelineEntry({required this.effectiveAt, required this.state});

  final DateTime effectiveAt;
  final ActiveState state;
}

/// The resolver sampled forward: every boundary until 30 days or 32 entries.
/// The pack needs no clock and no scheduler of its own — it just reads this.
List<TimelineEntry> buildTimeline({
  required DateTime now,
  required List<Profile> profiles,
  required List<Schedule> schedules,
  required String defaultProfileId,
  Pin? pin,
  Protection? protection,
}) {
  final entries = <TimelineEntry>[];
  final limit = now.add(const Duration(days: 30));
  var t = now;

  while (entries.length < 32) {
    final state = resolveActiveState(
      now: t,
      profiles: profiles,
      schedules: schedules,
      defaultProfileId: defaultProfileId,
      pin: pin,
      protection: protection,
    );
    entries.add(TimelineEntry(effectiveAt: t, state: state));

    final next = state.nextChangeAt;
    if (next == null || next.isAfter(limit)) break;
    t = next;
  }

  return entries;
}

/// What the pack drops: the mode's own reduced/hidden categories plus whatever
/// protection softens. Resolved here so the pack never sees `categoryLevels`.
Set<Category> resolveFilterCategories(ActiveState state) {
  final categories = <Category>{
    for (final entry in state.baseProfile.categoryLevels.entries)
      if (entry.value != Level.allow) entry.key,
  };
  final protection = state.protection;
  if (protection != null) categories.addAll(protection.softenedCategories);
  return categories;
}

/// The pushed payload. Enum values are the Dart `name`, so the pack and the app
/// share one spelling.
Map<String, dynamic> timelineToJson(List<TimelineEntry> entries) {
  return {
    'v': 1,
    'generatedAt': entries.first.effectiveAt.millisecondsSinceEpoch,
    'states': [
      for (final entry in entries)
        {
          'effectiveAt': entry.effectiveAt.millisecondsSinceEpoch,
          'base': entry.state.baseProfile.id,
          'reason': entry.state.reason.name,
          'protection': entry.state.protection == null
              ? null
              : {
                  'expiresAt': entry.state.protection!.expiresAt.millisecondsSinceEpoch,
                  'softened': [
                    for (final c in entry.state.protection!.softenedCategories) c.name,
                  ],
                },
          'surfaces': {
            for (final surface in Surface.values)
              surface.name:
                  (entry.state.baseProfile.surfaces[surface] ?? Level.allow).name,
          },
          'followingOnly': entry.state.baseProfile.followingOnly,
          'filterCategories': [
            for (final c in resolveFilterCategories(entry.state)) c.name,
          ],
        },
    ],
  };
}
