/// Shared models used by the Chores, Trips and Stats modules.
///
/// Every model is JSON-round-trippable so [NestmatesStore] can persist it.
library;

int _idCounter = 0;

/// Unique enough for a single-device app.
String newId() {
  _idCounter++;
  return '${DateTime.now().microsecondsSinceEpoch}-$_idCounter';
}

/// A single chore: what it is, who owns it this round, and its streak.
class Chore {
  Chore({
    required this.id,
    required this.name,
    required this.assignedTo,
    this.completed = false,
    this.streak = 0,
    this.bestStreak = 0,
  });

  factory Chore.fromJson(Map<String, dynamic> json) => Chore(
        id: json['id'] as String,
        name: json['name'] as String,
        assignedTo: json['assignedTo'] as String,
        completed: json['completed'] as bool? ?? false,
        streak: json['streak'] as int? ?? 0,
        bestStreak: json['bestStreak'] as int? ?? 0,
      );

  final String id;
  String name;
  String assignedTo;
  bool completed;

  /// Consecutive rounds this chore was finished before the round rolled over.
  int streak;
  int bestStreak;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'assignedTo': assignedTo,
        'completed': completed,
        'streak': streak,
        'bestStreak': bestStreak,
      };
}

/// One "X finished Y" event, appended every time a chore is checked off.
class CompletionRecord {
  CompletionRecord({
    required this.choreName,
    required this.roommate,
    required this.completedAt,
  });

  factory CompletionRecord.fromJson(Map<String, dynamic> json) =>
      CompletionRecord(
        choreName: json['choreName'] as String,
        roommate: json['roommate'] as String,
        completedAt: DateTime.parse(json['completedAt'] as String),
      );

  final String choreName;
  final String roommate;
  final DateTime completedAt;

  Map<String, dynamic> toJson() => {
        'choreName': choreName,
        'roommate': roommate,
        'completedAt': completedAt.toIso8601String(),
      };
}

/// One line on a packing list.
class PackingItem {
  PackingItem({required this.label, this.packed = false});

  factory PackingItem.fromJson(Map<String, dynamic> json) => PackingItem(
        label: json['label'] as String,
        packed: json['packed'] as bool? ?? false,
      );

  String label;
  bool packed;

  Map<String, dynamic> toJson() => {'label': label, 'packed': packed};
}

/// A trip and the checklist that goes with it.
class Trip {
  Trip({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
    List<PackingItem>? items,
  }) : items = items ?? <PackingItem>[];

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
        id: json['id'] as String,
        name: json['name'] as String,
        type: json['type'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((item) => PackingItem.fromJson(item as Map<String, dynamic>))
            .toList(),
      );

  final String id;
  String name;
  String type;
  final DateTime createdAt;
  final List<PackingItem> items;

  int get packedCount => items.where((item) => item.packed).length;

  bool get isFullyPacked => items.isNotEmpty && packedCount == items.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'createdAt': createdAt.toIso8601String(),
        'items': items.map((item) => item.toJson()).toList(),
      };
}
