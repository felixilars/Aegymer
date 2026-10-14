import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aegymer/core/databases/app_database.dart';
import 'package:aegymer/core/constants/default_seed_exercises.dart';

enum CloudConnectionStatus {
  idle,
  connecting,
  connected,
  offline,
  serverError,
}

class CloudSyncState {
  final CloudConnectionStatus status;
  final String? message;
  final DateTime? lastSyncTime;

  const CloudSyncState({
    required this.status,
    this.message,
    this.lastSyncTime,
  });

  factory CloudSyncState.initial() => const CloudSyncState(
        status: CloudConnectionStatus.idle,
      );
}

class SyncService {
  static const String supabaseUrl = 'https://faegwvospgqmsurjpbvo.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZhZWd3dm9zcGdxbXN1cmpwYnZvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE1ODk5MTIsImV4cCI6MjA5NzE2NTkxMn0.gLY0YRlHwNwLOCLEI8Ob-hxtMcT7EtBhXCQQBJQytls';

  final AppDatabase _db;
  final bool isSupabaseConfigured;

  // Global observable state for UI banners and status dialogs
  static final ValueNotifier<CloudSyncState> syncState =
      ValueNotifier(CloudSyncState.initial());

  SyncService(this._db, {this.isSupabaseConfigured = true});

  static bool get isSupabaseInitialized {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Ensures Supabase is initialized even if initial launch failed while server was paused
  static Future<bool> ensureSupabaseReady() async {
    if (isSupabaseInitialized) return true;
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      return true;
    } catch (e) {
      debugPrint('[SyncService] Supabase initialize attempt failed: $e');
      return false;
    }
  }

  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Initialize and sync:
  /// 1. Immediately seed default exercises if local database is empty
  /// 2. Background attempt to sync from Supabase cloud
  Future<void> initializeAndSync() async {
    // Step 1: Ensure local database is never empty
    await seedDefaultExercisesIfNeeded();
    await ensureUserReferencedExercisesPreserved();

    // Step 2: Attempt connection and initialization
    final ready = await ensureSupabaseReady();
    final client = _supabase;
    if (!ready || client == null) {
      syncState.value = CloudSyncState(
        status: CloudConnectionStatus.offline,
        message: 'Online exercise library is unreachable. Using built-in local exercise catalog.',
        lastSyncTime: DateTime.now(),
      );
      return;
    }

    await syncExercisesFromCloud();
    await syncFoodsFromCloud();
  }

  /// Seeds the local database with core foundational exercises if no exercises exist
  Future<void> seedDefaultExercisesIfNeeded() async {
    try {
      final existingCount = await (_db.selectOnly(_db.exercises)
            ..addColumns([_db.exercises.id.count()]))
          .map((row) => row.read(_db.exercises.id.count()))
          .getSingle();

      if (existingCount == null || existingCount == 0) {
        debugPrint('[SyncService] Local exercise database empty. Seeding core fallback exercises...');
        await _db.batch((batch) {
          batch.insertAll(
            _db.exercises,
            DefaultSeedExercises.coreExercises,
            mode: InsertMode.insertOrIgnore,
          );
        });
        debugPrint('[SyncService] Successfully seeded ${DefaultSeedExercises.coreExercises.length} core exercises.');
      }
    } catch (e) {
      debugPrint('[SyncService] Error seeding default exercises: $e');
    }
  }

