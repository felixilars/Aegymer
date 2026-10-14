import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'package:aegymer/core/databases/user_profile.dart';
import 'package:aegymer/core/databases/workout_sessions.dart';
import 'package:aegymer/core/databases/workout_sets.dart';
import 'package:aegymer/core/databases/user_meals.dart';
import 'package:aegymer/core/databases/exercises.dart';
import 'package:aegymer/core/databases/food.dart';
import 'package:aegymer/core/databases/routines.dart';
import 'package:aegymer/core/databases/routine_exercises.dart';
import 'package:aegymer/core/databases/meal_items.dart';

part 'app_database.g.dart';

class RoutineWithExercises {
  final Routine routine;
  final List<Exercise> exercises;

  RoutineWithExercises({required this.routine, required this.exercises});
}

@DriftDatabase(
  tables: [
    UserProfiles,
    WorkoutSessions,
    WorkoutSets,
    UserMeals,
    MealItems,
    Exercises,
    Foods,
    Routines,
    RoutineExercises,
  ],
)
class AppDatabase extends _$AppDatabase {
  static AppDatabase? _instance;

  factory AppDatabase([QueryExecutor? executor]) {
    if (executor != null) {
      return AppDatabase._internal(executor);
    }
    return _instance ??= AppDatabase._internal();
  }

  AppDatabase._internal([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  Future<void> close() async {
    // Prevent accidental closing of the singleton application database during UI navigation
    if (identical(this, _instance)) {
      return;
    }
    await super.close();
  }

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(routines);
            await m.createTable(routineExercises);
          }
          if (from < 3) {
            await m.addColumn(exercises, exercises.trackingType);
            await m.addColumn(exercises, exercises.secondaryTrackingTypes);
            await m.addColumn(workoutSets, workoutSets.weightType);
            await m.addColumn(workoutSets, workoutSets.distance);
            await m.addColumn(workoutSets, workoutSets.durationSeconds);
          }
          if (from < 4) {
            await m.createTable(mealItems);
            await m.addColumn(foods, foods.fiber);
          }
        },
      );

  // Fetch raw sets joined with their sessions for a specific exercise, sorted by date ascending.
  Future<List<TypedResult>> getRawExerciseHistory(String exerciseId) {
    return (select(workoutSets).join([
      innerJoin(workoutSessions, workoutSessions.id.equalsExp(workoutSets.sessionId)),
    ])
      ..where(workoutSets.exerciseId.equals(exerciseId))
      ..orderBy([OrderingTerm.asc(workoutSessions.date)]))
        .get();
  }

  // Save workout session and its sets in a database transaction
  Future<void> saveWorkoutSession({
    required String sessionId,
    required DateTime date,
    String? notes,
    required List<WorkoutSetsCompanion> setsCompanions,
  }) async {
    await transaction(() async {
      await into(workoutSessions).insert(
        WorkoutSessionsCompanion.insert(
          id: sessionId,
          date: date,
          notes: Value(notes),
        ),
      );
      await batch((batch) {
        batch.insertAll(workoutSets, setsCompanions);
      });
    });
  }

  // Fetch routines along with their sorted exercises
  Future<List<RoutineWithExercises>> getRoutinesWithExercises() async {
    final routinesList = await select(routines).get();
    final List<RoutineWithExercises> results = [];
    for (final routine in routinesList) {
      final query = select(routineExercises).join([
        innerJoin(exercises, exercises.id.equalsExp(routineExercises.exerciseId)),
      ])
        ..where(routineExercises.routineId.equals(routine.id))
        ..orderBy([OrderingTerm.asc(routineExercises.orderIndex)]);
      
      final rows = await query.get();
      final List<Exercise> routineExercisesList = [];
      for (final row in rows) {
        routineExercisesList.add(row.readTable(exercises));
      }
      results.add(RoutineWithExercises(routine: routine, exercises: routineExercisesList));
    }
    return results;
  }

  // Delete routine and its exercises
  Future<void> deleteRoutine(String routineId) async {
    await transaction(() async {
      await (delete(routineExercises)..where((tbl) => tbl.routineId.equals(routineId))).go();
      await (delete(routines)..where((tbl) => tbl.id.equals(routineId))).go();
    });
  }

  // Save routine and its exercises
  Future<void> saveRoutine({
    required String routineId,
    required String name,
    String? description,
    required List<String> exerciseIds,
  }) async {
    await transaction(() async {
      // 1. Delete existing routine_exercises if routine already exists
      await (delete(routineExercises)..where((tbl) => tbl.routineId.equals(routineId))).go();
      
      // 2. Insert or update routine
      await into(routines).insertOnConflictUpdate(
        RoutinesCompanion.insert(
          id: routineId,
          name: name,
          description: Value(description),
        ),
      );

      // 3. Insert new routine_exercises in order
      await batch((batch) {
        for (int i = 0; i < exerciseIds.length; i++) {
          final uniqueId = '$routineId-$i-${DateTime.now().microsecondsSinceEpoch}';
          batch.insert(
            routineExercises,
            RoutineExercisesCompanion.insert(
              id: uniqueId,
              routineId: routineId,
              exerciseId: exerciseIds[i],
              orderIndex: i,
            ),
          );
        }
      });
    });
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'my_database',
      native: const DriftNativeOptions(
        // By default, `driftDatabase` from `package:drift_flutter` stores the
        // database files in `getApplicationDocumentsDirectory()`.
        databaseDirectory: getApplicationSupportDirectory,
      ),
      web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.dart.js'),
    ),
      // If you need web support, see https://drift.simonbinder.eu/platforms/web/
    );
  }
}
