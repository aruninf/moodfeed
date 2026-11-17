import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../state/providers.dart';

/// The three topics protection may soften. `romantic` and `suggestive` are
/// absent, not disabled — a rough evening is not a reason to remove affection.
const _softenables = [
  Category.relationshipConflict,
  Category.breakup,
  Category.angerAggression,
];

const _durations = <String, Duration?>{
  '30m': Duration(minutes: 30),
  '2h': Duration(hours: 2),
  '4h': Duration(hours: 4),
  'Until morning': null,
};

Future<Protection?> showProtectionSheet(BuildContext context) {
  return showModalBottomSheet<Protection>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const ProtectionSheet(),
  );
}

class ProtectionSheet extends ConsumerStatefulWidget {
  const ProtectionSheet({super.key});

  @override
  ConsumerState<ProtectionSheet> createState() => _ProtectionSheetState();
}

class _ProtectionSheetState extends ConsumerState<ProtectionSheet> {
  String _duration = '2h';
  DateTime _now = DateTime.now();
  late final Set<Category> _selected = {
    ...ref.read(dataProvider).settings.protectionDefaults,
  };

  DateTime _expiry(DateTime now) {
    final duration = _durations[_duration];
    if (duration != null) return now.add(duration);
    final morning = DateTime(now.year, now.month, now.day, 7);
    return morning.isAfter(now) ? morning : DateTime(now.year, now.month, now.day + 1, 7);
  }

  void _confirm() {
    final protection = Protection(
      expiresAt: _expiry(_now),
      softenedCategories: {..._selected},
    );
    ref
        .read(dataProvider.notifier)
        .update((data) => data.copyWith(protection: protection));
    Navigator.of(context).pop(protection);
  }

  @override
  Widget build(BuildContext context) {
    _now = ref.watch(clockProvider).value ?? DateTime.now();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Protect my peace', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('Your mode stays the same. These topics step back.'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in _durations.entries)
                ChoiceChip(
                  label: Text(entry.key),
                  selected: _duration == entry.key,
                  onSelected: (_) => setState(() => _duration = entry.key),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (final category in _softenables)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_label(category.name)),
              value: _selected.contains(category),
              onChanged: (on) => setState(
                () => on == true ? _selected.add(category) : _selected.remove(category),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _selected.isEmpty ? null : _confirm,
            child: const Text('Protect'),
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
