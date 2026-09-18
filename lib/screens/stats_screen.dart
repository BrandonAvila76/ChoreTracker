import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/nestmates_store.dart';
import '../widgets/stat_tile.dart';

/// PART 3 — Stats & history. Everything here is derived from the shared store,
/// so it fills in automatically as the Chores and Trips modules are used.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = NestmatesStore.instance;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final history = store.recentHistory(30);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Stats'),
            actions: [
              IconButton(
                icon: const Icon(Icons.restart_alt),
                tooltip: 'Reset all data',
                onPressed: () => _confirmReset(context, store),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // IntrinsicHeight + stretch keeps the three tiles the same
              // height even when one label wraps to an extra line.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: StatTile(
                        value: '${store.totalCompletions}',
                        label: 'completions\nlogged',
                        icon: Icons.checklist,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        value: '${store.longestStreak}',
                        label: 'longest\nstreak',
                        icon: Icons.local_fire_department_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        value: '${store.itemsPackedAllTime}',
                        label: 'items\npacked',
                        icon: Icons.luggage_outlined,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionTitle('Chores completed, last 7 days'),
              _WeeklyBars(days: store.completionsPerDay()),
              const SizedBox(height: 24),
              const _SectionTitle('Completions by roommate'),
              _RoommateBars(tallies: store.completionsByRoommate),
              const SizedBox(height: 24),
              const _SectionTitle('Current streaks'),
              _StreakList(chores: store.choresByStreak),
              const SizedBox(height: 24),
              const _SectionTitle('Trips packed'),
              _TripList(trips: store.trips),
              const SizedBox(height: 24),
              const _SectionTitle('Completion history'),
              _HistoryList(history: history),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmReset(BuildContext context, NestmatesStore store) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset all data?'),
        content: const Text(
          'Deletes every chore, trip and history entry, and starts the house '
          'back at week 1. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await store.resetAll();
  }
}

/// Vertical bars, one per day, single hue — the measure is a count, not an
/// identity, so every bar is the same color.
class _WeeklyBars extends StatelessWidget {
  const _WeeklyBars({required this.days});

  final List<({DateTime day, int count})> days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final peak = days.fold<int>(0, (best, d) => d.count > best ? d.count : best);

    if (peak == 0) {
      return const _EmptyCard('Nothing completed in the last week.');
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
        child: SizedBox(
          height: 152,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final entry in days)
                Expanded(
                  child: Padding(
                    // 1px each side leaves the 2px gap between adjacent bars.
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 18,
                          child: entry.count == peak
                              ? Text('${entry.count}',
                                  style: theme.textTheme.labelSmall)
                              : null,
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Tooltip(
                              message:
                                  '${_weekdayName(entry.day)} ${_monthDay(entry.day)}'
                                  ' · ${entry.count} done',
                              child: entry.count == 0
                                  ? _BarShape(
                                      height: 2,
                                      color: theme.colorScheme.outlineVariant,
                                    )
                                  : FractionallySizedBox(
                                      widthFactor: 1,
                                      heightFactor: entry.count / peak,
                                      child: _BarShape(
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _weekdayInitial(entry.day),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A bar with rounded ends at the top, squared off against the baseline.
class _BarShape extends StatelessWidget {
  const _BarShape({required this.color, this.height});

  final Color color;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
    );
  }
}

/// Horizontal bars with the value direct-labeled, so no axis is needed.
class _RoommateBars extends StatelessWidget {
  const _RoommateBars({required this.tallies});

  final List<MapEntry<String, int>> tallies;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (tallies.isEmpty) {
      return const _EmptyCard('No roommates yet.');
    }
    final peak = tallies.fold<int>(0, (best, e) => e.value > best ? e.value : best);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Column(
          children: [
            for (final entry in tallies)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        entry.key,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: peak == 0 ? 0 : entry.value / peak,
                            child: Container(
                              height: 10,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${entry.value}',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.labelMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StreakList extends StatelessWidget {
  const _StreakList({required this.chores});

  final List<Chore> chores;

  @override
  Widget build(BuildContext context) {
    if (chores.isEmpty) return const _EmptyCard('No chores to track yet.');
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (final chore in chores)
            ListTile(
              dense: true,
              leading: Icon(
                chore.streak > 0
                    ? Icons.local_fire_department
                    : Icons.local_fire_department_outlined,
                color: chore.streak > 0
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
              title: Text(chore.name),
              subtitle: Text('${chore.assignedTo} · best ${chore.bestStreak}w'),
              trailing: Text(
                '${chore.streak}w',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
        ],
      ),
    );
  }
}

class _TripList extends StatelessWidget {
  const _TripList({required this.trips});

  final List<Trip> trips;

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return const _EmptyCard('No trips packed yet — plan one in the Trips tab.');
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (final trip in trips)
            ListTile(
              dense: true,
              leading: Icon(
                trip.isFullyPacked
                    ? Icons.check_circle_outline
                    : Icons.luggage_outlined,
              ),
              title: Text(trip.name),
              subtitle: Text(
                '${trip.type} · ${_monthDay(trip.createdAt)} · '
                '${trip.packedCount}/${trip.items.length} packed',
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.history});

  final List<CompletionRecord> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const _EmptyCard('Check off a chore and it shows up here.');
    }
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (final record in history)
            ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                child: Text(
                  record.roommate.isEmpty
                      ? '?'
                      : record.roommate[0].toUpperCase(),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              title: Text(record.choreName),
              subtitle: Text(
                '${record.roommate} · ${_weekdayName(record.completedAt)} '
                '${_monthDay(record.completedAt)}',
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          message,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

const _weekdayNames = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _weekdayName(DateTime date) => _weekdayNames[date.weekday - 1];

String _weekdayInitial(DateTime date) => _weekdayNames[date.weekday - 1][0];

String _monthDay(DateTime date) => '${_monthNames[date.month - 1]} ${date.day}';
