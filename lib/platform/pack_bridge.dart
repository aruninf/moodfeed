import 'dart:convert';

import '../data/store.dart';
import '../domain/timeline.dart';
import 'usage_channel.dart';

/// MoodFeed is the brain; the pack only applies what it is told. One push
/// carries every boundary for the next month, so the pack needs no clock.
class PackBridge {
  const PackBridge({this.platform = const MoodFeedPlatform()});

  final MoodFeedPlatform platform;

  Future<void> push(MoodData data, DateTime now) async {
    if (!await platform.isPackInstalled()) return;

    final entries = buildTimeline(
      now: now,
      profiles: data.profiles,
      schedules: data.schedules,
      defaultProfileId: data.settings.defaultProfileId,
      pin: data.pin,
      protection: data.protection,
    );
    await platform.pushTimeline(jsonEncode(timelineToJson(entries)));
  }
}
