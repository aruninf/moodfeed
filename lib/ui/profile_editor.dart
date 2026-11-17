import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../state/providers.dart';

class ProfileEditor extends ConsumerStatefulWidget {
  const ProfileEditor({required this.profile, super.key});

  final Profile profile;

  @override
  ConsumerState<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends ConsumerState<ProfileEditor> {
  late Profile _profile = widget.profile;

  void _persist(Profile next) {
    setState(() => _profile = next);
    ref.read(dataProvider.notifier).update(
          (data) => data.copyWith(
            profiles: [
              for (final p in data.profiles) p.id == next.id ? next : p,
            ],
          ),
        );
  }

  void _makeDefault() {
    _persist(_profile.copyWith(isDefault: true));
    ref.read(dataProvider.notifier).update(
          (data) => data.copyWith(
            profiles: [
              for (final p in data.profiles)
                p.id == _profile.id
                    ? p.copyWith(isDefault: true)
                    : p.copyWith(isDefault: false),
            ],
            settings: data.settings.copyWith(defaultProfileId: _profile.id),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_profile.name)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            initialValue: _profile.name,
            decoration: const InputDecoration(labelText: 'Name'),
            onChanged: (value) => _persist(_profile.copyWith(name: value)),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            key: const Key('make-default'),
            title: const Text('Use as default'),
            value: _profile.isDefault,
            onChanged: (value) => value ? _makeDefault() : null,
          ),
          SwitchListTile(
            key: const Key('following-only'),
            title: const Text('Following accounts only'),
            subtitle: const Text('Restricts the feed instead of hiding it'),
            value: _profile.followingOnly,
            onChanged: (value) => _persist(_profile.copyWith(followingOnly: value)),
          ),
          const SizedBox(height: 16),
          Text('Surfaces', style: Theme.of(context).textTheme.titleMedium),
          for (final surface in Surface.values)
            _LevelRow(
              key: Key('surface-${surface.name}'),
              label: _label(surface.name),
              value: _profile.surfaces[surface] ?? Level.allow,
              onChanged: (level) => _persist(
                _profile.copyWith(surfaces: {..._profile.surfaces, surface: level}),
              ),
            ),
          const SizedBox(height: 16),
          Text('Categories', style: Theme.of(context).textTheme.titleMedium),
          for (final category in Category.values)
            _LevelRow(
              key: Key('category-${category.name}'),
              label: _label(category.name),
              value: _profile.categoryLevels[category] ?? Level.allow,
              onChanged: (level) => _persist(
                _profile.copyWith(
                  categoryLevels: {..._profile.categoryLevels, category: level},
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final Level value;
  final ValueChanged<Level> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          SegmentedButton<Level>(
            segments: const [
              ButtonSegment(value: Level.allow, label: Text('Allow')),
              ButtonSegment(value: Level.reduce, label: Text('Reduce')),
              ButtonSegment(value: Level.hide, label: Text('Hide')),
            ],
            selected: {value},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => onChanged(selection.single),
          ),
        ],
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
