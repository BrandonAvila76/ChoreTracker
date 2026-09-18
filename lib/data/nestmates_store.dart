import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// The single source of truth for the whole app.
///
/// Chores, Trips and Stats all read and write through this object instead of
/// keeping their own `setState` copies. It is a [ChangeNotifier], so wrap any
/// widget that reads it in a `ListenableBuilder` and it will rebuild itself
/// whenever the data changes:
///
/// ```dart
/// ListenableBuilder(
///   listenable: NestmatesStore.instance,
///   builder: (context, _) => Text('${store.chores.length} chores'),
/// )
/// ```
///
/// Every mutating method persists to disk automatically — callers never need
/// to save by hand.
class NestmatesStore extends ChangeNotifier {
  NestmatesStore._();

  static final NestmatesStore instance = NestmatesStore._();

  static const _keyRoommates = 'nestmates.roommates';
  static const _keyChores = 'nestmates.chores';
  static const _keyHistory = 'nestmates.history';
  static const _keyTrips = 'nestmates.trips';
  static const _keyRound = 'nestmates.round';

  final Random _random = Random();
  final List<String> _roommates = [];
  final List<Chore> _chores = [];
  final List<CompletionRecord> _history = [];
  final List<Trip> _trips = [];

  SharedPreferences? _prefs;
  int _round = 1;
  bool _isReady = false;

  bool get isReady => _isReady;

  /// Which round (week) of chores the house is currently on.
  int get round => _round;

  List<String> get roommates => List.unmodifiable(_roommates);
  List<Chore> get chores => List.unmodifiable(_chores);
  List<CompletionRecord> get history => List.unmodifiable(_history);
  List<Trip> get trips => List.unmodifiable(_trips);

  // --------------------------------------------------------------
  // Loading & persistence
  // --------------------------------------------------------------

  /// Reads everything off disk. Call once from `main()` before `runApp`.
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final prefs = _prefs!;

    _roommates
      ..clear()
      ..addAll(_decodeList(_keyRoommates).cast<String>());
    _chores
      ..clear()
      ..addAll(_decodeList(_keyChores)
          .map((item) => Chore.fromJson(item as Map<String, dynamic>)));
    _history
      ..clear()
      ..addAll(_decodeList(_keyHistory).map(
          (item) => CompletionRecord.fromJson(item as Map<String, dynamic>)));
    _trips
      ..clear()
      ..addAll(_decodeList(_keyTrips)
          .map((item) => Trip.fromJson(item as Map<String, dynamic>)));
    _round = prefs.getInt(_keyRound) ?? 1;

    if (prefs.getString(_keyChores) == null) {
      _seedFirstRun();
    }

