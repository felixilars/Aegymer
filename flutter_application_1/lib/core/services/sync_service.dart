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
      List<dynamic> allData = [];
      int offset = 0;
      const int limit = 1000;
      bool hasMore = true;

      while (hasMore) {
        final response = await _supabase
            .from('global_exercises')
            .select()
            .range(offset, offset + limit - 1);
        final List<dynamic> data = response as List<dynamic>;
        allData.addAll(data);
        if (data.length < limit) {
          hasMore = false;
        } else {
          offset += limit;
        }
      }

      final companions = allData.map((item) {
        return ExercisesCompanion.insert(
          id: item['id'] as String,
          name: item['name'] as String,
          targetMuscle: item['target_muscle'] as String,
          equipment: item['equipment'] as String,
          description: Value(item['description'] as String?),
          videoUrl: Value(item['video_url'] as String?),
          isCustom: const Value(false),
          trackingType: Value(item['tracking_type'] as String?),
          secondaryTrackingTypes: Value(
            item['tracking_types'] != null
                ? (item['tracking_types'] is List
                    ? (item['tracking_types'] as List).join(',')
                    : item['tracking_types'].toString())
                : null,
          ),
        );
      }).toList();

      await _db.batch((batch) {
        batch.insertAll(_db.exercises, companions, mode: InsertMode.insertOrReplace);
      });
      print('Sync exercises completed successfully. Total synced: ${allData.length}');
    } catch (e) {
      print('Failed to sync exercises: $e');
    }
  }

  // Sync foods from Cloud to Local
  Future<void> syncFoodsFromCloud() async {
    try {
      List<dynamic> allData = [];
      int offset = 0;
      const int limit = 1000;
      bool hasMore = true;

      while (hasMore) {
        final response = await _supabase
            .from('global_foods')
            .select()
            .range(offset, offset + limit - 1);
        final List<dynamic> data = response as List<dynamic>;
        allData.addAll(data);
        if (data.length < limit) {
          hasMore = false;
        } else {
          offset += limit;
        }
      }

      final companions = allData.map((item) {
        return FoodsCompanion.insert(
          id: item['id'] as String,
          name: item['name'] as String,
          calories: (item['calories'] as num).toDouble(),
          protein: (item['protein'] as num).toDouble(),
          carbs: (item['carbs'] as num).toDouble(),
          fat: (item['fat'] as num).toDouble(),
          fiber: Value((item['fiber'] as num?)?.toDouble() ?? 0.0),
          sugar: Value((item['sugar'] as num?)?.toDouble() ?? 0.0),
          saturatedFat: Value((item['saturated_fat'] as num?)?.toDouble() ?? 0.0),
          sodium: Value((item['sodium'] as num?)?.toDouble() ?? 0.0),
          category: Value(item['category'] as String?),
          isCustom: const Value(false),
        );
      }).toList();

      await _db.batch((batch) {
        batch.insertAll(_db.foods, companions, mode: InsertMode.insertOrReplace);
      });
      print('Sync foods completed successfully. Total synced: ${allData.length}');
    } catch (e) {
      print('Failed to sync foods: $e');
    }
  }
}