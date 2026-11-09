import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aegymer/core/databases/app_database.dart';
import 'package:aegymer/core/services/workout_draft_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase(NativeDatabase.memory());
    await db.batch((b) {
      b.insertAll(db.exercises, [
        ExercisesCompanion.insert(
          id: 'run',
          name: 'Treadmill Running',
          targetMuscle: 'Cardio',
          equipment: 'Machine',
        ),
        ExercisesCompanion.insert(
          id: 'bench',
          name: 'Bench Press',
          targetMuscle: 'Chest',
          equipment: 'Barbell',
        ),
      ]);
    });
  });

  tearDown(() async {
    await db.close();
  });

  Map<String, dynamic> draftWith(List<Map<String, dynamic>> runSets) => {
        'workoutDate': DateTime(2026, 11, 1).toIso8601String(),
        'secondsElapsed': 3600,
        'notes': '',
        'exercises': [
          {
            'id': 'run',
            'name': 'Treadmill Running',
            'targetMuscle': 'Cardio',
            'equipment': 'Machine',
            'trackingType': 'cardio_time',
          },
          {
            'id': 'bench',
            'name': 'Bench Press',
            'targetMuscle': 'Chest',
            'equipment': 'Barbell',
            'trackingType': 'weight_reps',
          },
        ],
        'setsData': {
          'run': runSets,
          'bench': [
            {'weight': '60', 'reps': '8', 'distance': '', 'duration': '', 'weightType': 'standard'},
          ],
        },
      };

  Future<WorkoutSet> savedSet(String exerciseId) async =>
      (db.select(db.workoutSets)..where((t) => t.exerciseId.equals(exerciseId))).getSingle();

  test('cardio with only duration does not get an invented distance', () async {
    final ok = await WorkoutDraftService.finishAndSaveDraft(
      db,
      draftWith([
        {'weight': '', 'reps': '', 'distance': '', 'duration': '30:00', 'weightType': 'standard'},
      ]),
    );
    expect(ok, isTrue);

    final run = await savedSet('run');
    expect(run.durationSeconds, 1800);
    expect(run.distance, isNull);
    expect(run.reps, 1);
    expect(run.weight, 0);
  });

  test('cardio with only distance does not get an invented duration', () async {
    await WorkoutDraftService.finishAndSaveDraft(
      db,
      draftWith([
        {'weight': '', 'reps': '', 'distance': '5', 'duration': '', 'weightType': 'standard'},
      ]),
    );

    final run = await savedSet('run');
    expect(run.distance, 5);
    expect(run.durationSeconds, isNull);
  });

  test('strength sets still get an estimated duration for calories', () async {
    await WorkoutDraftService.finishAndSaveDraft(
      db,
      draftWith([
        {'weight': '', 'reps': '', 'distance': '5', 'duration': '', 'weightType': 'standard'},
      ]),
    );

    final bench = await savedSet('bench');
    expect(bench.weight, 60);
    expect(bench.reps, 8);
    expect(bench.durationSeconds, greaterThan(0));
  });

  test('launcher finish skips incomplete strength sets like the workout screen', () async {
    final draft = draftWith([
      {'weight': '', 'reps': '', 'distance': '5', 'duration': '', 'weightType': 'standard'},
    ]);
    (draft['setsData'] as Map)['bench'] = [
      {'weight': '60', 'reps': '8', 'distance': '', 'duration': '', 'weightType': 'standard'},
      {'weight': '60', 'reps': '', 'distance': '', 'duration': '', 'weightType': 'standard'},
      {'weight': '', 'reps': '8', 'distance': '', 'duration': '', 'weightType': 'added'},
    ];
    await WorkoutDraftService.finishAndSaveDraft(db, draft);

    final bench = await savedSet('bench'); // exactly one set saved
    expect(bench.weight, 60);
    expect(bench.reps, 8);
    expect(bench.weightType, 'standard');
  });
}
