import 'package:chores_module/data/models.dart';
import 'package:chores_module/data/nestmates_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final store = NestmatesStore.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.load();
    await store.resetAll();
  });

  test('seeds a first run with roommates and chores', () {
    expect(store.roommates, ['Alex', 'Sam', 'Jordan']);
    expect(store.chores.length, 3);
    expect(store.round, 1);
  });

  test('completing a chore logs it to history', () {
    final chore = store.chores.first;
    store.setChoreCompleted(chore.id, true);

    expect(store.completedThisRound, 1);
    expect(store.totalCompletions, 1);
    expect(store.history.single.roommate, chore.assignedTo);
  });

  test('unchecking a chore removes its history entry', () {
    final chore = store.chores.first;
    store.setChoreCompleted(chore.id, true);
    store.setChoreCompleted(chore.id, false);

    expect(store.totalCompletions, 0);
    expect(store.completedThisRound, 0);
  });

  test('a new round banks finished streaks and breaks unfinished ones', () {
    final finished = store.chores[0];
    final skipped = store.chores[1];
    store.setChoreCompleted(finished.id, true);

    store.startNewRound();

    expect(store.chores[0].streak, 1);
    expect(store.chores[0].bestStreak, 1);
    expect(store.chores[1].streak, 0);
    expect(store.chores.every((chore) => !chore.completed), isTrue);
    expect(store.round, 2);
    expect(skipped.streak, 0);
  });

  test('a new round rotates every chore to the next roommate', () {
    final before = store.chores.map((chore) => chore.assignedTo).toList();

    store.startNewRound();

    final after = store.chores.map((chore) => chore.assignedTo).toList();
    for (var i = 0; i < before.length; i++) {
      final expected = store.roommates[
          (store.roommates.indexOf(before[i]) + 1) % store.roommates.length];
      expect(after[i], expected);
    }
  });

  test('removing a roommate re-homes their chores', () {
    store.setRoommates(['Alex', 'Sam']);

    expect(
      store.chores.every((chore) => store.roommates.contains(chore.assignedTo)),
      isTrue,
    );
  });

  test('new chores go to whoever has the fewest', () {
    store.setRoommates(['Alex']);
    store.addChore('Mop');

    expect(store.chores.last.assignedTo, 'Alex');
    expect(store.chores.last.name, 'Mop');
  });

  test('trips save, update in place and delete', () {
    final trip = Trip(
      id: newId(),
      name: 'Spring Break',
      type: 'beach',
      createdAt: DateTime.now(),
      items: [PackingItem(label: 'Sunscreen'), PackingItem(label: 'Towel')],
    );

    store.saveTrip(trip);
    expect(store.trips.length, 1);

    trip.items.first.packed = true;
    store.saveTrip(trip);
    expect(store.trips.length, 1);
    expect(store.itemsPackedAllTime, 1);

    store.deleteTrip(trip.id);
    expect(store.trips, isEmpty);
  });

  test('data survives a reload from disk', () async {
    final chore = store.chores.first;
    store.setChoreCompleted(chore.id, true);
    store.addChore('Laundry');

    await store.load();

    expect(store.chores.length, 4);
    expect(store.totalCompletions, 1);
    expect(store.chores.any((c) => c.name == 'Laundry'), isTrue);
  });

  test('completionsPerDay returns one bucket per day, newest last', () {
    final chore = store.chores.first;
    store.setChoreCompleted(chore.id, true);

    final days = store.completionsPerDay();

    expect(days.length, 7);
    expect(days.last.count, 1);
  });
}
