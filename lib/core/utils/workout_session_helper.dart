import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' as drift;
import 'package:aegymer/core/databases/app_database.dart';

/// Helper to manage workout session titles, routine tags, and user notes.
class WorkoutSessionHelper {
  static const String routinePrefix = '[Routine:';

  /// Extracts the routine name if encoded in notes with `[Routine: <name>]`.
  static String? extractRoutineTag(String? notes) {
    if (notes == null || notes.trim().isEmpty) return null;
    final trimmed = notes.trim();
    if (!trimmed.startsWith(routinePrefix)) return null;

    final closeIdx = trimmed.indexOf(']');
    if (closeIdx <= routinePrefix.length) return null;

    final name = trimmed.substring(routinePrefix.length, closeIdx).trim();
    return name.isNotEmpty ? name : null;
  }

  /// Removes the `[Routine: ...]` prefix from notes so user sees only their actual notes.
  static String cleanNotes(String? notes) {
    if (notes == null) return '';
    final trimmed = notes.trim();
    if (!trimmed.startsWith(routinePrefix)) return trimmed;

    final closeIdx = trimmed.indexOf(']');
    if (closeIdx < 0) return trimmed;

    return trimmed.substring(closeIdx + 1).trim();
  }

  /// Formats user notes with an optional routine tag header.
  static String? formatNotesWithRoutine({
    required String? userNotes,
    String? routineName,
  }) {
    final clean = cleanNotes(userNotes);
    final hasRoutine = routineName != null &&
        routineName.trim().isNotEmpty &&
        routineName.trim() != 'Free Workout';

    if (!hasRoutine) {
      return clean.isNotEmpty ? clean : null;
    }

    final tag = '[Routine: ${routineName.trim()}]';
    if (clean.isEmpty) {
      return tag;
    }
    return '$tag\n$clean';
  }

  /// Finds the best matching saved routine based on exercise IDs.
  static String? matchRoutineNameByExercises({
    required List<String> sessionExerciseIds,
    required List<RoutineWithExercises> routines,
  }) {
    if (sessionExerciseIds.isEmpty || routines.isEmpty) return null;

    final sessionSet = sessionExerciseIds.toSet();

    RoutineWithExercises? bestRoutine;
    double bestScore = 0.0;

    for (final routine in routines) {
      if (routine.exercises.isEmpty) continue;
      final routineSet = routine.exercises.map((e) => e.id).toSet();

      final intersection = sessionSet.intersection(routineSet);
      if (intersection.isEmpty) continue;

      final routineCoverage = intersection.length / routineSet.length;
      final sessionCoverage = intersection.length / sessionSet.length;
      final score = (routineCoverage * 0.6) + (sessionCoverage * 0.4);

      // Match if at least 50% of the routine's exercises were completed and score is highest
      if (routineCoverage >= 0.5 && score > bestScore) {
        bestScore = score;
        bestRoutine = routine;
      }
    }

    if (bestRoutine != null && bestScore >= 0.4) {
      return bestRoutine.routine.name;
    }

    return null;
  }

  /// Resolves the user-facing display name for a workout session:
  /// 1. If explicit routine tag is found in notes -> returns it.
  /// 2. If exercises match a saved routine -> returns routine name.
  /// 3. Otherwise -> returns 'Workout #${index + 1}'.
  static Future<String> resolveSessionName({
    required WorkoutSession session,
    required AppDatabase db,
    int? index,
    List<RoutineWithExercises>? cachedRoutines,
    List<String>? sessionExerciseIds,
  }) async {
    // 1. Check tag in notes
    final tag = extractRoutineTag(session.notes);
    if (tag != null && tag.isNotEmpty) {
      return tag;
    }

    // 2. Fetch routines if not provided
    final routines = cachedRoutines ?? await db.getRoutinesWithExercises();

    // 3. Fetch exercise IDs if not provided
    List<String> exerciseIds = sessionExerciseIds ?? [];
    if (exerciseIds.isEmpty) {
      try {
        final query = db.selectOnly(db.workoutSets, distinct: true)
          ..addColumns([db.workoutSets.exerciseId])
          ..where(db.workoutSets.sessionId.equals(session.id));
        final rows = await query.get();
        exerciseIds = rows
            .map((r) => r.read(db.workoutSets.exerciseId))
            .whereType<String>()
            .toList();
      } catch (e) {
        debugPrint('Error loading exercise IDs for session ${session.id}: $e');
      }
    }

    // 4. Try matching against saved routines
    final matchedName = matchRoutineNameByExercises(
      sessionExerciseIds: exerciseIds,
      routines: routines,
    );
    if (matchedName != null && matchedName.isNotEmpty) {
      return matchedName;
    }

    // 5. Fallback for freestyle workouts
    final fallbackNum = (index != null && index >= 0) ? index + 1 : 1;
    return 'Workout #$fallbackNum';
  }
}
