import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store.dart';
import '../models.dart';
import '../state/providers.dart';

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dataProvider);
    final profiles = {for (final p in data.profiles) p.id: p};
    final blocks = [...data.schedules]..sort((a, b) => a.startMinute.compareTo(b.startMinute));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Overlapping blocks are fine — the higher priority wins.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        for (final block in blocks)
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_days(block.daysOfWeek)),
                        Text(_window(block)),
                        Text(profiles[block.profileId]?.name ?? 'Missing mode'),
                        if (block.startMinute > block.endMinute)
                          const Text('Overnight'),
                      ],
                    ),
                  ),
                  Switch(
                    key: Key('enabled-${block.id}'),
                    value: block.enabled,
                    onChanged: (value) => ref.read(dataProvider.notifier).update(
                          (d) => d.copyWith(
                            schedules: [
                              for (final s in d.schedules)
                                s.id == block.id ? _enabled(s, value) : s,
                            ],
                          ),
                        ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        FilledButton.tonal(
          onPressed: () => _openEditor(context, ref, data),
          child: const Text('Add block'),
        ),
      ],
    );
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref, MoodData data) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BlockEditor(profiles: data.profiles),
    );
  }
}

Schedule _enabled(Schedule s, bool value) => Schedule(
      id: s.id,
      profileId: s.profileId,
      daysOfWeek: s.daysOfWeek,
      startMinute: s.startMinute,
      endMinute: s.endMinute,
      priority: s.priority,
      enabled: value,
      updatedAt: s.updatedAt,
    );

class _BlockEditor extends ConsumerStatefulWidget {
  const _BlockEditor({required this.profiles});

  final List<Profile> profiles;

  @override
  ConsumerState<_BlockEditor> createState() => _BlockEditorState();
}

class _BlockEditorState extends ConsumerState<_BlockEditor> {
  final Set<int> _days = {DateTime.monday};
  int _start = 540;
  int _end = 1020;
  int _priority = 0;
  late String _profileId = widget.profiles.first.id;

  Future<void> _pickTime({required bool start}) async {
    final current = start ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null) return;
    setState(() {
      final minute = picked.hour * 60 + picked.minute;
      if (start) {
        _start = minute;
      } else {
        _end = minute;
      }
    });
  }

  void _save() {
    final now = DateTime.now();
    ref.read(dataProvider.notifier).update(
          (data) => data.copyWith(
            schedules: [
              ...data.schedules,
              Schedule(
                id: now.microsecondsSinceEpoch.toString(),
                profileId: _profileId,
                daysOfWeek: {..._days},
                startMinute: _start,
                endMinute: _end,
                priority: _priority,
                enabled: true,
                updatedAt: now,
              ),
            ],
          ),
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New block', style: Theme.of(context).textTheme.titleMedium),
          Wrap(
            spacing: 4,
            children: [
              for (var day = DateTime.monday; day <= DateTime.sunday; day++)
                FilterChip(
                  label: Text(_shortDay(day)),
                  selected: _days.contains(day),
                  onSelected: (on) => setState(
                    () => on ? _days.add(day) : _days.remove(day),
                  ),
                ),
            ],
          ),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => _pickTime(start: true),
                child: Text(_time(_start)),
              ),
              const Text(' – '),
              OutlinedButton(
                onPressed: () => _pickTime(start: false),
                child: Text(_time(_end)),
              ),
            ],
          ),
          DropdownButton<String>(
            value: _profileId,
            items: [
              for (final p in widget.profiles)
                DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            onChanged: (value) => setState(() => _profileId = value!),
          ),
          Row(
            children: [
              const Text('Priority'),
              IconButton(
                onPressed: () => setState(() => _priority--),
                icon: const Icon(Icons.remove),
              ),
              Text('$_priority'),
              IconButton(
                onPressed: () => setState(() => _priority++),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          FilledButton(
            onPressed: _days.isEmpty ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _shortDay(int weekday) => _dayNames[weekday - 1];

String _days(Set<int> days) {
  final sorted = days.toList()..sort();
  if (sorted.length == 7) return 'Every day';
  if (sorted.length == 5 && sorted.first == 1 && sorted.last == 5) {
    return 'Mon–Fri';
  }
  return sorted.map(_shortDay).join(', ');
}

String _window(Schedule s) => '${_time(s.startMinute)} – ${_time(s.endMinute)}';

String _time(int minute) {
  final h = (minute ~/ 60).toString().padLeft(2, '0');
  final m = (minute % 60).toString().padLeft(2, '0');
  return '$h:$m';
}
