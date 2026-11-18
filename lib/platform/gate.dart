import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/store.dart';
import 'usage_channel.dart';

/// Apps whose opening is worth a reminder. The clone pack is deliberately
/// absent — it obeys the pushed mode instead of being gated.
const watchedPackages = {
  'com.instagram.android',
  'com.instagram.android.lite',
  'com.facebook.katana',
  'com.facebook.katana.orca',
};

/// The dismissible ceiling from spec v1 §7.4: name the mode, offer to leave,
/// never pretend to block.
class Gate {
  Gate(
    this._prefs, {
    this._platform = const MoodFeedPlatform(),
  });

  static const _lastKey = 'moodfeed.gate.last';
  static const _modeKey = 'moodfeed.gate.mode';
  static const _profileKey = 'moodfeed.gate.profile';
  static const _protectingKey = 'moodfeed.gate.protecting';
  static const _cooldown = Duration(minutes: 90);
  static const _gateId = 1001;
  static const _degradedId = 1002;

  final SharedPreferences _prefs;
  final MoodFeedPlatform _platform;
  final _notifications = FlutterLocalNotificationsPlugin();
  bool _configured = false;

  Future<void> configure() async {
    if (_configured) return;
    _configured = true;

    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: _onResponse,
    );

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'moodfeed.gate.service',
        channelName: 'MoodFeed',
        channelDescription: 'Keeps the app-open reminder running.',
        channelImportance: NotificationChannelImportance.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
      ),
    );
    FlutterForegroundTask.setTaskHandler(_GateTaskHandler());

    final permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  /// Decides whether the service runs and what the handler will say.
  Future<void> sync({
    required bool enabled,
    required bool packInstalled,
    required bool usageAccess,
    required String modeName,
    required String profileId,
    required bool protecting,
  }) async {
    await configure();
    await _prefs.setString(_modeKey, modeName);
    await _prefs.setString(_profileKey, profileId);
    await _prefs.setBool(_protectingKey, protecting);

    if (!usageAccess) {
      await stop();
      await _showDegraded();
      return;
    }
    await _notifications.cancel(id: _degradedId);

    if (!enabled || packInstalled) {
      await stop();
      return;
    }
    if (!await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.startService(
        notificationTitle: 'MoodFeed is watching',
        notificationText: 'Names the mode when Instagram or Facebook opens',
        serviceTypes: [ForegroundServiceTypes.specialUse],
        callback: _startCallback,
      );
    }
  }

  Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  /// One poll: has the foreground app changed, and is it worth a reminder?
  Future<void> tick() async {
    final package = await _platform.foregroundPackage();
    if (package == _prefs.getString(_lastKey)) return;
    await _prefs.setString(_lastKey, package ?? '');
    if (package == null || !watchedPackages.contains(package)) return;

    final notified = _prefs.getInt('moodfeed.gate.notified.$package') ?? 0;
    final now = DateTime.now();
    final testMode = _prefs.getBool('moodfeed.gate.test_mode') ?? false;
    final cooldownMs = testMode ? 5000 : _cooldown.inMilliseconds;
    if (now.millisecondsSinceEpoch - notified < cooldownMs) {
      return;
    }
    await _prefs.setInt(
      'moodfeed.gate.notified.$package',
      now.millisecondsSinceEpoch,
    );
    await _showGate(package);
  }

  /// Clears the cooldown so the next Instagram open triggers the gate immediately.
  Future<void> clearCooldown() async {
    for (final pkg in watchedPackages) {
      await _prefs.remove('moodfeed.gate.notified.$pkg');
    }
    await _prefs.remove(_lastKey);
  }

  /// Sends a one-off test reminder to verify notifications and buttons on device.
  Future<void> showTestReminder() async {
    await configure();
    await _showGate('com.instagram.android');
  }

  Future<void> _showGate(String package) async {
    final mode = _prefs.getString(_modeKey) ?? 'your mode';
    final protecting = _prefs.getBool(_protectingKey) ?? false;
    await _notifications.show(
      id: _gateId,
      title: '$mode is active',
      body: protecting
          ? 'Protection is on. This is a reminder, not a block.'
          : 'This is a reminder, not a block.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'moodfeed.gate',
          'App-open reminder',
          channelDescription: 'Names your mode when a watched app opens.',
          importance: Importance.high,
          priority: Priority.high,
          actions: [
            AndroidNotificationAction('close', 'Close app'),
            AndroidNotificationAction('continue', 'Continue'),
          ],
        ),
      ),
      payload: package,
    );
  }

  Future<void> _showDegraded() async {
    await _notifications.show(
      id: _degradedId,
      title: 'Usage access is off',
      body: 'MoodFeed cannot tell when Instagram opens.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'moodfeed.gate.degraded',
          'MoodFeed degraded mode',
          channelDescription: 'Shown while usage access is missing.',
          importance: Importance.low,
          priority: Priority.low,
          ongoing: true,
          autoCancel: false,
        ),
      ),
    );
  }

  Future<void> _onResponse(NotificationResponse response) async {
    if (response.actionId == 'close') {
      await _platform.closeForegroundApp();
    }
    final action = response.actionId == 'close' ? 'closed' : 'continued';

    final store = Store(_prefs);
    final data = await store.load();
    if (!data.settings.counterOptIn) return;
    await store.save(
      data.copyWith(
        gateEvents: [
          ...data.gateEvents,
          GateEvent(
            ts: DateTime.now(),
            packageName: response.payload ?? '',
            action: action,
            profileId: _prefs.getString(_profileKey) ?? '',
            protectionOn: _prefs.getBool(_protectingKey) ?? false,
          ),
        ],
      ),
    );
  }
}

class _GateTaskHandler extends TaskHandler {
  Gate? _gate;

  Future<void> _tick() async {
    _gate ??= Gate(await SharedPreferences.getInstance());
    await _gate!.tick();
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {
    _tick();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

@pragma('vm:entry-point')
void _startCallback() {
  FlutterForegroundTask.setTaskHandler(_GateTaskHandler());
}
