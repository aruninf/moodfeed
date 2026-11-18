import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models.dart';
import '../platform/usage_channel.dart';
import '../state/providers.dart';
import 'protection_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(activeStateProvider);
    final data = ref.watch(dataProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final protection = state.protection;
    final usageAccess = ref.watch(usageAccessProvider).value;
    final packInstalled = ref.watch(packInstalledProvider).value;

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
        const SizedBox(height: 16),
        _buildStatusBanner(context, ref, usageAccess: usageAccess, packInstalled: packInstalled),
        const SizedBox(height: 24),
        FilledButton.icon(
          icon: const Icon(Icons.shield_outlined),
          onPressed: () => showProtectionSheet(context),
          label: const Text('Protect my peace'),
        ),
        const SizedBox(height: 6),
        Text(
          'One tap to soften conflict, breakup, and anger content for 2 hours.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
        const SizedBox(height: 28),
        Text('Switch mode', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Select a mode to apply it immediately until the next schedule.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final profile in data.profiles)
              FilterChip(
                selected: profile.id == state.baseProfile.id,
                label: Text(profile.name),
                onSelected: (_) => _pin(ref, profile, state.nextChangeAt, now),
              ),
          ],
        ),
        const SizedBox(height: 32),
        _buildVerificationCard(context, ref),
        const SizedBox(height: 16),
        _buildGuideCard(context),
      ],
    );
  }

  Widget _buildStatusBanner(
    BuildContext context,
    WidgetRef ref, {
    required bool? usageAccess,
    required bool? packInstalled,
  }) {
    final theme = Theme.of(context);
    final isReady = usageAccess != false;

    return Card(
      elevation: 0,
      color: isReady
          ? theme.colorScheme.surfaceContainerHighest
          : theme.colorScheme.errorContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              isReady ? Icons.check_circle_outline : Icons.info_outline,
              color: isReady
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isReady
                        ? (packInstalled == true
                            ? 'MoodFeed Pack connected'
                            : 'Monitoring active')
                        : 'Action required: Usage access off',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isReady
                        ? (packInstalled == true
                            ? 'Feed filters apply directly in patched Instagram.'
                            : 'Reminder will pop up when Instagram or Facebook opens.')
                        : 'Grant usage access so MoodFeed can detect when Instagram opens.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (!isReady) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: () async {
                  await const MoodFeedPlatform().openUsageAccessSettings();
                  ref.invalidate(usageAccessProvider);
                },
                child: const Text('Grant'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationCard(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_outlined, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'How to verify it is working',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '1. Keep MoodFeed installed and running in the background.\n'
              '2. Open your Instagram or Facebook app.\n'
              '3. A reminder notification will instantly pop up showing your active mode with a "Close app" option.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.notifications_active_outlined, size: 18),
              label: const Text('Send test reminder now'),
              onPressed: () async {
                await ref.read(gateProvider).showTestReminder();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Test reminder sent to your notification shade.'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideCard(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(Icons.help_outline, color: theme.colorScheme.primary, size: 20),
        title: Text(
          'How MoodFeed works',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const SizedBox(height: 4),
          _guideRow(
            theme,
            title: 'Modes and Surfaces',
            desc: 'Work, Public, Private, and Relax define what you see (such as hiding Reels, Explore, or Ads).',
          ),
          const SizedBox(height: 10),
          _guideRow(
            theme,
            title: 'Automated Schedule',
            desc: 'In the Schedule tab, set your day and hours. Modes transition on the clock without manual effort.',
          ),
          const SizedBox(height: 10),
          _guideRow(
            theme,
            title: 'Emotional Protection',
            desc: 'Tap "Protect my peace" during stressful periods. It immediately softens conflict, breakup, and anger content for 2 hours.',
          ),
          const SizedBox(height: 10),
          _guideRow(
            theme,
            title: 'Feed Enforcement',
            desc: 'MoodFeed works as a single standalone app. It watches for Instagram and Facebook and triggers a reminder the moment they open so you stay in control.',
          ),
        ],
      ),
    );
  }

  Widget _guideRow(ThemeData theme, {required String title, required String desc}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
        const SizedBox(height: 2),
        Text(desc, style: theme.textTheme.bodySmall),
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
            profiles: [
              for (final p in d.profiles) p.copyWith(isDefault: p.id == profile.id),
            ],
            settings: d.settings.copyWith(defaultProfileId: profile.id),
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
