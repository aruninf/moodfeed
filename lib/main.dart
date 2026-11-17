import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/store.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = Store(await SharedPreferences.getInstance());
  final data = await store.load();
  runApp(
    ProviderScope(
      overrides: [
        storeProvider.overrideWithValue(store),
        initialDataProvider.overrideWithValue(data),
      ],
      child: const MoodFeedApp(),
    ),
  );
}
