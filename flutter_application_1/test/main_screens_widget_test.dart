import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/databases/app_database.dart';
import 'package:flutter_application_1/presentation/screen/Home_and_Main/homepage.dart';
import 'package:flutter_application_1/presentation/screen/MealPrep/meal_prep_page.dart';
import 'package:flutter_application_1/presentation/screen/workout_launcher_screen.dart';
import 'package:flutter_application_1/presentation/screen/workout_progress_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Main app screens render', () {
    testWidgets('Home screen shows core dashboard widgets', (
      WidgetTester tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());

      await tester.pumpWidget(
        MaterialApp(
          home: Homepage(
            db: db,
            onRecordWorkout: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Recent Sessions'), findsOneWidget);
      expect(find.text('Daily Streak'), findsOneWidget);
    });

    testWidgets('Meal page shows recommendation and search areas', (
      WidgetTester tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());

      await tester.pumpWidget(
        MaterialApp(
          home: MealPrepPage(db: db),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Recommended Foods'), findsOneWidget);
      expect(find.text('Current Meal'), findsOneWidget);
      expect(find.text('Search Food'), findsOneWidget);
    });

    testWidgets('Workout launcher renders the free-style and routines sections', (
      WidgetTester tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());

      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutLauncherScreen(db: db),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Free-style Workout'), findsOneWidget);
      expect(find.text('Your Routines'), findsOneWidget);
    });

    testWidgets('Progress screen renders without crashing with empty history', (
      WidgetTester tester,
    ) async {
      final db = AppDatabase(NativeDatabase.memory());

      await tester.pumpWidget(
        MaterialApp(
          home: WorkoutProgressScreen(db: db),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(WorkoutProgressScreen), findsOneWidget);
    });
  });
}