    _isReady = true;
    notifyListeners();
  }

  /// Gives a brand new install something to look at.
  void _seedFirstRun() {
    _roommates.addAll(['Alex', 'Sam', 'Jordan']);
    _chores.addAll([
      Chore(id: newId(), name: 'Dishes', assignedTo: 'Alex'),
      Chore(id: newId(), name: 'Trash', assignedTo: 'Sam'),
      Chore(id: newId(), name: 'Vacuum', assignedTo: 'Jordan'),
    ]);
    _persist();
  }

  List<dynamic> _decodeList(String key) {
    final raw = _prefs?.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    return jsonDecode(raw) as List<dynamic>;
  }

  Future<void> _persist() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(_keyRoommates, jsonEncode(_roommates));
    await prefs.setString(
        _keyChores, jsonEncode(_chores.map((c) => c.toJson()).toList()));
    await prefs.setString(
        _keyHistory, jsonEncode(_history.map((r) => r.toJson()).toList()));
    await prefs.setString(
        _keyTrips, jsonEncode(_trips.map((t) => t.toJson()).toList()));
    await prefs.setInt(_keyRound, _round);
  }

  void _commit() {
    notifyListeners();
    _persist();
  }

  // --------------------------------------------------------------
  // Roommates
  // --------------------------------------------------------------

  /// Replaces the roommate list, re-homing any chore left without an owner.
  void setRoommates(List<String> names) {
    _roommates
      ..clear()
      ..addAll(names);
    for (final chore in _chores) {
      if (!_roommates.contains(chore.assignedTo)) {
        chore.assignedTo =
            _roommates.isEmpty ? 'Unassigned' : _leastLoadedRoommate();
      }
    }
    _commit();
  }

  // --------------------------------------------------------------
  // Chores
  // --------------------------------------------------------------

  void addChore(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _roommates.isEmpty) return;
    _chores.add(Chore(
      id: newId(),
      name: trimmed,
      assignedTo: _leastLoadedRoommate(),
    ));
    _commit();
  }

  void removeChore(String choreId) {
    _chores.removeWhere((chore) => chore.id == choreId);
    _commit();
  }

  void assignChore(String choreId, String roommate) {
    _choreById(choreId).assignedTo = roommate;
    _commit();
  }

  /// Checking a chore off logs it to the history that Stats reads.
  void setChoreCompleted(String choreId, bool completed) {
    final chore = _choreById(choreId);
    if (chore.completed == completed) return;
    chore.completed = completed;

    if (completed) {
      _history.add(CompletionRecord(
        choreName: chore.name,
        roommate: chore.assignedTo,
        completedAt: DateTime.now(),
      ));
    } else {
      // Unchecking is an undo, so drop the entry it created.
      final index = _history.lastIndexWhere((record) =>
          record.choreName == chore.name && record.roommate == chore.assignedTo);
      if (index != -1) _history.removeAt(index);
    }
    _commit();
  }

  /// Shuffles every chore to a random roommate and starts the round over.
  void randomlyAssignAll() {
    if (_roommates.isEmpty) return;
    for (final chore in _chores) {
      chore.assignedTo = _roommates[_random.nextInt(_roommates.length)];
      chore.completed = false;
    }
    _commit();
  }

  /// Closes the current round: banks or breaks each streak, rotates every
  /// chore to the next roommate, and clears the checkboxes.
  void startNewRound() {
    for (final chore in _chores) {
      if (chore.completed) {
        chore.streak++;
        if (chore.streak > chore.bestStreak) chore.bestStreak = chore.streak;
      } else {
        chore.streak = 0;
      }
      chore.completed = false;
    }
    _rotateAssignments();
    _round++;
    _commit();
  }

  void _rotateAssignments() {
    if (_roommates.length < 2) return;
    for (final chore in _chores) {
      final current = _roommates.indexOf(chore.assignedTo);
      chore.assignedTo = current == -1
          ? _roommates.first
          : _roommates[(current + 1) % _roommates.length];
    }
  }

  Chore _choreById(String choreId) =>
      _chores.firstWhere((chore) => chore.id == choreId);

  /// Keeps round-robin fair by handing new work to whoever has the least.
  String _leastLoadedRoommate() {
    final counts = {for (final name in _roommates) name: 0};
    for (final chore in _chores) {
      if (counts.containsKey(chore.assignedTo)) {
        counts[chore.assignedTo] = counts[chore.assignedTo]! + 1;
      }
    }
    var best = _roommates.first;
    for (final name in _roommates) {
      if (counts[name]! < counts[best]!) best = name;
    }
    return best;
  }

  // --------------------------------------------------------------
  // Trips — the API the Trips module writes through
  // --------------------------------------------------------------

  /// Inserts the trip, or replaces the stored one with a matching id.
  void saveTrip(Trip trip) {
    final index = _trips.indexWhere((existing) => existing.id == trip.id);
    if (index == -1) {
      _trips.add(trip);
    } else {
      _trips[index] = trip;
    }
    _commit();
  }

  void deleteTrip(String tripId) {
    _trips.removeWhere((trip) => trip.id == tripId);
    _commit();
  }

  // --------------------------------------------------------------
  // Derived stats
  // --------------------------------------------------------------

  int get completedThisRound => _chores.where((chore) => chore.completed).length;

  double get roundProgress =>
      _chores.isEmpty ? 0 : completedThisRound / _chores.length;

  int get totalCompletions => _history.length;

  int get longestStreak => _chores.isEmpty
      ? 0
      : _chores.map((chore) => chore.bestStreak).reduce(max);

  int get itemsPackedAllTime =>
      _trips.fold(0, (sum, trip) => sum + trip.packedCount);

  /// Chores ordered by current streak, longest first.
  List<Chore> get choresByStreak =>
      [..._chores]..sort((a, b) => b.streak.compareTo(a.streak));

  /// How many chores each roommate has ever completed, biggest first.
  List<MapEntry<String, int>> get completionsByRoommate {
    final counts = {for (final name in _roommates) name: 0};
    for (final record in _history) {
      counts[record.roommate] = (counts[record.roommate] ?? 0) + 1;
    }
    return counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }

  /// Whoever has completed the most chores, or null if nobody has yet.
  String? get streakLeader {
    final ranked = completionsByRoommate;
    if (ranked.isEmpty || ranked.first.value == 0) return null;
    return ranked.first.key;
  }

  /// Newest completions first.
  List<CompletionRecord> recentHistory([int limit = 20]) {
    final sorted = [..._history]
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    return sorted.take(limit).toList();
  }

  /// Completion counts for the last [days] days, oldest day first.
  List<({DateTime day, int count})> completionsPerDay([int days = 7]) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(days, (offset) {
      final day = today.subtract(Duration(days: days - 1 - offset));
      final count = _history
          .where((record) => _isSameDay(record.completedAt, day))
          .length;
      return (day: day, count: count);
    });
  }

  /// Wipes everything back to a fresh install. Used by the Stats screen.
  Future<void> resetAll() async {
    _roommates.clear();
    _chores.clear();
    _history.clear();
    _trips.clear();
    _round = 1;
    await _prefs?.clear();
    _seedFirstRun();
    notifyListeners();
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
