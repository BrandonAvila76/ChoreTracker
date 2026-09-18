import 'package:flutter/material.dart';

import '../data/nestmates_store.dart';
import '../widgets/stat_tile.dart';

/// PART 3 — Home screen. Pulls a summary out of both modules so the house can
/// see where things stand without digging into either tab.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onNavigate});

  /// Jumps the bottom nav to another tab (1 = Chores, 2 = Trips, 3 = Stats).
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final store = NestmatesStore.instance;
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final chores = store.chores;
        final mine = chores.take(4).toList();
        final recent = store.recentHistory(4);

        return Scaffold(
          appBar: AppBar(title: const Text('Nestmates')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _WeekCard(
                round: store.round,
                done: store.completedThisRound,
                total: chores.length,
                progress: store.roundProgress,
              ),
              const SizedBox(height: 16),
              // IntrinsicHeight + stretch keeps the three tiles the same
              // height even when one label wraps to an extra line.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: StatTile(
                        value: '${store.totalCompletions}',
                        label: 'chores done\nall time',
                        icon: Icons.check_circle_outline,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        value: '${store.longestStreak}',
                        label: 'best streak\n(weeks)',
                        icon: Icons.local_fire_department_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        value: '${store.trips.length}',
                        label: 'trips\npacked',
                        icon: Icons.card_travel,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _SectionHeader(
                title: 'This week',
                actionLabel: 'All chores',
                onAction: () => onNavigate(1),
              ),
              if (chores.isEmpty)
                const _EmptyHint('No chores yet. Add some in the Chores tab.')
              else
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final chore in mine)
                        CheckboxListTile(
                          value: chore.completed,
                          onChanged: (value) =>
                              store.setChoreCompleted(chore.id, value ?? false),
                          title: Text(chore.name),
                          subtitle: Text(chore.assignedTo),
                          secondary: chore.streak > 0
                              ? Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text('${chore.streak}w'),
                                )
                              : null,
                        ),
                      if (chores.length > mine.length)
                        TextButton(
                          onPressed: () => onNavigate(1),
                          child: Text(
                              '+ ${chores.length - mine.length} more chores'),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              _SectionHeader(
                title: 'Recent activity',
                actionLabel: 'Stats',
                onAction: () => onNavigate(3),
              ),
              if (recent.isEmpty)
                const _EmptyHint('Check off a chore and it shows up here.')
              else
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final record in recent)
                        ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            child: Text(
                              record.roommate.isEmpty
                                  ? '?'
                                  : record.roommate[0].toUpperCase(),
                              style: theme.textTheme.labelMedium,
                            ),
                          ),
                          title: Text('${record.roommate} did ${record.choreName}'),
                          subtitle: Text(_relativeTime(record.completedAt)),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              _SectionHeader(
                title: 'Trips',
                actionLabel: 'Plan a trip',
                onAction: () => onNavigate(2),
              ),
              if (store.trips.isEmpty)
                const _EmptyHint('No trips packed yet.')
              else
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final trip in store.trips.take(3))
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.luggage_outlined),
                          title: Text(trip.name),
                          subtitle: Text(
                              '${trip.type} · ${trip.packedCount}/${trip.items.length} packed'),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.round,
    required this.done,
    required this.total,
    required this.progress,
  });

  final int round;
  final int done;
  final int total;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Week $round',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              total == 0
                  ? 'Nothing on the board'
                  : '$done of $total chores done',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor:
                    theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

String _relativeTime(DateTime moment) {
  final diff = DateTime.now().difference(moment);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'yesterday';
  return '${diff.inDays}d ago';
}
