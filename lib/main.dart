import 'dart:math';
import 'package:flutter/material.dart';

void main() {
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

  static const List<Widget> _screens = [
    ChoresScreen(),
    TripsScreen(),
    StatsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nestmates')),
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
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

// A single chore: what it is, who it's assigned to, whether it's
// done this round, and how many rounds in a row it's been completed.
class Chore {
  Chore({required this.name, required this.assignedTo});

  String name;
  String assignedTo;
  bool completed = false;
  int streak = 0;
}

class _ChoresScreenState extends State<ChoresScreen> {
  // Roommates start empty — add them from the "Manage Roommates" screen.
  List<String> _roommates = ['Alex', 'Sam', 'Jordan'];

  late List<Chore> _chores = [
    Chore(name: 'Dishes', assignedTo: _roommates[0]),
    Chore(name: 'Trash', assignedTo: _roommates[1]),
    Chore(name: 'Vacuum', assignedTo: _roommates[2]),
  ];

  final TextEditingController _newChoreController = TextEditingController();
  final Random _random = Random();

  void _addChore(String name) {
    if (name.trim().isEmpty) return;
    if (_roommates.isEmpty) {
      _showSnackBar('Add at least one roommate first.');
      return;
    }
    setState(() {
      // New chores start assigned to a random roommate.
      final assignee = _roommates[_random.nextInt(_roommates.length)];
      _chores.add(Chore(name: name.trim(), assignedTo: assignee));
    });
    _newChoreController.clear();
  }

  void _removeChore(int index) {
    setState(() {
      _chores.removeAt(index);
    });
  }

  void _toggleComplete(int index) {
    setState(() {
      final chore = _chores[index];
      chore.completed = !chore.completed;
      if (chore.completed) {
        chore.streak++;
      } else {
        chore.streak = chore.streak > 0 ? chore.streak - 1 : 0;
      }
    });
  }

  // Randomly reassigns every chore to any roommate (with replacement),
  // and resets "completed" for the new round.
  void _randomlyAssignAll() {
    if (_roommates.isEmpty) {
      _showSnackBar('Add at least one roommate first.');
      return;
    }
    setState(() {
      for (final chore in _chores) {
        chore.assignedTo = _roommates[_random.nextInt(_roommates.length)];
        chore.completed = false;
      }
    });
  }

  // Lets the user manually pick who a single chore is assigned to.
  Future<void> _pickAssignee(int index) async {
    if (_roommates.isEmpty) {
      _showSnackBar('Add at least one roommate first.');
      return;
    }
    final chosen = await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Assign to'),
          children: _roommates.map((name) {
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(context, name),
              child: Text(name),
            );
          }).toList(),
        );
      },
    );
    if (chosen != null) {
      setState(() {
        _chores[index].assignedTo = chosen;
      });
    }
  }

  // Opens the roommate management screen and syncs any changes back.
  Future<void> _openManageRoommates() async {
    final updated = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (context) => ManageRoommatesScreen(roommates: _roommates),
      ),
    );
    if (updated != null) {
      setState(() {
        _roommates = updated;
        // If a roommate was removed, reassign their chores randomly
        // among whoever's left so nothing points at a deleted name.
        for (final chore in _chores) {
          if (!_roommates.contains(chore.assignedTo)) {
            chore.assignedTo = _roommates.isNotEmpty
                ? _roommates[_random.nextInt(_roommates.length)]
                : 'Unassigned';
          }
        }
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chores'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Manage roommates',
            onPressed: _openManageRoommates,
          ),
          IconButton(
            icon: const Icon(Icons.shuffle),
            tooltip: 'Randomly assign all',
            onPressed: _randomlyAssignAll,
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
            child: ListView.builder(
              itemCount: _chores.length,
              itemBuilder: (context, index) {
                final chore = _chores[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    leading: Checkbox(
                      value: chore.completed,
                      onChanged: (_) => _toggleComplete(index),
                    ),
                    title: Text(chore.name),
                    subtitle: Text(
                      'Assigned to ${chore.assignedTo} · streak: ${chore.streak}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.person_outline),
                          tooltip: 'Assign to someone specific',
                          onPressed: () => _pickAssignee(index),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete chore',
                          onPressed: () => _removeChore(index),
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
            child: const Text('Done', style: TextStyle(color: Colors.white)),
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
  class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
  }

  class _TripsScreenState extends State<TripsScreen> {
  String _selectedTripType = 'Beach';

  final Set<String> _checkedItems = {};

  final TextEditingController _itemController = TextEditingController();

  final Map<String, List<String>> _tripChecklists = {
  'Beach': [
  'Swimsuit',
  'Sunscreen',
  'Towel',
  'Sunglasses',
  'Sandals',
  'Water bottle',
  ],
  'Hiking': [
  'Hiking boots',
  'Backpack',
  'Water bottle',
  'Snacks',
  'First aid kit',
  'Map',
  ],
  'Business': [
  'Laptop',
  'Laptop charger',
  'Business clothes',
  'Dress shoes',
  'Notebook',
  'Toiletries',
  ],
  'Custom': [],
  };

  late List<String> _currentChecklist;

  @override
  void initState() {
  super.initState();
  _currentChecklist = List.of(_tripChecklists[_selectedTripType]!);
  }

  void _changeTripType(String? newType) {
  if (newType == null) return;

  setState(() {
  _selectedTripType = newType;
  _currentChecklist = List.of(_tripChecklists[newType]!);
  });
  }

  @override
  Widget build(BuildContext context) {
  return Scaffold(
  appBar: AppBar(
  title: const Text('Trip Packing'),
  ),
  body: Padding(
  padding: const EdgeInsets.all(16.0),
  child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
  const Text(
  'Trip Type',
  style: TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.bold,
  ),
  ),
  const SizedBox(height: 8),

  DropdownButtonFormField<String>(
  value: _selectedTripType,
  decoration: const InputDecoration(
  border: OutlineInputBorder(),
  ),
  items: _tripChecklists.keys.map((type) {
  return DropdownMenuItem(
  value: type,
  child: Text(type),
  );
  }).toList(),
  onChanged: _changeTripType,
  ),

  const SizedBox(height: 24),

  Text(
  '$_selectedTripType Packing List',
  style: const TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.bold,
  ),
  ),

  const SizedBox(height: 8),

    Row(
      children: [
        Expanded(
          child: TextField(
            controller: _itemController,
            decoration: const InputDecoration(
              labelText: 'Add packing item',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            final newItem = _itemController.text.trim();

            if (newItem.isNotEmpty) {
              setState(() {
                _tripChecklists[_selectedTripType]!.add(newItem);
                _itemController.clear();
              });
            }
          },
          child: const Text('Add Item'),
        ),
      ],
    ),

    const SizedBox(height: 8),


  Expanded(
  child: _currentChecklist.isEmpty
  ? const Center(
  child: Text(
  'No items yet. Add items to your custom checklist.',
  ),
  )
      : ListView.builder(
  itemCount: _currentChecklist.length,
  itemBuilder: (context, index) {
    return Card(
      child: CheckboxListTile(
        title: Text(_currentChecklist[index]),
        value: _checkedItems.contains(_currentChecklist[index]),
        onChanged: (bool? value) {
          setState(() {
            if (value == true) {
              _checkedItems.add(_currentChecklist[index]);
            } else {
              _checkedItems.remove(_currentChecklist[index]);
            }
          });
        },
      ),
    );
  },
  ),
  ),
  ],
  ),
  ),
  );
  }
  }
// ------------------------------------------------------------
// PART 3: STATS/DASHBOARD + DATA LAYER (placeholder — leader's job)
// ------------------------------------------------------------
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Text(
          'Stats/history go here.\n\nTODO:\n- Chore completion history + '
          'streaks display\n- Past trips packed\n'
          '- Shared data layer (e.g. shared_preferences or sqflite) '
          'that Chores & Trips both read/write to',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// SHARED DATA LAYER (stub) - leader owns this
// ------------------------------------------------------------
class NestmatesData {
  // TODO: replace with shared_preferences (simple) or sqflite (relational)
  static final List<Map<String, dynamic>> chores = [];
  static final List<Map<String, dynamic>> trips = [];
}
