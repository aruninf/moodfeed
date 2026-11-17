/// The content taxonomy. The MVP classifies nothing; the labels exist so a mode
/// carries meaning and the gate can name what is being softened.
enum Category {
  romantic,
  suggestive,
  relationshipConflict,
  breakup,
  angerAggression,
  comedy,
  educational,
  newsTech,
}

/// How a mode treats one surface or one category.
enum Level { allow, reduce, hide }

/// Surfaces the pack can remove or filter.
enum Surface {
  feed,
  reels,
  explore,
  stories,
  suggested,
  ads,
  notes,
  instants,
  threadsButton,
}

/// Why the current mode is active.
enum Reason { pinned, scheduled, defaultProfile }

class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.categoryLevels,
    required this.surfaces,
    required this.followingOnly,
    required this.isDefault,
  });

  final String id;
  final String name;
  final int icon;
  final int color;
  final Map<Category, Level> categoryLevels;
  final Map<Surface, Level> surfaces;
  final bool followingOnly;
  final bool isDefault;

  Profile copyWith({
    String? name,
    Map<Category, Level>? categoryLevels,
    Map<Surface, Level>? surfaces,
    bool? followingOnly,
    bool? isDefault,
  }) =>
      Profile(
        id: id,
        name: name ?? this.name,
        icon: icon,
        color: color,
        categoryLevels: categoryLevels ?? this.categoryLevels,
        surfaces: surfaces ?? this.surfaces,
        followingOnly: followingOnly ?? this.followingOnly,
        isDefault: isDefault ?? this.isDefault,
      );
}

class Schedule {
  const Schedule({
    required this.id,
    required this.profileId,
    required this.daysOfWeek,
    required this.startMinute,
    required this.endMinute,
    required this.priority,
    required this.enabled,
    required this.updatedAt,
  });

  final String id;
  final String profileId;

  /// `DateTime.monday` … `DateTime.sunday`.
  final Set<int> daysOfWeek;
  final int startMinute;
  final int endMinute;
  final int priority;
  final bool enabled;
  final DateTime updatedAt;
}

class Pin {
  const Pin({
    required this.profileId,
    required this.startedAt,
    required this.expiresAt,
  });

  final String profileId;
  final DateTime startedAt;

  /// Null means no boundary exists within seven days, so the pin holds.
  final DateTime? expiresAt;
}

class Protection {
  const Protection({
    required this.expiresAt,
    required this.softenedCategories,
  });

  final DateTime expiresAt;
  final Set<Category> softenedCategories;
}

class ActiveState {
  const ActiveState({
    required this.baseProfile,
    required this.reason,
    required this.protection,
    required this.nextChangeAt,
  });

  final Profile baseProfile;
  final Reason reason;
  final Protection? protection;
  final DateTime? nextChangeAt;
}
