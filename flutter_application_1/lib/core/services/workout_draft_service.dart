import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aegymer/core/databases/app_database.dart';
import 'package:aegymer/core/utils/workout_cal.dart';
import 'package:aegymer/core/services/streak_service.dart';

class WorkoutDraftService {
  static const String keyWorkoutDraft = 'active_workout_draft';

  /// Save workout draft to SharedPreferences
  static Future<void> saveDraft({
    required DateTime workoutDate,
    required DateTime sessionStartTime,
    required int secondsElapsed,
    required String notes,
    String? routineId,
    String? routineName,
    required List<Exercise> exercises,
    required Map<String, String> trackingTypes,
    required Map<String, List<Map<String, dynamic>>> setsData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draft = {
        'workoutDate': workoutDate.toIso8601String(),
        'sessionStartTime': sessionStartTime.toIso8601String(),
        'secondsElapsed': secondsElapsed,
        'notes': notes,
        'routineId': routineId,
        'routineName': routineName,
        'exercises': exercises.map((e) => {
          'id': e.id,
          'name': e.name,
          'targetMuscle': e.targetMuscle,
          'equipment': e.equipment,
          'trackingType': trackingTypes[e.id] ?? e.trackingType,
        }).toList(),
        'trackingTypes': trackingTypes,
        'setsData': setsData,
        'savedAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString(keyWorkoutDraft, jsonEncode(draft));
    } catch (e) {
      debugPrint('Error saving workout draft: $e');
    }
  }

  /// Get active workout draft if one exists
  static Future<Map<String, dynamic>?> getDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(keyWorkoutDraft);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded;
    } catch (e) {
      debugPrint('Error reading workout draft: $e');
      return null;
    }
  }

  /// Clear the active draft (e.g. after finish or discard)
  static Future<void> clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyWorkoutDraft);
    } catch (e) {
      debugPrint('Error clearing workout draft: $e');
    }
  }

  /// Immediately finish and save an active draft directly to database without re-opening screen
  static Future<bool> finishAndSaveDraft(AppDatabase db, Map<String, dynamic> draft) async {
    try {
      final workoutDateStr = draft['workoutDate'] as String?;
      final workoutDate = workoutDateStr != null ? DateTime.parse(workoutDateStr) : DateTime.now();
      final notes = (draft['notes'] as String?)?.trim();
      final secondsElapsed = draft['secondsElapsed'] as int? ?? 0;
      final setsData = draft['setsData'] as Map<String, dynamic>? ?? {};
      final rawExercises = draft['exercises'] as List<dynamic>? ?? [];

      final sessionId = 'session-${DateTime.now().millisecondsSinceEpoch}';
      final companions = <WorkoutSetsCompanion>[];

      for (final rawEx in rawExercises) {
        final exMap = rawEx as Map<String, dynamic>;
        final exId = exMap['id'] as String;
        final listSets = setsData[exId] as List<dynamic>? ?? [];

        for (int i = 0; i < listSets.length; i++) {
          final s = listSets[i] as Map<String, dynamic>;
          final w = double.tryParse(s['weight']?.toString() ?? '0') ?? 0.0;
          final r = int.tryParse(s['reps']?.toString() ?? '0') ?? 0;
          final dist = double.tryParse(s['distance']?.toString() ?? '');
          final dur = _parseDurationSeconds(s['duration']);
          final wType = s['weightType']?.toString() ?? 'standard';

          // Skip sets that are completely empty
          if (w == 0 && r == 0 && (dist == null || dist == 0) && (dur == null || dur == 0)) {
            continue;
          }

          final e1rm = WorkoutCalculator.calculateE1RM(w, r);
          final durationSecs = dur ?? (secondsElapsed > 0 ? (secondsElapsed ~/ (companions.length + 1)) : 90);

          companions.add(
            WorkoutSetsCompanion.insert(
              id: 'set-$sessionId-$exId-$i-${DateTime.now().microsecondsSinceEpoch}',
              sessionId: sessionId,
              exerciseId: exId,
              setNumber: companions.length + 1,
              weight: w,
              reps: r,
              weightType: drift.Value(wType),
              distance: drift.Value(dist),
              durationSeconds: drift.Value(durationSecs > 0 ? durationSecs : 90),
              calculated1rm: drift.Value(e1rm > 0 ? e1rm : null),
            ),
          );
        }
      }

      if (companions.isEmpty) {
        await clearDraft();
        return false;
      }

      await db.saveWorkoutSession(
        sessionId: sessionId,
        date: workoutDate,
        notes: notes,
        setsCompanions: companions,
      );

      StreakService.notifyWorkoutUpdated();
      await clearDraft();
      return true;
    } catch (e) {
      debugPrint('Error saving draft directly: $e');
      return false;
    }
  }

  static int? _parseDurationSeconds(dynamic val) {
    if (val == null) return null;
    final text = val.toString().trim();
    if (text.isEmpty) return null;
    if (text.contains(':')) {
      final parts = text.split(':');
      if (parts.length == 2) {
        final m = int.tryParse(parts[0]) ?? 0;
        final s = int.tryParse(parts[1]) ?? 0;
        return m * 60 + s;
      } else if (parts.length == 3) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        final s = int.tryParse(parts[2]) ?? 0;
        return h * 3600 + m * 60 + s;
      }
    }
    return int.tryParse(text);
  }
}
