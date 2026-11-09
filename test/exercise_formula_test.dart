import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aegymer/core/databases/app_database.dart';
import 'package:aegymer/core/services/backup_service.dart';
import 'package:aegymer/core/utils/exercise_formula.dart';
import 'package:aegymer/core/utils/formula_expression.dart';
import 'package:aegymer/core/utils/set_metrics.dart';

double eval(String src, [Map<String, double> vars = const {}]) =>
    FormulaExpression.parse(src, variables: vars.keys.toSet()).evaluate(vars);

void main() {
  group('FormulaExpression', () {
    test('arithmetic, precedence, unary minus and power', () {
      expect(eval('1 + 2 * 3'), 7);
      expect(eval('(1 + 2) * 3'), 9);
      expect(eval('-2 ^ 2'), -4);
      expect(eval('2 ^ 3 ^ 2'), 512);
      expect(eval('10 / 4 - 0.5'), 2);
      expect(eval('6 × 2 ÷ 3'), 4);
    });

    test('variables and functions (angles in degrees)', () {
      expect(eval('weight * sin(30) + 20', {'weight': 100}), closeTo(70, 1e-9));
      expect(eval('cos(60)'), closeTo(0.5, 1e-9));
      expect(eval('max(reps, 3, 8)', {'reps': 5}), 8);
      expect(eval('min(2, sqrt(9))'), 2);
      expect(eval('round(2.6) + abs(-1) + pow(2, 3)'), 12);
      expect(eval('WEIGHT', {'weight': 4}), 4); // case-insensitive
    });

    test('rejects bad input with a readable message', () {
      void bad(String src, String part) => expect(
            () => FormulaExpression.parse(src, variables: {'weight'}),
            throwsA(isA<FormulaException>().having((e) => e.message, 'message', contains(part))),
          );
      bad('', 'empty');
      bad('weight *', 'ends too early');
      bad('(weight', 'Expected ")"');
      bad('weigth * 2', 'Unknown name "weigth"');
      bad('foo(1)', 'Unknown function');
      bad('sin 45', 'needs parentheses');
      bad('pow(2)', 'takes 2 values');
      bad('weight; 1', 'not allowed');
      bad('1.2.3', 'not a valid number');
      bad('2 3', 'Unexpected');
    });
  });

  group('ExerciseFormula', () {
    test('load feeds the calorie formula; blank fields mean default', () {
      final f = ExerciseFormula.fromSource(load: 'weight * 0.5 + 30', kcal: 'load * reps * 0.01');
      final r = f.apply(weight: 200, reps: 10, bodyweight: 70, durationSeconds: 90);
      expect(r.load, 130);
      expect(r.kcal, 13);

      final kcalOnly = ExerciseFormula.fromSource(kcal: 'load * reps * 0.01');
      expect(kcalOnly.apply(weight: 200, reps: 10, bodyweight: 70).load, isNull);
      expect(kcalOnly.apply(weight: 200, reps: 10, bodyweight: 70).kcal, 20);
      expect(ExerciseFormula.fromSource(load: '  ', kcal: null).isEmpty, isTrue);
    });

    test('negative results become 0, non-numbers fall back to default', () {
      final f = ExerciseFormula.fromSource(load: 'weight - 500', kcal: '1 / (reps - 10)');
      final r = f.apply(weight: 100, reps: 10, bodyweight: 70);
      expect(r.load, 0);
      expect(r.kcal, isNull);
    });

    test('load is not allowed inside the load formula; invalid text is ignored', () {
      expect(ExerciseFormula.validate('load * 2', isKcal: false), contains('Unknown name'));
      expect(ExerciseFormula.validate('load * 2', isKcal: true), isNull);
      expect(ExerciseFormula.fromSource(load: 'weight *').isEmpty, isTrue);
    });
  });

  group('database', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.into(db.exercises).insert(ExercisesCompanion.insert(
          id: 'lp', name: 'Leg Press', targetMuscle: 'Legs', equipment: 'Machine'));
      await db.into(db.exercises).insert(ExercisesCompanion.insert(
          id: 'bench', name: 'Bench Press', targetMuscle: 'Chest', equipment: 'Barbell'));
    });

    tearDown(() => db.close());

    WorkoutSetsCompanion set(String id, String sessionId, String ex, double w, int r) =>
        WorkoutSetsCompanion.insert(
          id: id,
          sessionId: sessionId,
          exerciseId: ex,
          setNumber: 1,
          weight: w,
          reps: r,
          calculated1rm: Value(w * (1 + r / 30)),
          durationSeconds: const Value(90),
        );

    Future<WorkoutSet> load(String id) =>
        (db.select(db.workoutSets)..where((t) => t.id.equals(id))).getSingle();

    test('saving applies the formula only to exercises that have one', () async {
      await db.saveExerciseFormula('lp', load: 'weight * 0.5', kcal: 'load * reps * 0.01');
      final saved = await db.saveWorkoutSession(
        sessionId: 's1',
        date: DateTime(2026, 11, 1),
        setsCompanions: [set('a', 's1', 'lp', 200, 10), set('b', 's1', 'bench', 100, 5)],
      );

      final lp = await load('a');
      expect(lp.weight, 200); // what the user entered is kept
      expect(lp.effectiveLoad, 100);
      expect(lp.loadKg, 100);
      expect(lp.calories, 10);
      expect(lp.calculated1rm, closeTo(100 * (1 + 10 / 30), 1e-9));
      expect(saved.first.effectiveLoad.value, 100);

      final bench = await load('b');
      expect(bench.effectiveLoad, isNull);
      expect(bench.calories, isNull);
      expect(bench.loadKg, 100);
    });

    test('a new formula leaves history alone unless recalculated', () async {
      await db.saveWorkoutSession(
          sessionId: 's1', date: DateTime(2026, 11, 1), setsCompanions: [set('old', 's1', 'lp', 200, 10)]);
      await db.saveExerciseFormula('lp', load: 'weight * 0.5');
      await db.saveWorkoutSession(
          sessionId: 's2', date: DateTime(2026, 11, 3), setsCompanions: [set('new', 's2', 'lp', 200, 10)]);

      // Option A: only new sets.
      expect((await load('old')).loadKg, 200);
      expect((await load('new')).loadKg, 100);

      // Option B: recalculate history.
      expect(await db.countSetsForExercise('lp'), 2);
      expect(await db.recomputeFormulaHistory('lp'), 2);
      expect((await load('old')).loadKg, 100);
      expect((await load('old')).calculated1rm, closeTo(100 * (1 + 10 / 30), 1e-9));

      // Clearing the formula and recalculating restores the defaults.
      await db.saveExerciseFormula('lp', load: '', kcal: ' ');
      expect(await db.getExerciseFormula('lp'), isNull);
      await db.recomputeFormulaHistory('lp');
      final reset = await load('old');
      expect(reset.effectiveLoad, isNull);
      expect(reset.calories, isNull);
      expect(reset.calculated1rm, closeTo(200 * (1 + 10 / 30), 1e-9));
    });

    test('cardio sets get calories but no load', () async {
      await db.into(db.exercises).insert(ExercisesCompanion.insert(
          id: 'run', name: 'Running', targetMuscle: 'Cardio', equipment: 'None'));
      await db.saveExerciseFormula('run', load: 'weight * 2', kcal: 'bw * km');
      await db.saveWorkoutSession(sessionId: 's1', date: DateTime(2026, 11, 1), setsCompanions: [
        WorkoutSetsCompanion.insert(
          id: 'c', sessionId: 's1', exerciseId: 'run', setNumber: 1, weight: 0, reps: 1,
          distance: const Value(5.0), durationSeconds: const Value(1800)),
      ]);
      final c = await load('c');
      expect(c.effectiveLoad, isNull);
      expect(c.calories, 70 * 5); // no profile -> 70 kg default
    });

    test('formulas survive backup/restore; custom exercise delete removes them', () async {
      await db.saveExerciseFormula('lp', load: 'weight * sin(45) + 30');
      final backup = await BackupService(db).exportBackup();

      final other = AppDatabase(NativeDatabase.memory());
      addTearDown(other.close);
      await BackupService(other).restoreBackup(backup);
      expect((await other.getExerciseFormula('lp'))?.loadFormula, 'weight * sin(45) + 30');

      await db.into(db.exercises).insert(ExercisesCompanion.insert(
          id: 'mine', name: 'My Machine', targetMuscle: 'Legs', equipment: 'Machine',
          isCustom: const Value(true)));
      await db.saveExerciseFormula('mine', kcal: 'reps');
      expect(await db.deleteCustomExerciseIfUnused('mine'), 0);
      expect(await db.getExerciseFormula('mine'), isNull);
    });
  });
}