  /// Ensures that any exercise that has been recorded in workout sets or routines
  /// is preserved and never missing from the exercises table.
  Future<void> ensureUserReferencedExercisesPreserved() async {
    try {
      // Find all distinct exercise IDs used in past workout sets
      final querySets = _db.selectOnly(_db.workoutSets, distinct: true)
        ..addColumns([_db.workoutSets.exerciseId]);
      final usedIdsFromSets = await querySets.map((row) => row.read(_db.workoutSets.exerciseId)).get();

      // Find all distinct exercise IDs used in routines
      final queryRoutines = _db.selectOnly(_db.routineExercises, distinct: true)
        ..addColumns([_db.routineExercises.exerciseId]);
      final usedIdsFromRoutines = await queryRoutines.map((row) => row.read(_db.routineExercises.exerciseId)).get();

      final allReferencedIds = {...usedIdsFromSets, ...usedIdsFromRoutines}.whereType<String>().toSet();

      if (allReferencedIds.isEmpty) return;

      // Check which of these are currently in the exercises table
      final existingExercises = await (_db.select(_db.exercises)
            ..where((tbl) => tbl.id.isIn(allReferencedIds)))
          .get();
      final existingIdSet = existingExercises.map((e) => e.id).toSet();

      // Any missing ones get an auto-recovered placeholder record so the user never loses past history
      final missingIds = allReferencedIds.difference(existingIdSet);
      if (missingIds.isNotEmpty) {
        final companions = missingIds.map((id) {
          return ExercisesCompanion.insert(
            id: id,
            name: 'Archived Exercise ($id)',
            targetMuscle: 'General',
            equipment: 'Other',
            description: const Value('Exercise restored from past workout history.'),
            isCustom: const Value(true),
          );
        }).toList();

        await _db.batch((batch) {
          batch.insertAll(_db.exercises, companions, mode: InsertMode.insertOrIgnore);
        });
        debugPrint('[SyncService] Restored ${missingIds.length} historical exercises.');
      }
    } catch (e) {
      debugPrint('[SyncService] Error checking user referenced exercises: $e');
    }
  }

  // Sync exercises from Cloud to Local
  Future<void> syncExercisesFromCloud() async {
    final client = _supabase;
    if (client == null) {
      _setOfflineState('Supabase client is not configured.');
      await seedDefaultExercisesIfNeeded();
      return;
    }

    syncState.value = const CloudSyncState(
      status: CloudConnectionStatus.connecting,
      message: 'Connecting and syncing exercises from cloud...',
    );

    try {
      List<dynamic> allData = [];
      int offset = 0;
      const int limit = 1000;
      bool hasMore = true;

      while (hasMore) {
        final response = await client
            .from('global_exercises')
            .select()
            .range(offset, offset + limit - 1)
            .timeout(const Duration(seconds: 10));

        final List<dynamic> data = response as List<dynamic>;
        allData.addAll(data);
        if (data.length < limit) {
          hasMore = false;
        } else {
          offset += limit;
        }
      }

      if (allData.isNotEmpty) {
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
      }

      syncState.value = CloudSyncState(
        status: CloudConnectionStatus.connected,
        message: 'Successfully synced ${allData.length} exercises from cloud.',
        lastSyncTime: DateTime.now(),
      );
      debugPrint('[SyncService] Sync exercises completed successfully. Total: ${allData.length}');
    } catch (e) {
      debugPrint('[SyncService] Failed to sync exercises: $e');
      _setOfflineState('Unable to connect to Supabase server ($e).');
      // Ensure offline fallback is present
      await seedDefaultExercisesIfNeeded();
    }
  }

  // Sync foods from Cloud to Local
  Future<void> syncFoodsFromCloud() async {
    final client = _supabase;
    if (client == null) return;

    try {
      List<dynamic> allData = [];
      int offset = 0;
      const int limit = 1000;
      bool hasMore = true;

      while (hasMore) {
        final response = await client
            .from('global_foods')
            .select()
            .range(offset, offset + limit - 1)
            .timeout(const Duration(seconds: 10));

        final List<dynamic> data = response as List<dynamic>;
        allData.addAll(data);
        if (data.length < limit) {
          hasMore = false;
        } else {
          offset += limit;
        }
      }

      if (allData.isNotEmpty) {
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
      }
      debugPrint('[SyncService] Sync foods completed successfully. Total: ${allData.length}');
    } catch (e) {
      debugPrint('[SyncService] Failed to sync foods: $e');
    }
  }

  void _setOfflineState(String reason) {
    syncState.value = CloudSyncState(
      status: CloudConnectionStatus.offline,
      message: reason,
      lastSyncTime: DateTime.now(),
    );
  }
}