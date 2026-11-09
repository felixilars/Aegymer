import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aegymer/core/databases/app_database.dart';
import 'package:aegymer/presentation/screen/exercise_formula_screen.dart';

void main() {
  testWidgets('write a leg press formula, preview it, save and recalculate history', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    late Exercise legPress;
    await tester.runAsync(() async {
      await db.into(db.exercises).insert(ExercisesCompanion.insert(
          id: 'lp', name: 'Leg Press', targetMuscle: 'Legs', equipment: 'Machine'));
      legPress = await (db.select(db.exercises)..where((t) => t.id.equals('lp'))).getSingle();
      await db.saveWorkoutSession(sessionId: 's1', date: DateTime(2026, 11, 1), setsCompanions: [
        WorkoutSetsCompanion.insert(
            id: 'old', sessionId: 's1', exerciseId: 'lp', setNumber: 1, weight: 200, reps: 10),
      ]);
    });

    await tester.pumpWidget(MaterialApp(
      home: ExerciseFormulaScreen(db: db, exercise: legPress, trackingType: 'weight_reps'),
    ));
    for (var i = 0; i < 10 && find.text('Load (kg)').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }

    final loadField = find.byType(TextField).first;
    final list = find.byType(Scrollable).first;
    expect(find.text('Load = 100 kg (default)'), findsOneWidget);

    // A typo shows an error and disables saving.
    await tester.enterText(loadField, 'weigth * 0.5');
    await tester.pump();
    expect(find.textContaining('Unknown name "weigth"'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Save formula'), 200, scrollable: list);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    await tester.scrollUntilVisible(find.text('Leg press 45°, 30 kg sled'), -200, scrollable: list);

    // Tapping the example fills a valid formula with a live preview.
    await tester.tap(find.text('Leg press 45°, 30 kg sled'));
    await tester.pump();
    expect(find.text('weight * sin(45) + 30'), findsOneWidget);
    expect(find.text('Load = 100.7 kg'), findsOneWidget); // 100 × 0.707 + 30

    await tester.scrollUntilVisible(find.text('Save formula'), 200, scrollable: list);
    await tester.ensureVisible(find.text('Save formula'));
    await tester.pump();
    await tester.tap(find.text('Save formula'));
    for (var i = 0; i < 10 && find.text('Apply to past workouts?').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(find.text('Apply to past workouts?'), findsOneWidget);

    await tester.tap(find.text('Recalculate 1 sets'));
    for (var i = 0; i < 10 && find.byType(ExerciseFormulaScreen).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }

    final old = await tester.runAsync(() => db.select(db.workoutSets).getSingle());
    expect(old!.effectiveLoad, closeTo(200 * 0.70710678 + 30, 1e-6));
    final saved = await tester.runAsync(() => db.getExerciseFormula('lp'));
    expect(saved!.loadFormula, 'weight * sin(45) + 30');
  });
}
