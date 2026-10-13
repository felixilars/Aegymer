import 'dart:convert';
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

    // Only backup custom exercises and foods
    final customExercises = await (_db.select(
      _db.exercises,
    )..where((tbl) => tbl.isCustom.equals(true))).get();
    final customFoods = await (_db.select(
      _db.foods,
    )..where((tbl) => tbl.isCustom.equals(true))).get();

    final backupData = {
      'version': 1,
      'backup_timestamp': DateTime.now().toIso8601String(),
      'profiles': profiles.map((e) => e.toJson()).toList(),
      'sessions': sessions.map((e) => e.toJson()).toList(),
      'sets': sets.map((e) => e.toJson()).toList(),
      'meals': meals.map((e) => e.toJson()).toList(),
      'custom_exercises': customExercises.map((e) => e.toJson()).toList(),
      'custom_foods': customFoods.map((e) => e.toJson()).toList(),
    };

    return jsonEncode(backupData);
  }

  // Restore user's personal data from JSON string
  Future<void> restoreBackup(String jsonString) async {
    final Map<String, dynamic> backupData = jsonDecode(jsonString);

    await _db.transaction(() async {
      // Delete current user data before restoring
      // await _db.delete(_db.userProfiles).go();
      // await _db.delete(_db.workoutSessions).go();
      // await _db.delete(_db.workoutSets).go();
      // await _db.delete(_db.userMeals).go();
      // await (_db.delete(_db.exercises)..where((tbl) => tbl.isCustom.equals(true))).go();
      // await (_db.delete(_db.foods)..where((tbl) => tbl.isCustom.equals(true))).go();

      // Restore data
      for (var p in backupData['profiles']) {
        await _db.into(_db.userProfiles).insert(UserProfile.fromJson(p));
      }
      for (var e in backupData['custom_exercises']) {
        await _db.into(_db.exercises).insert(Exercise.fromJson(e));
      }
      for (var f in backupData['custom_foods']) {
        await _db.into(_db.foods).insert(Food.fromJson(f));
      }
      for (var s in backupData['sessions']) {
        await _db.into(_db.workoutSessions).insert(WorkoutSession.fromJson(s));
      }
      for (var s in backupData['sets']) {
        await _db.into(_db.workoutSets).insert(WorkoutSet.fromJson(s));
      }
      for (var m in backupData['meals']) {
        await _db.into(_db.userMeals).insert(UserMeal.fromJson(m));
      }
    });
  }
}
