import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/databases/app_database.dart';
import 'package:flutter_application_1/presentation/screen/workout_launcher_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:flutter_application_1/presentation/AppBars/RecordWorkoutAppBar.dart';

void main() {
  testWidgets('Workout launcher shows a home button for returning to the homepage', (
    WidgetTester tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: const RecordWorkoutAppBar(),
          body: WorkoutLauncherScreen(db: db),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aegymer Workout'), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);
  });
}
