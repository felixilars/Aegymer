import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/core/databases/app_database.dart';

class SyncService {
  final AppDatabase _db;
  final SupabaseClient _supabase = Supabase.instance.client;

  SyncService(this._db);

  // Sync exercises from Cloud to Local
  Future<void> syncExercisesFromCloud() async {
    try {
      final response = await _supabase.from('global_exercises').select();
      final List<dynamic> data = response as List<dynamic>;

      await _db.transaction(() async {
        for (var item in data) {
          await _db
              .into(_db.exercises)
              .insertOnConflictUpdate(
                ExercisesCompanion.insert(
                  id: item['id'] as String,
                  name: item['name'] as String,
                  targetMuscle: item['target_muscle'] as String,
                  equipment: item['equipment'] as String,
                  description: Value(item['description'] as String?),
                  videoUrl: Value(item['video_url'] as String?),
                  isCustom: const Value(
                    false,
                  ), // Global data so isCustom = false
                ),
              );
        }
      });
      print('Sync exercises completed successfully.');
    } catch (e) {
      print('Failed to sync exercises: $e');
    }
  }

  // Sync foods from Cloud to Local
  Future<void> syncFoodsFromCloud() async {
    try {
      final response = await _supabase.from('global_foods').select();
      final List<dynamic> data = response as List<dynamic>;

      await _db.transaction(() async {
        for (var item in data) {
          await _db
              .into(_db.foods)
              .insertOnConflictUpdate(
                FoodsCompanion.insert(
                  id: item['id'] as String,
                  name: item['name'] as String,
                  calories: (item['calories'] as num).toDouble(),
                  protein: (item['protein'] as num).toDouble(),
                  carbs: (item['carbs'] as num).toDouble(),
                  fat: (item['fat'] as num).toDouble(),
                  category: Value(item['category'] as String?),
                  isCustom: const Value(false),
                ),
              );
        }
      });
      print('Sync foods completed successfully.');
    } catch (e) {
      print('Failed to sync foods: $e');
    }
  }
}
