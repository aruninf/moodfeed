import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moodfeed/data/store.dart';
import 'package:moodfeed/platform/pack_bridge.dart';
import 'package:moodfeed/platform/usage_channel.dart';

class FakePlatform extends MoodFeedPlatform {
  FakePlatform({required this.installed});

  final bool installed;
  final pushes = <String>[];

  @override
  Future<bool> isPackInstalled() async => installed;

  @override
  Future<bool> pushTimeline(String json) async {
    pushes.add(json);
    return true;
  }
}

void main() {
  final now = DateTime(2026, 11, 16, 9);

  test('pushes the serialised timeline when the pack is installed', () async {
    final platform = FakePlatform(installed: true);

    await PackBridge(platform: platform).push(MoodData.defaults(), now);

    expect(platform.pushes.length, 1);
    final payload = jsonDecode(platform.pushes.single) as Map<String, dynamic>;
    final states = payload['states'] as List;
    expect(states.length, greaterThanOrEqualTo(1));
    expect(states.first['effectiveAt'], lessThanOrEqualTo(now.millisecondsSinceEpoch));
  });

  test('does nothing when the pack is absent', () async {
    final platform = FakePlatform(installed: false);

    await PackBridge(platform: platform).push(MoodData.defaults(), now);

    expect(platform.pushes, isEmpty);
  });
}
