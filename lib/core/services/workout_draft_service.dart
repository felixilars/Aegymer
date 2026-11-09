import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aegymer/core/databases/app_database.dart';
import 'package:aegymer/core/utils/workout_cal.dart';
import 'package:aegymer/core/services/streak_service.dart';
import 'package:aegymer/core/utils/workout_session_helper.dart';

class WorkoutDraftService {
  static const String keyWorkoutDraft = 'active_workout_draft';
  static int _clearGeneration = 0;

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
    Map<String, String>? weightEntryModes,
    Map<String, double>? barbellWeights,
  }) async {
    final int currentGen = _clearGeneration;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_clearGeneration != currentGen) {
        // clearDraft was called while this saveDraft was executing; do not write stale draft.
        return;
      }
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
        if (weightEntryModes != null) 'weightEntryModes': weightEntryModes,
        if (barbellWeights != null) 'barbellWeights': barbellWeights,
        'savedAt': DateTime.now().toIso8601String(),
      };
      if (_clearGeneration != currentGen) {
        return;
      }
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
    _clearGeneration++;
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
      final weightEntryModes = draft['weightEntryModes'] as Map<String, dynamic>? ?? {};
      final barbellWeights = draft['barbellWeights'] as Map<String, dynamic>? ?? {};

      double userBodyweight = 70.0;
      try {
        final profile = await (db.select(db.userProfiles)..limit(1)).getSingleOrNull();
        if (profile != null && profile.weight > 0) {
          userBodyweight = profile.weight;
        }
      } catch (_) {}

      // Count total non-empty sets to compute average duration
      int totalNonEmptySets = 0;
      for (final rawEx in rawExercises) {
        final exMap = rawEx as Map<String, dynamic>;
        final exId = exMap['id'] as String;
        final listSets = setsData[exId] as List<dynamic>? ?? [];
        for (final s in listSets) {
          final setMap = s as Map<String, dynamic>;
          final w = double.tryParse(setMap['weight']?.toString() ?? '0') ?? 0.0;
          final r = int.tryParse(setMap['reps']?.toString() ?? '0') ?? 0;
          final dist = double.tryParse(setMap['distance']?.toString() ?? '');
          final dur = _parseDurationSeconds(setMap['duration']);
          if (w > 0 || r > 0 || (dist != null && dist > 0) || (dur != null && dur > 0)) {
            totalNonEmptySets++;
          }
        }
      }

      final defaultAvgDuration = totalNonEmptySets > 0 && secondsElapsed > 0
          ? (secondsElapsed ~/ totalNonEmptySets)
          : 90;

      final sessionId = 'session-${DateTime.now().millisecondsSinceEpoch}';
      final companions = <WorkoutSetsCompanion>[];

      for (final rawEx in rawExercises) {
        final exMap = rawEx as Map<String, dynamic>;
        final exId = exMap['id'] as String;
        final exName = exMap['name']?.toString() ?? '';
        final listSets = setsData[exId] as List<dynamic>? ?? [];
        final mode = weightEntryModes[exId]?.toString() ?? 'total';
        final barW = (barbellWeights[exId] as num?)?.toDouble() ?? 20.0;
        final trackingType = WorkoutCalculator.normalizeTrackingType(
          exMap['trackingType']?.toString(),
          name: exName,
          targetMuscle: exMap['targetMuscle']?.toString() ?? '',
          equipment: exMap['equipment']?.toString() ?? '',
        );
        final isCardio = trackingType == 'cardio_time';
        final isTimeOnly = trackingType == 'time_only';

        int exerciseSetCounter = 0;

        for (int i = 0; i < listSets.length; i++) {
          final s = listSets[i] as Map<String, dynamic>;
          final w = double.tryParse(s['weight']?.toString() ?? '0') ?? 0.0;
          final r = int.tryParse(s['reps']?.toString() ?? '0') ?? 0;
          final dist = double.tryParse(s['distance']?.toString() ?? '');
          final dur = _parseDurationSeconds(s['duration']);
          // Weight variants only apply to bodyweight exercises, as on the
          // workout screen.
          final isBodyweightTracking = trackingType == 'bodyweight' ||
              trackingType == 'bodyweight_weighted' ||
              trackingType == 'bodyweight_assisted';
          final wType = isBodyweightTracking
              ? (s['weightType']?.toString() ?? 'standard')
              : 'standard';

          double actualWeight = w;
          if (mode == 'barbell') {
            actualWeight = 2.0 * w + barW;
          } else if (mode == 'dumbbell') {
            actualWeight = 2.0 * w;
          }

          // Same rule as the workout screen, so finishing from the launcher
          // saves exactly what "Finish" on the workout screen would.
          if (!WorkoutCalculator.isSetCompleted(
            trackingType: trackingType,
            totalWeight: actualWeight,
            reps: r,
            distance: dist ?? 0,
            durationSeconds: dur ?? 0,
            weightType: wType,
          )) {
            continue;
          }

          exerciseSetCounter++;

          final double effWeight = (wType == 'bodyweight' || wType == 'added' || wType == 'assisted')
              ? WorkoutCalculator.getEffectiveWeight(
                  weightInput: actualWeight,
                  weightType: wType,
                  userBodyweight: userBodyweight,
                  exerciseName: exName,
                )
              : actualWeight;

          // Use the exercise's tracking type (weightType is 'standard' for cardio).
          final isTimeOrCardio = isCardio || isTimeOnly;
          final e1rm = isTimeOrCardio ? 0.0 : WorkoutCalculator.calculateE1RM(effWeight, r);
          final bool hasDuration = dur != null && dur > 0;
          // Cardio keeps only the values the user entered; strength sets get an
          // estimated duration, used solely for calorie estimates.
          final int? durationSecs = hasDuration
              ? dur
              : (isCardio ? null : (defaultAvgDuration > 0 ? defaultAvgDuration : 90));

          companions.add(
            WorkoutSetsCompanion.insert(
              id: 'set-$sessionId-$exId-$i-${DateTime.now().microsecondsSinceEpoch}',
              sessionId: sessionId,
              exerciseId: exId,
              setNumber: exerciseSetCounter,
              weight: isTimeOrCardio ? 0.0 : effWeight,
              reps: isCardio ? 1 : (isTimeOnly ? (dur ?? r) : r),
              weightType: drift.Value(wType),
              distance: drift.Value(isCardio && dist != null && dist > 0 ? dist : null),
              durationSeconds: drift.Value(durationSecs),
              calculated1rm: drift.Value(e1rm > 0 ? e1rm : null),
            ),
          );
        }
      }

      if (companions.isEmpty) {
        await clearDraft();
        return false;
      }

      final draftRoutineName = draft['routineName']?.toString();
      final finalNotes = WorkoutSessionHelper.formatNotesWithRoutine(
        userNotes: notes,
        routineName: (draftRoutineName != null && draftRoutineName != 'Free Workout')
            ? draftRoutineName
            : null,
      );

      await db.saveWorkoutSession(
        sessionId: sessionId,
        date: workoutDate,
        notes: finalNotes,
        setsCompanions: companions,
      );

      await clearDraft();
      StreakService.notifyWorkoutUpdated();
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
