import 'package:flutter/services.dart';

/// The two questions Kotlin answers, and the two commands it takes.
class MoodFeedPlatform {
  const MoodFeedPlatform();

  static const channel = 'com.moodfeed/platform';

  static const _methods = MethodChannel(channel);

  /// The package that most recently came to the foreground, or null.
  Future<String?> foregroundPackage() async {
    final result = await _methods.invokeMethod<String>('foregroundPackage');
    return result;
  }

  Future<bool> hasUsageAccess() async =>
      await _methods.invokeMethod<bool>('hasUsageAccess') ?? false;

  Future<void> openUsageAccessSettings() =>
      _methods.invokeMethod<void>('openUsageAccessSettings');

  /// Takes the user home. Android forbids one app killing another.
  Future<void> closeForegroundApp() =>
      _methods.invokeMethod<void>('closeForegroundApp');

  Future<bool> isPackInstalled() async =>
      await _methods.invokeMethod<bool>('isPackInstalled') ?? false;

  /// False when the pack is absent or signed with another key.
  Future<bool> pushTimeline(String json) async =>
      await _methods.invokeMethod<bool>('pushTimeline', {'json': json}) ?? false;
}
