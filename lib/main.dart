import 'package:flutter/material.dart';

import 'data/nestmates_store.dart';
import 'screens/dashboard_screen.dart';
import 'screens/stats_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NestmatesStore.instance.load();
  runApp(const NestmatesApp());
}

class NestmatesApp extends StatelessWidget {
  const NestmatesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nestmates',
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const HomeShell(),
    );
  }
}

/// Bottom-nav shell tying all 3 modules together.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  void _goToTab(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps each tab's scroll position and text fields alive.
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          DashboardScreen(onNavigate: _goToTab),
          const ChoresScreen(),
          // TripsScreen is still the bare placeholder, so the shell supplies
          // its app bar. Drop this wrapper once it has a Scaffold of its own.
          Scaffold(
            appBar: AppBar(title: const Text('Trips')),
            body: const TripsScreen(),
          ),
          const StatsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _goToTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.cleaning_services),
            label: 'Chores',
          ),
          NavigationDestination(
            icon: Icon(Icons.card_travel),
            label: 'Trips',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// PART 1: CHORES MODULE (fully implemented — this is your part)
// ------------------------------------------------------------
class ChoresScreen extends StatefulWidget {
  const ChoresScreen({super.key});

  @override
  State<ChoresScreen> createState() => _ChoresScreenState();
}

class _ChoresScreenState extends State<ChoresScreen> {
  // Chores, roommates and streaks all live in the shared store now, so the
  // Stats screen sees every change without this screen telling it anything.
  final NestmatesStore _store = NestmatesStore.instance;
  final TextEditingController _newChoreController = TextEditingController();

  @override
  void dispose() {
    _newChoreController.dispose();
    super.dispose();
  }

  void _addChore(String name) {
    if (name.trim().isEmpty) return;
    if (_store.roommates.isEmpty) {
      _showSnackBar('Add at least one roommate first.');
      return;
    }
    _store.addChore(name);
    _newChoreController.clear();
  }

  // Lets the user manually pick who a single chore is assigned to.
  Future<void> _pickAssignee(String choreId) async {
    if (_store.roommates.isEmpty) {
      _showSnackBar('Add at least one roommate first.');
      return;
    }
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Assign to'),
          children: _store.roommates.map((name) {
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(context, name),
              child: Text(name),
            );
          }).toList(),
        );
      },
    );
    if (chosen != null) _store.assignChore(choreId, chosen);
  }

  // Opens the roommate management screen and syncs any changes back. The
  // store re-homes any chore whose owner was deleted.
  Future<void> _openManageRoommates() async {
    final updated = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ManageRoommatesScreen(roommates: _store.roommates),
      ),
    );
    if (updated != null) _store.setRoommates(updated);
  }

  Future<void> _confirmNewRound() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Start week ${_store.round + 1}?'),
        content: const Text(
          'Finished chores bank a streak, unfinished ones reset to zero, '
          'and everything rotates to the next roommate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start week'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      _store.startNewRound();
      _showSnackBar('Week ${_store.round} started — chores rotated.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final chores = _store.chores;
        return Scaffold(
          appBar: AppBar(
            title: Text('Chores · Week ${_store.round}'),
            actions: [
              IconButton(
                icon: const Icon(Icons.people_outline),
                tooltip: 'Manage roommates',
                onPressed: _openManageRoommates,
              ),
              IconButton(
                icon: const Icon(Icons.shuffle),
                tooltip: 'Randomly assign all',
                onPressed:
                    _store.roommates.isEmpty ? null : _store.randomlyAssignAll,
              ),
              IconButton(
                icon: const Icon(Icons.event_repeat),
                tooltip: 'Start a new week',
                onPressed: chores.isEmpty ? null : _confirmNewRound,
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newChoreController,
                        decoration: const InputDecoration(
                          labelText: 'Add a chore',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: _addChore,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _addChore(_newChoreController.text),
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: chores.isEmpty
                    ? const Center(child: Text('No chores yet — add one above.'))
                    : ListView.builder(
                        itemCount: chores.length,
                        itemBuilder: (context, index) {
                          final chore = chores[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            child: ListTile(
                              leading: Checkbox(
                                value: chore.completed,
                                onChanged: (value) => _store.setChoreCompleted(
                                    chore.id, value ?? false),
                              ),
                              title: Text(chore.name),
                              subtitle: Text(
                                'Assigned to ${chore.assignedTo}'
                                '${chore.streak > 0 ? ' · streak: ${chore.streak}' : ''}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.person_outline),
                                    tooltip: 'Assign to someone specific',
                                    onPressed: () => _pickAssignee(chore.id),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: 'Delete chore',
                                    onPressed: () =>
                                        _store.removeChore(chore.id),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------
// Manage Roommates screen: add/remove people from the chore list
// ------------------------------------------------------------
class ManageRoommatesScreen extends StatefulWidget {
  const ManageRoommatesScreen({super.key, required this.roommates});

  final List<String> roommates;

  @override
  State<ManageRoommatesScreen> createState() => _ManageRoommatesScreenState();
}

class _ManageRoommatesScreenState extends State<ManageRoommatesScreen> {
  late List<String> _roommates;
  final TextEditingController _newNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Copy so we don't mutate the parent's list until "Done" is pressed.
    _roommates = List.of(widget.roommates);
  }

  @override
  void dispose() {
    _newNameController.dispose();
    super.dispose();
  }

  void _addRoommate(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _roommates.contains(trimmed)) return;
    setState(() {
      _roommates.add(trimmed);
    });
    _newNameController.clear();
  }

  void _removeRoommate(int index) {
    setState(() {
      _roommates.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Roommates'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _roommates),
            child: const Text('Done'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newNameController,
                    decoration: const InputDecoration(
                      labelText: 'Add a roommate',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: _addRoommate,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _addRoommate(_newNameController.text),
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _roommates.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_roommates[index]),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _removeRoommate(index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------
// PART 2: TRIPS MODULE (placeholder — teammate's job)
// ------------------------------------------------------------
class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Text(
          'Trips go here.\n\nTODO:\n- Trip type selector '
          '(beach/hiking/business/custom)\n'
          '- Auto-generate checklist per trip type\n'
          '- Edit + save custom checklists',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// PART 3: STATS/DASHBOARD + DATA LAYER
// ------------------------------------------------------------
// Lives in its own files now, so this one stays small:
//   lib/data/nestmates_store.dart    — shared storage (replaces NestmatesData)
//   lib/data/models.dart             — Chore, Trip, PackingItem, history
//   lib/screens/dashboard_screen.dart
//   lib/screens/stats_screen.dart
//
// Trips module: save through NestmatesStore.instance.saveTrip(...) and the
// Home and Stats screens pick it up automatically. See README.md.
