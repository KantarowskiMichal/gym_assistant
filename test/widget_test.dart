import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gym_assistant/main.dart';

void main() {
  testWidgets('App shows navigation and screens', (WidgetTester tester) async {
    await tester.pumpWidget(const GymAssistantApp());

    // Verify bottom navigation exists (text appears in both nav and AppBar)
    expect(find.text('Exercises'), findsWidgets);
    expect(find.text('Workouts'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);

    // Verify navigation icons exist
    expect(find.byIcon(Icons.fitness_center), findsOneWidget);
    expect(find.byIcon(Icons.list_alt), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month), findsOneWidget);

    // Verify the add button exists
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
