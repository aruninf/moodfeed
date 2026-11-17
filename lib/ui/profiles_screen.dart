import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../state/providers.dart';
import 'profile_editor.dart';

class ProfilesScreen extends ConsumerWidget {
  const ProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(dataProvider).profiles;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final profile in profiles)
          Card(
            child: ListTile(
              leading: Text(
                String.fromCharCode(profile.icon),
                style: const TextStyle(fontFamily: 'MaterialIcons', fontSize: 24),
              ),
              title: Text(profile.name),
              subtitle: Text(_summary(profile)),
              trailing: profile.isDefault ? const Text('Default') : null,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProfileEditor(profile: profile),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String _summary(Profile profile) {
  final hidden = profile.surfaces.values.where((l) => l == Level.hide).length;
  final parts = <String>[
    if (hidden > 0) '$hidden surfaces hidden',
    if (profile.followingOnly) 'following only',
  ];
  return parts.isEmpty ? 'Everything on' : parts.join(' · ');
}
