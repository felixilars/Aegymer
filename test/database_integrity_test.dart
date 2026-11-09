import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aegymer/core/databases/app_database.dart';
import 'package:aegymer/core/services/backup_service.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.into(db.exercises).insert(ExercisesCompanion.insert(
          id: 'my-curl',
          name: 'My Curl',
          targetMuscle: 'Biceps',
          equipment: 'Dumbbell',
          isCustom: const Value(true),
        ));
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> logSet(String exerciseId) => db.saveWorkoutSession(
        sessionId: 's1',
        date: DateTime(2026, 11, 1),
        setsCompanions: [
          WorkoutSetsCompanion.insert(
            id: 'set1',
            sessionId: 's1',
            exerciseId: exerciseId,
            setNumber: 1,
            weight: 10,
            reps: 10,
          ),
        ],
      );

  test('foreign keys are enforced', () async {
    final row = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(row.data.values.single, 1);

    await expectLater(logSet('does-not-exist'), throwsA(anything));
  });

  test('catalog upsert works on an exercise referenced by history', () async {
    await logSet('my-curl');
    await db.batch((b) => b.insertAllOnConflictUpdate(db.exercises, [
          ExercisesCompanion.insert(
            id: 'my-curl',
            name: 'Renamed Curl',
            targetMuscle: 'Biceps',
            equipment: 'Dumbbell',
          ),
        ]));
    final ex = await (db.select(db.exercises)..where((t) => t.id.equals('my-curl'))).getSingle();
    expect(ex.name, 'Renamed Curl');
  });

  test('custom exercise used in history is not deleted', () async {
    await logSet('my-curl');
    expect(await db.deleteCustomExerciseIfUnused('my-curl'), 1);
    expect(await db.select(db.exercises).get(), hasLength(1));
  });

  test('unused custom exercise is deleted along with routine entries', () async {
    await db.saveRoutine(routineId: 'r1', name: 'Arms', exerciseIds: ['my-curl']);
    expect(await db.deleteCustomExerciseIfUnused('my-curl'), 0);
    expect(await db.select(db.exercises).get(), isEmpty);
    expect(await db.select(db.routineExercises).get(), isEmpty);
  });

  test('backup restores into an empty database, adding placeholder catalog rows', () async {
    await db.into(db.exercises).insert(ExercisesCompanion.insert(
          id: 'bench',
          name: 'Bench Press',
          targetMuscle: 'Chest',
          equipment: 'Barbell',
        ));
    await logSet('bench');
    final backup = await BackupService(db).exportBackup();

    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);
    await BackupService(fresh).restoreBackup(backup);

    final sets = await fresh.select(fresh.workoutSets).get();
    expect(sets.single.exerciseId, 'bench');
    // 'bench' is a catalog exercise, so the backup does not contain it.
    final placeholder = await (fresh.select(fresh.exercises)..where((t) => t.id.equals('bench'))).getSingle();
    expect(placeholder.isCustom, isFalse);
    expect((jsonDecode(backup) as Map)['custom_exercises'], hasLength(1));

    // Restoring twice is idempotent.
    await BackupService(fresh).restoreBackup(backup);
    expect(await fresh.select(fresh.workoutSets).get(), hasLength(1));
  });

  test('restored profile replaces the one created during onboarding', () async {
    UserProfilesCompanion profile(String id, double weight) => UserProfilesCompanion.insert(
          id: id,
          gender: 'Male',
          age: 30,
          weight: weight,
          height: 175,
          activityLevel: 1.55,
          target: 'maintain',
          dailyCalories: 2500,
          dailyProtein: 150,
          dailyCarbs: 300,
          dailyFat: 70,
        );

    await db.into(db.userProfiles).insert(profile('old-phone', 82));
    final backup = await BackupService(db).exportBackup();

    // New phone: the user had to create a profile before reaching Settings.
    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);
    await fresh.into(fresh.userProfiles).insert(profile('new-phone', 70));
    await BackupService(fresh).restoreBackup(backup);
    await BackupService(fresh).restoreBackup(backup);

    final profiles = await fresh.select(fresh.userProfiles).get();
    expect(profiles, hasLength(1));
    expect(profiles.single.id, 'new-phone');
    expect(profiles.single.weight, 82);
  });
}
