import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:aegymer/core/databases/app_database.dart';

class BackupService {
  final AppDatabase _db;

  BackupService(this._db);

  // Export user's personal data to JSON string
  Future<String> exportBackup() async {
    final profiles = await _db.select(_db.userProfiles).get();
    final sessions = await _db.select(_db.workoutSessions).get();
    final sets = await _db.select(_db.workoutSets).get();
    final meals = await _db.select(_db.userMeals).get();
    final mealItems = await _db.select(_db.mealItems).get();
    final routines = await _db.select(_db.routines).get();
    final routineExercises = await _db.select(_db.routineExercises).get();

    // Only backup custom exercises and foods
    final customExercises = await (_db.select(
      _db.exercises,
    )..where((tbl) => tbl.isCustom.equals(true))).get();
    final customFoods = await (_db.select(
      _db.foods,
    )..where((tbl) => tbl.isCustom.equals(true))).get();

    final backupData = {
      'version': 2,
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
    };

    return jsonEncode(backupData);
  }

  // Restore user's personal data from JSON string
  Future<void> restoreBackup(String jsonString) async {
    final Map<String, dynamic> backupData = jsonDecode(jsonString);

    await _db.transaction(() async {
      if (backupData['profiles'] != null) {
        for (var p in backupData['profiles']) {
          await _db.into(_db.userProfiles).insert(UserProfile.fromJson(p), mode: InsertMode.insertOrReplace);
        }
      }
      if (backupData['custom_exercises'] != null) {
        for (var e in backupData['custom_exercises']) {
          await _db.into(_db.exercises).insert(Exercise.fromJson(e), mode: InsertMode.insertOrReplace);
        }
      }
      if (backupData['custom_foods'] != null) {
        for (var f in backupData['custom_foods']) {
          await _db.into(_db.foods).insert(Food.fromJson(f), mode: InsertMode.insertOrReplace);
        }
      }
      if (backupData['routines'] != null) {
        for (var r in backupData['routines']) {
          await _db.into(_db.routines).insert(Routine.fromJson(r), mode: InsertMode.insertOrReplace);
        }
      }
      if (backupData['routine_exercises'] != null) {
        for (var re in backupData['routine_exercises']) {
          await _db.into(_db.routineExercises).insert(RoutineExercise.fromJson(re), mode: InsertMode.insertOrReplace);
        }
      }
      if (backupData['sessions'] != null) {
        for (var s in backupData['sessions']) {
          await _db.into(_db.workoutSessions).insert(WorkoutSession.fromJson(s), mode: InsertMode.insertOrReplace);
        }
      }
      if (backupData['sets'] != null) {
        for (var s in backupData['sets']) {
          await _db.into(_db.workoutSets).insert(WorkoutSet.fromJson(s), mode: InsertMode.insertOrReplace);
        }
      }
      if (backupData['meals'] != null) {
        for (var m in backupData['meals']) {
          await _db.into(_db.userMeals).insert(UserMeal.fromJson(m), mode: InsertMode.insertOrReplace);
        }
      }
      if (backupData['meal_items'] != null) {
        for (var mi in backupData['meal_items']) {
          await _db.into(_db.mealItems).insert(MealItem.fromJson(mi), mode: InsertMode.insertOrReplace);
        }
      }
    });
  }
}
