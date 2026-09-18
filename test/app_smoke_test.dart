import 'package:chores_module/data/nestmates_store.dart';
import 'package:chores_module/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders every tab for real, so a layout overflow or a bad constraint fails
/// the build instead of showing up in the demo video.

/// Scoped to the nav bar — "Stats" and "Trips" also appear in screen content.
Finder _navTab(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

void main() {
  final store = NestmatesStore.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.load();
    await store.resetAll();
  });

  testWidgets('every tab renders and the nav switches between them',
      (tester) async {
    await tester.pumpWidget(const NestmatesApp());
    await tester.pumpAndSettle();

    expect(find.text('Nestmates'), findsOneWidget);
    expect(find.text('Week 1'), findsOneWidget);

    await tester.tap(_navTab('Chores'));
    await tester.pumpAndSettle();
    expect(find.text('Chores · Week 1'), findsOneWidget);

    await tester.tap(_navTab('Trips'));
    await tester.pumpAndSettle();
    expect(find.text('Trip Packing'), findsOneWidget);

    await tester.tap(_navTab('Stats'));
    await tester.pumpAndSettle();
    expect(find.text('Chores completed, last 7 days'), findsOneWidget);
  });

  testWidgets('checking a chore on the dashboard updates the stats charts',
      (tester) async {
    await tester.pumpWidget(const NestmatesApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(find.text('1 of 3 chores done'), findsOneWidget);

    await tester.tap(_navTab('Stats'));
    await tester.pumpAndSettle();

    // The bar chart replaces its empty state once there is something to plot.
    expect(find.text('Nothing completed in the last week.'), findsNothing);
    expect(find.text('Completions by roommate'), findsOneWidget);
  });

  testWidgets('adding a chore from the Chores tab shows up on Home',
      (tester) async {
    await tester.pumpWidget(const NestmatesApp());
    await tester.pumpAndSettle();

    await tester.tap(_navTab('Chores'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Scrub the tub');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add'));
    await tester.pumpAndSettle();

    expect(find.text('Scrub the tub'), findsOneWidget);

    await tester.tap(_navTab('Home'));
    await tester.pumpAndSettle();
    expect(find.text('0 of 4 chores done'), findsOneWidget);
  });
}
