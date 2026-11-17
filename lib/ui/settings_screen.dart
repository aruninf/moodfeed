import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../platform/usage_channel.dart';
import '../state/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dataProvider);
    final settings = data.settings;
    final packInstalled = ref.watch(packInstalledProvider).value ?? false;
    final usageAccess = ref.watch(usageAccessProvider).value;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ListTile(
          title: const Text('Default mode'),
          trailing: DropdownButton<String>(
            value: settings.defaultProfileId,
            items: [
              for (final p in data.profiles)
                DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            onChanged: (id) => _setDefault(ref, id),
          ),
        ),
        SwitchListTile(
          title: const Text('App-open reminder'),
          subtitle: const Text('Watches Instagram and Facebook'),
          value: settings.gateEnabled,
          onChanged: (value) => ref.read(dataProvider.notifier).update(
                (d) => d.copyWith(
                  settings: d.settings.copyWith(gateEnabled: value),
                ),
              ),
        ),
        ListTile(
          title: const Text('Usage access'),
          subtitle: Text(
            usageAccess == false
                ? 'Off — MoodFeed cannot tell when Instagram opens.'
                : 'On — MoodFeed can see which app came to the front.',
          ),
          trailing: usageAccess == false
              ? TextButton(
                  onPressed: () async {
                    await const MoodFeedPlatform().openUsageAccessSettings();
                    ref.invalidate(usageAccessProvider);
                  },
                  child: const Text('Grant'),
                )
              : null,
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('Protection topics',
              style: Theme.of(context).textTheme.titleMedium),
        ),
        for (final category in const [
          Category.relationshipConflict,
          Category.breakup,
          Category.angerAggression,
        ])
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_label(category.name)),
            value: settings.protectionDefaults.contains(category),
            onChanged: (on) => ref.read(dataProvider.notifier).update(
                  (d) => d.copyWith(
                    settings: d.settings.copyWith(
                      protectionDefaults: {
                        for (final c in d.settings.protectionDefaults)
                          if (c != category) c,
                        if (on == true) category,
                      },
                    ),
                  ),
                ),
          ),
        SwitchListTile(
          title: const Text('Remember what the gate showed'),
          value: settings.counterOptIn,
          onChanged: (value) => ref.read(dataProvider.notifier).update(
                (d) => d.copyWith(
                  settings: d.settings.copyWith(counterOptIn: value),
                ),
              ),
        ),
        const Divider(),
        ListTile(
          title: const Text('MoodFeed pack'),
          subtitle: Text(packInstalled ? 'Installed' : 'Not installed'),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Everything stays on this device. No account, no server, no analytics.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  void _setDefault(WidgetRef ref, String? id) {
    if (id == null) return;
    ref.read(dataProvider.notifier).update(
          (d) => d.copyWith(
            profiles: [
              for (final p in d.profiles) p.copyWith(isDefault: p.id == id),
            ],
            settings: d.settings.copyWith(defaultProfileId: id),
          ),
        );
  }
}

/// `relationshipConflict` -> `Relationship conflict`.
String _label(String name) {
  final spaced = name.replaceAllMapped(
    RegExp('([A-Z])'),
    (match) => ' ${match.group(1)!.toLowerCase()}',
  );
  return spaced[0].toUpperCase() + spaced.substring(1);
}
