# Nestmates

A roommate chore tracker and trip packing list in one Flutter app.

## Modules

| Part | Screen | Status |
| --- | --- | --- |
| 1 — Chores | `lib/screens/chores_screen.dart` | Done |
| 2 — Trips | `lib/screens/trips_screen.dart` | Placeholder |
| 3 — Stats & data layer | `lib/screens/dashboard_screen.dart`, `lib/screens/stats_screen.dart`, `lib/data/` | Done |

## Shared data layer

Everything persists through one object, `NestmatesStore.instance`
(`lib/data/nestmates_store.dart`), backed by `shared_preferences`. It is loaded
once in `main()` and is the only thing that touches storage — no screen keeps
its own copy of the data.

It is a `ChangeNotifier`, so a screen reads it like this:

```dart
ListenableBuilder(
  listenable: NestmatesStore.instance,
  builder: (context, _) => Text('${store.chores.length} chores'),
)
```

Every mutating method saves to disk on its own, so callers never save by hand.
Anything written through the store shows up on the Home and Stats screens
automatically.

### Adding a trip (Part 2)

```dart
NestmatesStore.instance.saveTrip(Trip(
  id: newId(),
  name: 'Spring Break',
  type: 'beach',
  createdAt: DateTime.now(),
  items: [PackingItem(label: 'Sunscreen')],
));
```

`saveTrip` inserts or replaces by id — call it again with the same trip
whenever an item is checked off.

## How chores work

Chores belong to a **round** (a week). Checking one off logs a
`CompletionRecord` to the history the Stats screen reads. Starting a new week
(the calendar icon on the Chores tab) banks a streak for every chore that got
done, resets the streak of every chore that did not, rotates each chore to the
next roommate, and clears the checkboxes.

## Running it

```sh
flutter pub get
flutter run
```

## Tests

```sh
flutter analyze
flutter test
```

`test/nestmates_store_test.dart` covers the data layer (streaks, rotation,
persistence). `test/app_smoke_test.dart` renders every tab so a layout overflow
fails the build instead of showing up in the demo. Both run in CI on every push
to `main`, which also uploads the release APK as a build artifact.
