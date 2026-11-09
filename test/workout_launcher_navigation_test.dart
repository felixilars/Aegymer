import 'package:flutter/material.dart';
import 'package:aegymer/core/databases/app_database.dart';
import 'package:aegymer/presentation/screen/workout_launcher_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aegymer/presentation/AppBars/RecordWorkoutAppBar.dart';

void main() {
  testWidgets('Workout launcher has centered title and no home button', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

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
    expect(find.byIcon(Icons.home), findsNothing);
  });
}
