import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'state/providers.dart';
import 'ui/home_screen.dart';
import 'ui/profiles_screen.dart';
import 'ui/schedule_screen.dart';
import 'ui/settings_screen.dart';

class MoodFeedApp extends ConsumerStatefulWidget {
  const MoodFeedApp({super.key});

  @override
  ConsumerState<MoodFeedApp> createState() => _MoodFeedAppState();
}

class _MoodFeedAppState extends ConsumerState<MoodFeedApp>
    with WidgetsBindingObserver {
  int _index = 0;

  static const _titles = ['MoodFeed', 'Modes', 'Schedule', 'Settings'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _sync();
  }

  /// The gate reads the mode from the store, so it only needs a nudge when the
  /// mode, the settings or a capability changes — not every clock tick.
  Future<void> _sync() async {
    await _syncGate();
    await ref.read(packBridgeProvider).push(
          ref.read(dataProvider),
          DateTime.now(),
        );
  }

  Future<void> _syncGate() async {
    final gate = ref.read(gateProvider);
    final data = ref.read(dataProvider);
    final active = ref.read(activeStateProvider);
    await gate.sync(
      enabled: data.settings.gateEnabled,
      packInstalled: await ref.read(packInstalledProvider.future),
      usageAccess: await ref.read(usageAccessProvider.future),
      modeName: active.baseProfile.name,
      profileId: active.baseProfile.id,
      protecting: active.protection != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(dataProvider, (_, _) => _sync());
    ref.listen(
      activeStateProvider.select((s) => (s.baseProfile.id, s.protection != null)),
      (_, _) => _syncGate(),
    );
    ref.listen(packInstalledProvider, (_, _) => _syncGate());
    ref.listen(usageAccessProvider, (_, _) => _syncGate());

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
          2 => const ScheduleScreen(),
          _ => const SettingsScreen(),
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
