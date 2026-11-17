import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../state/providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeStateProvider);
    final data = ref.watch(dataProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final protection = state.protection;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          key: const Key('active-mode'),
          protection == null
              ? state.baseProfile.name
              : '${state.baseProfile.name} — protecting '
                  '${protection.softenedCategories.length} topics',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          switch (state.reason) {
            Reason.pinned => 'Pinned',
            Reason.scheduled => 'Scheduled',
            Reason.defaultProfile => 'Default mode',
          },
          style: Theme.of(context).textTheme.labelLarge,
        ),
        if (state.nextChangeAt != null) ...[
          const SizedBox(height: 4),
          Text(
            'Next switch in ${_remaining(state.nextChangeAt!, now)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (protection != null) ...[
          const SizedBox(height: 16),
          ActionChip(
            key: const Key('protection-badge'),
            avatar: const Icon(Icons.shield_outlined, size: 18),
            label: Text('Protection ends in ${_remaining(protection.expiresAt, now)}'),
            onPressed: () => ref
                .read(dataProvider.notifier)
                .update((d) => d.copyWith(clearProtection: true)),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          // Task 8 replaces this with showProtectionSheet.
          onPressed: () {},
          child: const Text('Protect my peace'),
        ),
        const SizedBox(height: 32),
        Text('Switch mode', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final profile in data.profiles)
              ActionChip(
                label: Text(profile.name),
                onPressed: () => _pin(ref, profile, state.nextChangeAt, now),
              ),
          ],
        ),
      ],
    );
  }

  void _pin(WidgetRef ref, Profile profile, DateTime? until, DateTime now) {
    ref.read(dataProvider.notifier).update(
          (d) => d.copyWith(
            pin: Pin(
              profileId: profile.id,
              startedAt: now,
              expiresAt: until,
            ),
          ),
        );
  }
}

/// `2h 14m`, `45m`, `3d 4h` — never a countdown to the second.
String _remaining(DateTime target, DateTime now) {
  final delta = target.difference(now);
  if (delta.inMinutes < 60) return '${delta.inMinutes}m';
  if (delta.inHours < 24) {
    return '${delta.inHours}h ${delta.inMinutes % 60}m';
  }
  return '${delta.inDays}d ${delta.inHours % 24}h';
}
