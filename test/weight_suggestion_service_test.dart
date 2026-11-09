import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aegymer/core/databases/app_database.dart';
import 'package:aegymer/core/services/weight_suggestion_service.dart';

void main() {
  late AppDatabase db;
  late WeightSuggestionService service;
  final today = DateTime(2026, 11, 9);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    service = WeightSuggestionService(db);
    await db.into(db.exercises).insert(ExercisesCompanion.insert(
          id: 'squat', name: 'Squat', targetMuscle: 'Legs', equipment: 'Barbell'));
  });

  tearDown(() async {
    await db.close();
  });

  var counter = 0;
  Future<void> logSession(DateTime date, double weight, List<int> reps,
      {String weightType = 'standard', double? distance}) async {
    final sessionId = 'session-${counter++}';
    await db.saveWorkoutSession(
      sessionId: sessionId,
      date: date,
      setsCompanions: [
        for (var i = 0; i < reps.length; i++)
          WorkoutSetsCompanion.insert(
            id: '$sessionId-$i',
            sessionId: sessionId,
            exerciseId: 'squat',
            setNumber: i + 1,
            weight: weight,
            reps: reps[i],
            weightType: Value(weightType),
            distance: Value(distance),
          ),
      ],
    );
  }

  test('no history means no suggestion', () async {
    expect(await service.suggestFor('squat', sessionDate: today), isNull);
  });

  test('beating your usual reps suggests going heavier (APRE)', () async {
    await logSession(today.subtract(const Duration(days: 7)), 100, [5, 5, 5]);
    await logSession(today.subtract(const Duration(days: 3)), 100, [8, 7, 7]);

    final s = await service.suggestFor('squat', sessionDate: today);
    expect(s, isNotNull);
    expect(s!.method, startsWith('APRE'));
    expect(s.lastWeight, 100);
    expect(s.lastReps, 8);
    expect(s.weight, 105); // ~2.5 reps above usual -> +2 steps
    expect(s.sessionCount, 2);
  });

  test('matching your usual reps keeps the weight', () async {
    await logSession(today.subtract(const Duration(days: 7)), 60, [10, 10, 10]);
    await logSession(today.subtract(const Duration(days: 3)), 60, [10, 10, 9]);

    final s = await service.suggestFor('squat', sessionDate: today);
    expect(s!.weight, 60);
  });

  test('a long break triggers a deload', () async {
    await logSession(today.subtract(const Duration(days: 30)), 100, [5, 5, 5]);

    final s = await service.suggestFor('squat', sessionDate: today);
    expect(s!.method, startsWith('Deload'));
    expect(s.weight, 90);
  });

  test('five or more sessions switch to the KNN model', () async {
    for (var i = 0; i < 6; i++) {
      await logSession(today.subtract(Duration(days: 3 * (6 - i))), 50.0 + 2.5 * i, [8, 8, 7]);
    }
    final s = await service.suggestFor('squat', sessionDate: today);
    expect(s!.method, 'KNN (ML)');
    expect(s.weight, greaterThanOrEqualTo(s.lastWeight));
  });

  test('ignores future-dated, bodyweight and cardio sets', () async {
    await logSession(today.add(const Duration(days: 2)), 200, [5]);
    await logSession(today.subtract(const Duration(days: 2)), 0, [10], weightType: 'bodyweight');
    await logSession(today.subtract(const Duration(days: 1)), 0, [1], distance: 5);
    expect(await service.suggestFor('squat', sessionDate: today), isNull);
  });
}
