import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

/// One row per gate notification the user acted on. Capped so the store cannot
/// grow without bound; nothing leaves the device.
class GateEvent {
  const GateEvent({
    required this.ts,
    required this.packageName,
    required this.action,
    required this.profileId,
    required this.protectionOn,
  });

  final DateTime ts;
  final String packageName;

  /// `closed` or `continued`.
  final String action;
  final String profileId;
  final bool protectionOn;

  Map<String, dynamic> toJson() => {
        'ts': ts.millisecondsSinceEpoch,
        'packageName': packageName,
        'action': action,
        'profileId': profileId,
        'protectionOn': protectionOn,
      };

  factory GateEvent.fromJson(Map<String, dynamic> json) => GateEvent(
        ts: DateTime.fromMillisecondsSinceEpoch(json['ts'] as int? ?? 0),
        packageName: json['packageName'] as String? ?? '',
        action: json['action'] as String? ?? 'continued',
        profileId: json['profileId'] as String? ?? '',
        protectionOn: json['protectionOn'] as bool? ?? false,
      );
}

class Settings {
  const Settings({
    required this.defaultProfileId,
    required this.gateEnabled,
    required this.protectionDefaults,
    required this.counterOptIn,
  });

  final String defaultProfileId;
  final bool gateEnabled;
  final Set<Category> protectionDefaults;
  final bool counterOptIn;

  Settings copyWith({
    String? defaultProfileId,
    bool? gateEnabled,
    Set<Category>? protectionDefaults,
    bool? counterOptIn,
  }) =>
      Settings(
        defaultProfileId: defaultProfileId ?? this.defaultProfileId,
        gateEnabled: gateEnabled ?? this.gateEnabled,
        protectionDefaults: protectionDefaults ?? this.protectionDefaults,
        counterOptIn: counterOptIn ?? this.counterOptIn,
      );

  Map<String, dynamic> toJson() => {
        'defaultProfileId': defaultProfileId,
        'gateEnabled': gateEnabled,
        'protectionDefaults': [for (final c in protectionDefaults) c.name],
        'counterOptIn': counterOptIn,
      };

  factory Settings.fromJson(Map<String, dynamic> json, Settings fallback) =>
      Settings(
        defaultProfileId: json['defaultProfileId'] as String? ?? fallback.defaultProfileId,
        gateEnabled: json['gateEnabled'] as bool? ?? fallback.gateEnabled,
        protectionDefaults: _categories(json['protectionDefaults']) ??
            fallback.protectionDefaults,
        counterOptIn: json['counterOptIn'] as bool? ?? fallback.counterOptIn,
      );
}

class MoodData {
  const MoodData({
    required this.profiles,
    required this.schedules,
    required this.pin,
    required this.protection,
    required this.settings,
    required this.gateEvents,
  });

  final List<Profile> profiles;
  final List<Schedule> schedules;
  final Pin? pin;
  final Protection? protection;
  final Settings settings;
  final List<GateEvent> gateEvents;

  static const _conflictCategories = {
    Category.relationshipConflict,
    Category.breakup,
    Category.angerAggression,
  };

