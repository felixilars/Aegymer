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
import 'package:aegymer/core/databases/exercise_formulas.dart';
import 'package:aegymer/core/utils/exercise_formula.dart';
import 'package:aegymer/core/utils/workout_cal.dart';

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
    ExerciseFormulas,
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
  int get schemaVersion => 6;

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
          if (from < 5) {
            // v5 adds real foreign keys to workout_sets and meal_items, which
            // SQLite can only do by rebuilding the tables. Fix rows that would
            // violate them first, without losing any visible history.
            await customStatement(
                'DELETE FROM workout_sets WHERE session_id NOT IN (SELECT id FROM workout_sessions)');
            await customStatement(
                "INSERT OR IGNORE INTO exercises (id, name, target_muscle, equipment, description, is_custom) "
                "SELECT DISTINCT exercise_id, 'Archived Exercise (' || exercise_id || ')', 'General', 'Other', "
                "'Exercise restored from past workout history.', 1 "
                'FROM workout_sets WHERE exercise_id NOT IN (SELECT id FROM exercises)');
            await customStatement(
                'DELETE FROM meal_items WHERE meal_id NOT IN (SELECT id FROM user_meals)');
            await customStatement(
                "INSERT OR IGNORE INTO foods (id, name, calories, protein, carbs, fat, is_custom) "
                "SELECT DISTINCT food_id, 'Archived Food (' || food_id || ')', 0, 0, 0, 0, 1 "
                'FROM meal_items WHERE food_id NOT IN (SELECT id FROM foods)');
            // TableMigration is drift's documented way to rebuild a table.
            // ignore: experimental_member_use
            await m.alterTable(TableMigration(
              workoutSets,
              // Columns added after v4 don't exist in the old table and must
              // be declared, or SQLite copies their names in as text.
              newColumns: [workoutSets.effectiveLoad, workoutSets.calories],
            ));
            // ignore: experimental_member_use
            await m.alterTable(TableMigration(mealItems));
          }
          if (from < 6) {
            await m.createTable(exerciseFormulas);
            // The v5 rebuild above already creates workout_sets with these
            // columns, so only add them when coming from v5 itself.
            if (from >= 5) {
              await m.addColumn(workoutSets, workoutSets.effectiveLoad);
              await m.addColumn(workoutSets, workoutSets.calories);
            }
          }
        },
        // Runs after onCreate/onUpgrade, so migrations still execute with
        // foreign keys off. SQLite disables them by default per connection,
        // which would make every `.references()` in the schema a no-op.
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
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

  // Save workout session and its sets in a database transaction. Custom
  // exercise formulas are applied; the sets as saved are returned.
  Future<List<WorkoutSetsCompanion>> saveWorkoutSession({
    required String sessionId,
    required DateTime date,
    String? notes,
    required List<WorkoutSetsCompanion> setsCompanions,
  }) async {
    return transaction(() async {
      final sets = await applyExerciseFormulas(setsCompanions);
      await into(workoutSessions).insert(
        WorkoutSessionsCompanion.insert(
          id: sessionId,
          date: date,
          notes: Value(notes),
        ),
      );
      await batch((batch) {
        batch.insertAll(workoutSets, sets);
      });
      return sets;
    });
  }

  // Fetch a workout session by ID
  Future<WorkoutSession?> getWorkoutSessionById(String sessionId) async {
    return (select(workoutSessions)..where((tbl) => tbl.id.equals(sessionId))).getSingleOrNull();
  }

  // Delete workout session and its sets in a database transaction
  Future<void> deleteWorkoutSession(String sessionId) async {
    await transaction(() async {
      await (delete(workoutSets)..where((tbl) => tbl.sessionId.equals(sessionId))).go();
      await (delete(workoutSessions)..where((tbl) => tbl.id.equals(sessionId))).go();
    });
  }

  // Update workout session and its sets in a database transaction
  Future<void> updateWorkoutSession({
    required String sessionId,
    required DateTime date,
    String? notes,
    required List<WorkoutSetsCompanion> setsCompanions,
  }) async {
    await transaction(() async {
      await (update(workoutSessions)..where((tbl) => tbl.id.equals(sessionId))).write(
        WorkoutSessionsCompanion(
          date: Value(date),
          notes: Value(notes),
        ),
      );
      await (delete(workoutSets)..where((tbl) => tbl.sessionId.equals(sessionId))).go();
      if (setsCompanions.isNotEmpty) {
        final sets = await applyExerciseFormulas(setsCompanions);
        await batch((batch) {
          batch.insertAll(workoutSets, sets);
        });
      }
    });
  }

  // Fetch routines along with their sorted exercises (optimized batch query)
  Future<List<RoutineWithExercises>> getRoutinesWithExercises() async {
    final routinesList = await select(routines).get();
    if (routinesList.isEmpty) return [];

    final routineIds = routinesList.map((r) => r.id).toList();
    final rows = await (select(routineExercises).join([
      innerJoin(exercises, exercises.id.equalsExp(routineExercises.exerciseId)),
    ])
      ..where(routineExercises.routineId.isIn(routineIds))
      ..orderBy([OrderingTerm.asc(routineExercises.orderIndex)]))
      .get();

    final Map<String, List<Exercise>> exercisesByRoutine = {};
    for (final row in rows) {
      final re = row.readTable(routineExercises);
      final ex = row.readTable(exercises);
      exercisesByRoutine.putIfAbsent(re.routineId, () => []).add(ex);
    }

    return routinesList
        .map((r) => RoutineWithExercises(
              routine: r,
              exercises: exercisesByRoutine[r.id] ?? [],
            ))
        .toList();
  }

  /// Deletes a custom exercise unless it appears in workout history.
  ///
  /// Returns the number of logged sets that reference the exercise; when that
  /// is greater than zero nothing is deleted, so past sessions keep their
  /// exercise name. Routine entries pointing at the exercise are removed with it.
  Future<int> deleteCustomExerciseIfUnused(String exerciseId) {
    return transaction(() async {
      final usedCount = await (selectOnly(workoutSets)
            ..addColumns([workoutSets.id.count()])
            ..where(workoutSets.exerciseId.equals(exerciseId)))
          .map((row) => row.read(workoutSets.id.count()) ?? 0)
          .getSingle();
      if (usedCount > 0) return usedCount;

      await (delete(routineExercises)..where((tbl) => tbl.exerciseId.equals(exerciseId))).go();
      await (delete(exerciseFormulas)..where((tbl) => tbl.exerciseId.equals(exerciseId))).go();
      await (delete(exercises)
            ..where((tbl) => tbl.id.equals(exerciseId) & tbl.isCustom.equals(true)))
          .go();
      return 0;
    });
  }

  // ---------------------------------------------------------------------------
  // Custom exercise formulas
  // ---------------------------------------------------------------------------

  Future<ExerciseFormulaRow?> getExerciseFormula(String exerciseId) {
    return (select(exerciseFormulas)..where((t) => t.exerciseId.equals(exerciseId)))
        .getSingleOrNull();
  }

  /// Saves (or, when both are blank, removes) an exercise's formulas. Only
  /// sets saved from now on use them; see [recomputeFormulaHistory].
  Future<void> saveExerciseFormula(String exerciseId, {String? load, String? kcal}) async {
    String? clean(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
    final l = clean(load), k = clean(kcal);
    if (l == null && k == null) {
      await (delete(exerciseFormulas)..where((t) => t.exerciseId.equals(exerciseId))).go();
      return;
    }
    await into(exerciseFormulas).insertOnConflictUpdate(ExerciseFormulasCompanion.insert(
      exerciseId: exerciseId,
      loadFormula: Value(l),
      kcalFormula: Value(k),
    ));
  }

  Future<int> countSetsForExercise(String exerciseId) {
    return (selectOnly(workoutSets)
          ..addColumns([workoutSets.id.count()])
          ..where(workoutSets.exerciseId.equals(exerciseId)))
        .map((row) => row.read(workoutSets.id.count()) ?? 0)
        .getSingle();
  }

  Future<double> _profileBodyweight() async {
    final profile = await (select(userProfiles)..limit(1)).getSingleOrNull();
    final bw = profile?.weight ?? 0;
    return bw > 0 ? bw : 70.0;
  }

  Future<Map<String, ExerciseFormula>> _formulasFor(Iterable<String> exerciseIds) async {
    final ids = exerciseIds.toSet();
    if (ids.isEmpty) return const {};
    final rows = await (select(exerciseFormulas)..where((t) => t.exerciseId.isIn(ids))).get();
    return {
      for (final r in rows)
        r.exerciseId: ExerciseFormula.fromSource(load: r.loadFormula, kcal: r.kcalFormula),
    };
  }

  /// Fills effective load, calories and e1RM from each exercise's custom
  /// formula. Sets of exercises without one are returned unchanged.
  Future<List<WorkoutSetsCompanion>> applyExerciseFormulas(List<WorkoutSetsCompanion> sets) async {
    final formulas = await _formulasFor(sets.map((s) => s.exerciseId.value));
    if (formulas.isEmpty) return sets;
    final bw = await _profileBodyweight();

    return sets.map((s) {
      final f = formulas[s.exerciseId.value];
      if (f == null || f.isEmpty) return s;
      final m = _formulaMetrics(
        f,
        weight: s.weight.value,
        reps: s.reps.value,
        bodyweight: bw,
        durationSeconds: s.durationSeconds.present ? s.durationSeconds.value : null,
        distance: s.distance.present ? s.distance.value : null,
      );
      return s.copyWith(
        effectiveLoad: Value(m.load),
        calories: Value(m.kcal),
        calculated1rm: m.e1rm != null ? Value(m.e1rm) : s.calculated1rm,
      );
    }).toList();
  }

  /// Rewrites stored load, calories and e1RM of every past set of
  /// [exerciseId] with its current formula (or the defaults when it has
  /// none). Uses today's body weight. Returns the number of sets updated.
  Future<int> recomputeFormulaHistory(String exerciseId) {
    return transaction(() async {
      final f = (await _formulasFor([exerciseId]))[exerciseId] ?? const ExerciseFormula();
      final bw = await _profileBodyweight();
      final sets = await (select(workoutSets)..where((t) => t.exerciseId.equals(exerciseId))).get();

      await batch((b) {
        for (final s in sets) {
          final m = _formulaMetrics(
            f,
            weight: s.weight,
            reps: s.reps,
            bodyweight: bw,
            durationSeconds: s.durationSeconds,
            distance: s.distance,
          );
          b.update(
            workoutSets,
            WorkoutSetsCompanion(
              effectiveLoad: Value(m.load),
              calories: Value(m.kcal),
              calculated1rm: m.e1rm != null ? Value(m.e1rm) : const Value.absent(),
            ),
            where: (t) => t.id.equals(s.id),
          );
        }
      });
      return sets.length;
    });
  }

  /// Load/e1RM only apply to weighted rep sets (not cardio or timed holds,
  /// which are stored with weight 0). e1RM is null when it should be kept.
  static ({double? load, double? kcal, double? e1rm}) _formulaMetrics(
    ExerciseFormula f, {
    required double weight,
    required int reps,
    required double bodyweight,
    int? durationSeconds,
    double? distance,
  }) {
    final r = f.apply(
      weight: weight,
      reps: reps,
      bodyweight: bodyweight,
      durationSeconds: durationSeconds ?? 0,
      distanceKm: distance ?? 0,
    );
    final isLoadSet = weight > 0 && reps > 0 && distance == null;
    final load = isLoadSet ? r.load : null;
    final double? e1rm = isLoadSet ? WorkoutCalculator.calculateE1RM(load ?? weight, reps) : null;
    return (load: load, kcal: r.kcal, e1rm: e1rm);
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
