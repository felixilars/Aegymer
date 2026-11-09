import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aegymer/core/databases/app_database.dart';
import 'package:aegymer/presentation/screen/active_workout_screen.dart';

void main() {
  testWidgets('workout screen shows the next-weight suggestion and applies it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    late RoutineWithExercises routine;
    await tester.runAsync(() async {
      await db.into(db.exercises).insert(ExercisesCompanion.insert(
            id: 'lp', name: 'Leg Press', targetMuscle: 'Legs', equipment: 'Machine',
            trackingType: const Value('weight_reps')));
      final now = DateTime.now();
      for (final (i, reps) in [(7, 8), (3, 11)]) {
        await db.saveWorkoutSession(
          sessionId: 's$i',
          date: now.subtract(Duration(days: i)),
          setsCompanions: [
            WorkoutSetsCompanion.insert(
                id: 'set$i', sessionId: 's$i', exerciseId: 'lp', setNumber: 1, weight: 120, reps: reps),
          ],
        );
      }
      await db.saveRoutine(routineId: 'r', name: 'Legs', exerciseIds: ['lp']);
      routine = (await db.getRoutinesWithExercises()).single;
    });

    await tester.pumpWidget(MaterialApp(home: ActiveWorkoutScreen(db: db, routine: routine)));
    for (var i = 0; i < 10 && find.textContaining('Suggested:').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }

    // 11 reps vs usual 8 -> two 2.5 kg steps up.
    expect(find.text('Suggested: 125 kg'), findsOneWidget);
    expect(find.textContaining('+5 kg vs last'), findsOneWidget);

    // Last session (120 × 11) is shown as hints; nothing is pre-entered.
    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.where((f) => f.decoration?.hintText == '120'), isNotEmpty);
    expect(fields.where((f) => f.decoration?.hintText == '11'), isNotEmpty);
    expect(fields.where((f) => f.controller?.text == '120' || f.controller?.text == '11'), isEmpty);

    // So finishing without typing anything saves nothing.
    await tester.ensureVisible(find.text('Finish'));
    await tester.tap(find.text('Finish'));
    await tester.pump();
    expect(find.text('Please complete at least one set before finishing the workout.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5)); // let the snackbar go

    await tester.ensureVisible(find.text('Apply'));
    await tester.tap(find.text('Apply'));
    await tester.pump();

    final weightFields = tester
        .widgetList<TextField>(find.byType(TextField))
        .where((f) => f.controller?.text == '125');
    expect(weightFields, isNotEmpty);

    // Unmount to stop the workout timer.
    await tester.pumpWidget(const SizedBox());
  });
}