  static MoodData defaults() {
    const allHidden = {
      Surface.feed: Level.hide,
      Surface.reels: Level.hide,
      Surface.explore: Level.hide,
      Surface.stories: Level.allow,
      Surface.suggested: Level.hide,
      Surface.ads: Level.hide,
      Surface.notes: Level.hide,
      Surface.instants: Level.hide,
      Surface.threadsButton: Level.hide,
    };
    return MoodData(
      profiles: const [
        Profile(
          id: 'work',
          name: 'Work',
          icon: 0xe0be,
          color: 0xff4c6ef5,
          categoryLevels: {},
          surfaces: allHidden,
          followingOnly: false,
          isDefault: false,
        ),
        Profile(
          id: 'public',
          name: 'Public',
          icon: 0xe57e,
          color: 0xff12b886,
          categoryLevels: {},
          surfaces: allHidden,
          followingOnly: false,
          isDefault: false,
        ),
        Profile(
          id: 'private',
          name: 'Private',
          icon: 0xe32e,
          color: 0xfff76707,
          categoryLevels: {},
          surfaces: {
            Surface.feed: Level.reduce,
            Surface.explore: Level.hide,
          },
          followingOnly: false,
          isDefault: false,
        ),
        Profile(
          id: 'relax',
          name: 'Relax',
          icon: 0xe226,
          color: 0xffae3ec9,
          categoryLevels: {},
          surfaces: {
            Surface.reels: Level.hide,
            Surface.explore: Level.hide,
            Surface.ads: Level.hide,
          },
          followingOnly: true,
          isDefault: true,
        ),
      ],
      schedules: [
        Schedule(
          id: 'weekday-work',
          profileId: 'work',
          daysOfWeek: const {
            DateTime.monday,
            DateTime.tuesday,
            DateTime.wednesday,
            DateTime.thursday,
            DateTime.friday,
          },
          startMinute: 540,
          endMinute: 1020,
          priority: 0,
          enabled: true,
          updatedAt: DateTime(2026, 11, 16),
        ),
      ],
      pin: null,
      protection: null,
      settings: const Settings(
        defaultProfileId: 'relax',
        gateEnabled: true,
        protectionDefaults: _conflictCategories,
        counterOptIn: false,
      ),
      gateEvents: const [],
    );
  }

  MoodData copyWith({
    List<Profile>? profiles,
    List<Schedule>? schedules,
    Pin? pin,
    bool clearPin = false,
    Protection? protection,
    bool clearProtection = false,
    Settings? settings,
    List<GateEvent>? gateEvents,
  }) =>
      MoodData(
        profiles: profiles ?? this.profiles,
        schedules: schedules ?? this.schedules,
        pin: clearPin ? null : pin ?? this.pin,
        protection: clearProtection ? null : protection ?? this.protection,
        settings: settings ?? this.settings,
        gateEvents: gateEvents ?? this.gateEvents,
      );

  Map<String, dynamic> toJson() => {
        'profiles': [for (final p in profiles) _profileToJson(p)],
        'schedules': [for (final s in schedules) _scheduleToJson(s)],
        'pin': pin == null ? null : _pinToJson(pin!),
        'protection': protection == null ? null : _protectionToJson(protection!),
        'settings': settings.toJson(),
        'gateEvents': [for (final e in gateEvents) e.toJson()],
      };

  /// Missing or malformed keys fall back to `defaults()`, so a half-written
  /// document can never wipe the user's profiles.
  factory MoodData.fromJson(Map<String, dynamic> json) {
    final fallback = defaults();
    return MoodData(
      profiles: _list(json['profiles'], _profileFromJson) ?? fallback.profiles,
      schedules: _list(json['schedules'], _scheduleFromJson) ?? fallback.schedules,
      pin: _one(json['pin'], _pinFromJson),
      protection: _one(json['protection'], _protectionFromJson),
      settings: json['settings'] is Map<String, dynamic>
          ? Settings.fromJson(json['settings'] as Map<String, dynamic>, fallback.settings)
          : fallback.settings,
      gateEvents: _list(json['gateEvents'], GateEvent.fromJson) ?? const [],
    );
  }
}

class Store {
  Store(this._prefs);

  static const key = 'moodfeed.v1';
  static const _maxGateEvents = 500;

  final SharedPreferences _prefs;

  SharedPreferences get prefs => _prefs;

  Future<MoodData> load() async {
    final raw = _prefs.getString(key);
    if (raw == null) return MoodData.defaults();
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return MoodData.defaults();
      return MoodData.fromJson(json);
    } catch (_) {
      return MoodData.defaults();
    }
  }

  Future<void> save(MoodData data) async {
    final events = data.gateEvents.length > _maxGateEvents
        ? data.gateEvents.sublist(data.gateEvents.length - _maxGateEvents)
        : data.gateEvents;
    await _prefs.setString(
      key,
      jsonEncode(data.copyWith(gateEvents: events).toJson()),
    );
  }
}

