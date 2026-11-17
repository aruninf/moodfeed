import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ui/home_screen.dart';
import 'ui/profiles_screen.dart';

class MoodFeedApp extends ConsumerStatefulWidget {
  const MoodFeedApp({super.key});

  @override
  ConsumerState<MoodFeedApp> createState() => _MoodFeedAppState();
}

class _MoodFeedAppState extends ConsumerState<MoodFeedApp> {
  int _index = 0;

  // shortcut: real screens arrive in Tasks 5-9, placeholders keep the shell
  // runnable meanwhile.
  static const _titles = ['MoodFeed', 'Modes', 'Schedule', 'Settings'];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MoodFeed',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xffae3ec9),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(title: Text(_titles[_index])),
        body: switch (_index) {
          0 => const HomeScreen(),
          1 => const ProfilesScreen(),
          _ => Center(child: Text(_titles[_index])),
        },
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.tune), label: 'Modes'),
            NavigationDestination(icon: Icon(Icons.calendar_today), label: 'Schedule'),
            NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}
