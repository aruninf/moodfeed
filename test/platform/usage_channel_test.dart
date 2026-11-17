import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodfeed/platform/usage_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(MoodFeedPlatform.channel);

  void mock(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, handler);
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('foregroundPackage returns the last resumed package', () async {
    mock((call) async => call.method == 'foregroundPackage' ? 'com.instagram.android' : null);

    expect(await MoodFeedPlatform().foregroundPackage(), 'com.instagram.android');
  });

  test('a null reply maps to null without throwing', () async {
    mock((call) async => null);

    expect(await MoodFeedPlatform().foregroundPackage(), isNull);
  });
}
