import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:aegymer/core/databases/app_database.dart';

/// What a backup file contains, shown to the user before restoring.
class BackupSummary {
  final int version;
  final DateTime? createdAt;
  final int sessions;
  final int sets;
  final int meals;
  final int routines;
  final int customExercises;
  final int customFoods;
  final bool hasProfile;

  const BackupSummary({
    required this.version,
    required this.createdAt,
    required this.sessions,
    required this.sets,
    required this.meals,
    required this.routines,
    required this.customExercises,
    required this.customFoods,
    required this.hasProfile,
  });
}

class BackupService {
  /// Format version written by [exportBackup]. Restoring a newer version is
  /// refused rather than risking a partial or wrong import.
  static const int currentVersion = 2;

  final AppDatabase _db;

  BackupService(this._db);

  /// Validates [jsonString] as an Aegymer backup and summarizes it.
  /// Throws [FormatException] if it is not one this app version can restore.
  static BackupSummary inspect(String jsonString) {
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonString);
    } on FormatException {
      throw const FormatException('This file is not valid JSON.');
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] is! int ||
        !decoded.containsKey('backup_timestamp')) {
      throw const FormatException('This file is not an Aegymer backup.');
    }
    final Map<String, dynamic> data = decoded;
    final version = data['version'] as int;
    if (version > currentVersion) {
      throw FormatException(
          'This backup was made by a newer version of Aegymer (format $version). Update the app to restore it.');
    }
    int count(String key) => (data[key] as List?)?.length ?? 0;
    return BackupSummary(
      version: version,
      createdAt: DateTime.tryParse(data['backup_timestamp']?.toString() ?? ''),
      sessions: count('sessions'),
      sets: count('sets'),
      meals: count('meals'),
      routines: count('routines'),
      customExercises: count('custom_exercises'),
      customFoods: count('custom_foods'),
      hasProfile: count('profiles') > 0,
    );
  }

  // Export user's personal data to JSON string
  Future<String> exportBackup() async {
    final profiles = await _db.select(_db.userProfiles).get();
    final sessions = await _db.select(_db.workoutSessions).get();
    final sets = await _db.select(_db.workoutSets).get();
    final meals = await _db.select(_db.userMeals).get();
    final mealItems = await _db.select(_db.mealItems).get();
    final routines = await _db.select(_db.routines).get();
    final routineExercises = await _db.select(_db.routineExercises).get();
    final formulas = await _db.select(_db.exerciseFormulas).get();

    // Only backup custom exercises and foods
    final customExercises = await (_db.select(
      _db.exercises,
    )..where((tbl) => tbl.isCustom.equals(true))).get();
    final customFoods = await (_db.select(
      _db.foods,
    )..where((tbl) => tbl.isCustom.equals(true))).get();

    final backupData = {
      'version': currentVersion,
      'backup_timestamp': DateTime.now().toIso8601String(),
      'profiles': profiles.map((e) => e.toJson()).toList(),
      'sessions': sessions.map((e) => e.toJson()).toList(),
      'sets': sets.map((e) => e.toJson()).toList(),
      'meals': meals.map((e) => e.toJson()).toList(),
      'meal_items': mealItems.map((e) => e.toJson()).toList(),
      'routines': routines.map((e) => e.toJson()).toList(),
      'routine_exercises': routineExercises.map((e) => e.toJson()).toList(),
      'custom_exercises': customExercises.map((e) => e.toJson()).toList(),
      'custom_foods': customFoods.map((e) => e.toJson()).toList(),
      'exercise_formulas': formulas.map((e) => e.toJson()).toList(),
    };

    return jsonEncode(backupData);
  }

  // Restore user's personal data from JSON string.
  //
  // Rows are upserted parents-first so foreign keys hold. Backups only carry
  // custom exercises/foods, so sets or meal items may reference catalog rows
  // that are not on this device yet; placeholders are created for those
  // (the next cloud sync overwrites them with the real catalog entries).
  //
  // Existing data is kept: rows with the same id are updated, others added.
  Future<void> restoreBackup(String jsonString) async {
    inspect(jsonString); // throws FormatException for invalid/unsupported files
    final Map<String, dynamic> backupData = jsonDecode(jsonString);

    List<Map<String, dynamic>> rows(String key) =>
        ((backupData[key] as List<dynamic>?) ?? const [])
            .cast<Map<String, dynamic>>();

    final sets = rows('sets').map(WorkoutSet.fromJson).toList();
    final mealItems = rows('meal_items').map(MealItem.fromJson).toList();
    final formulas = rows('exercise_formulas').map(ExerciseFormulaRow.fromJson).toList();

    await _db.transaction(() async {
      await _restoreProfile(rows('profiles'));
      for (final e in rows('custom_exercises')) {
        await _db.into(_db.exercises).insertOnConflictUpdate(Exercise.fromJson(e));
      }
      for (final f in rows('custom_foods')) {
        await _db.into(_db.foods).insertOnConflictUpdate(Food.fromJson(f));
      }
      for (final r in rows('routines')) {
        await _db.into(_db.routines).insertOnConflictUpdate(Routine.fromJson(r));
      }
      for (final re in rows('routine_exercises')) {
        await _db.into(_db.routineExercises).insertOnConflictUpdate(RoutineExercise.fromJson(re));
      }
      for (final s in rows('sessions')) {
        await _db.into(_db.workoutSessions).insertOnConflictUpdate(WorkoutSession.fromJson(s));
      }
      for (final m in rows('meals')) {
        await _db.into(_db.userMeals).insertOnConflictUpdate(UserMeal.fromJson(m));
      }

      await _ensureExercisesExist({
        ...sets.map((s) => s.exerciseId),
        ...formulas.map((f) => f.exerciseId),
      });
      await _ensureFoodsExist(mealItems.map((m) => m.foodId).toSet());

      for (final s in sets) {
        await _db.into(_db.workoutSets).insertOnConflictUpdate(s);
      }
      for (final mi in mealItems) {
        await _db.into(_db.mealItems).insertOnConflictUpdate(mi);
      }
      // Sets keep the load/calories stored in the backup, so restored
      // history is not recomputed.
      for (final f in formulas) {
        await _db.into(_db.exerciseFormulas).insertOnConflictUpdate(f);
      }
    });
  }

  /// The app has a single profile and every screen reads "the first one", so
  /// the backup's profile overwrites the local one (keeping the local id)
  /// instead of being added next to it. Extra profiles left behind by older
  /// restores are removed. Nothing references profiles, so this is safe.
  Future<void> _restoreProfile(List<Map<String, dynamic>> backupProfiles) async {
    if (backupProfiles.isEmpty) return;
    final restored = UserProfile.fromJson(backupProfiles.first);

    final local = await _db.select(_db.userProfiles).get();
    final keepId = local.isNotEmpty ? local.first.id : restored.id;

    await (_db.delete(_db.userProfiles)..where((t) => t.id.equals(keepId).not())).go();
    await _db.into(_db.userProfiles).insertOnConflictUpdate(restored.copyWith(id: keepId));
  }

  Future<void> _ensureExercisesExist(Set<String> ids) async {
    if (ids.isEmpty) return;
    final existing = await (_db.select(_db.exercises)..where((t) => t.id.isIn(ids))).get();
    final missing = ids.difference(existing.map((e) => e.id).toSet());
    for (final id in missing) {
      await _db.into(_db.exercises).insert(
            ExercisesCompanion.insert(
              id: id,
              name: 'Archived Exercise ($id)',
              targetMuscle: 'General',
              equipment: 'Other',
              description: const Value('Exercise restored from a backup.'),
              isCustom: const Value(false),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  Future<void> _ensureFoodsExist(Set<String> ids) async {
    if (ids.isEmpty) return;
    final existing = await (_db.select(_db.foods)..where((t) => t.id.isIn(ids))).get();
    final missing = ids.difference(existing.map((f) => f.id).toSet());
    for (final id in missing) {
      await _db.into(_db.foods).insert(
            FoodsCompanion.insert(
              id: id,
              name: 'Archived Food ($id)',
              calories: 0,
              protein: 0,
              carbs: 0,
              fat: 0,
              isCustom: const Value(false),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }
}