Map<String, dynamic> _profileToJson(Profile p) => {
      'id': p.id,
      'name': p.name,
      'icon': p.icon,
      'color': p.color,
      'categoryLevels': {
        for (final e in p.categoryLevels.entries) e.key.name: e.value.name,
      },
      'surfaces': {
        for (final e in p.surfaces.entries) e.key.name: e.value.name,
      },
      'followingOnly': p.followingOnly,
      'isDefault': p.isDefault,
    };

Profile _profileFromJson(Map<String, dynamic> json) => Profile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      icon: json['icon'] as int? ?? 0,
      color: json['color'] as int? ?? 0,
      categoryLevels: _levels(json['categoryLevels'], Category.values),
      surfaces: _levels(json['surfaces'], Surface.values),
      followingOnly: json['followingOnly'] as bool? ?? false,
      isDefault: json['isDefault'] as bool? ?? false,
    );

Map<String, dynamic> _scheduleToJson(Schedule s) => {
      'id': s.id,
      'profileId': s.profileId,
      'daysOfWeek': s.daysOfWeek.toList()..sort(),
      'startMinute': s.startMinute,
      'endMinute': s.endMinute,
      'priority': s.priority,
      'enabled': s.enabled,
      'updatedAt': s.updatedAt.millisecondsSinceEpoch,
    };

Schedule _scheduleFromJson(Map<String, dynamic> json) => Schedule(
      id: json['id'] as String? ?? '',
      profileId: json['profileId'] as String? ?? '',
      daysOfWeek: {
        for (final day in (json['daysOfWeek'] as List? ?? const []))
          if (day is int) day,
      },
      startMinute: json['startMinute'] as int? ?? 0,
      endMinute: json['endMinute'] as int? ?? 0,
      priority: json['priority'] as int? ?? 0,
      enabled: json['enabled'] as bool? ?? true,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int? ?? 0),
    );

Map<String, dynamic> _pinToJson(Pin p) => {
      'profileId': p.profileId,
      'startedAt': p.startedAt.millisecondsSinceEpoch,
      'expiresAt': p.expiresAt?.millisecondsSinceEpoch,
    };

Pin _pinFromJson(Map<String, dynamic> json) {
  final expiresAt = json['expiresAt'] as int?;
  return Pin(
    profileId: json['profileId'] as String? ?? '',
    startedAt: DateTime.fromMillisecondsSinceEpoch(json['startedAt'] as int? ?? 0),
    expiresAt: expiresAt == null ? null : DateTime.fromMillisecondsSinceEpoch(expiresAt),
  );
}

Map<String, dynamic> _protectionToJson(Protection p) => {
      'expiresAt': p.expiresAt.millisecondsSinceEpoch,
      'softenedCategories': [for (final c in p.softenedCategories) c.name],
    };

Protection _protectionFromJson(Map<String, dynamic> json) => Protection(
      expiresAt: DateTime.fromMillisecondsSinceEpoch(json['expiresAt'] as int? ?? 0),
      softenedCategories: _categories(json['softenedCategories']) ?? const {},
    );

Map<T, Level> _levels<T extends Enum>(Object? raw, List<T> values) {
  if (raw is! Map) return {};
  final lookup = {for (final v in values) v.name: v};
  final result = <T, Level>{};
  for (final entry in raw.entries) {
    final key = lookup[entry.key];
    if (key == null) continue;
    for (final level in Level.values) {
      if (level.name == entry.value) result[key] = level;
    }
  }
  return result;
}

Set<Category>? _categories(Object? raw) {
  if (raw is! List) return null;
  final lookup = {for (final c in Category.values) c.name: c};
  final result = <Category>{};
  for (final name in raw) {
    final category = lookup[name];
    if (category != null) result.add(category);
  }
  return result;
}

List<T>? _list<T>(Object? raw, T Function(Map<String, dynamic>) parse) {
  if (raw is! List) return null;
  final result = <T>[];
  for (final item in raw) {
    if (item is Map<String, dynamic>) result.add(parse(item));
  }
  return result;
}

T? _one<T>(Object? raw, T Function(Map<String, dynamic>) parse) =>
    raw is Map<String, dynamic> ? parse(raw) : null;
