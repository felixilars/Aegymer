import 'package:drift/drift.dart';

import 'package:aegymer/core/databases/app_database.dart';
import 'package:aegymer/core/services/autoregulation_service.dart';

/// A next-session weight recommendation for one exercise.
class WeightSuggestion {
  /// Suggested total load in kg (bar + plates for barbell lifts, both
  /// dumbbells combined), matching how weights are stored in workout_sets.
  final double weight;

  /// Which rule produced it, e.g. 'APRE (Rule-Based)', 'KNN (ML)', 'Deload ...'.
  final String method;

  /// Working weight (first set) and its reps from the most recent session.
  final double lastWeight;
  final int lastReps;
  final DateTime lastDate;

  /// Number of past sessions the suggestion is based on.
  final int sessionCount;

  const WeightSuggestion({
    required this.weight,
    required this.method,
    required this.lastWeight,
    required this.lastReps,
    required this.lastDate,
    required this.sessionCount,
  });

  double get change => weight - lastWeight;
}

/// Builds per-session history from the database and runs the on-device
/// APRE / KNN autoregulation engine to suggest the next working weight.
class WeightSuggestionService {
  final AppDatabase _db;
  final AutoregulationService _engine;

  WeightSuggestionService(this._db, {AutoregulationService? engine})
      : _engine = engine ?? AutoregulationService();

  /// Returns a suggestion for [exerciseId], or null when there is no usable
  /// weight-and-reps history (new exercise, cardio, timed or bodyweight-only).
  ///
  /// Only sessions dated before [sessionDate] are used, so back-dated logging
  /// does not learn from the future.
  Future<WeightSuggestion?> suggestFor(
    String exerciseId, {
    required DateTime sessionDate,
  }) async {
    final history = await loadHistory(exerciseId, before: sessionDate);
    if (history.isEmpty) return null;

    final result = _engine.suggestNextWorkout(
      history: history,
      nextSessionDate: sessionDate,
      targetReps: _usualReps(history),
    );
    final weight = (result['weight'] as num?)?.toDouble() ?? 0.0;
    if (weight <= 0) return null;

    final last = history.last;
    return WeightSuggestion(
      weight: weight,
      method: result['method']?.toString() ?? 'APRE (Rule-Based)',
      lastWeight: last.workingWeight,
      lastReps: last.reps.first,
      lastDate: last.date,
      sessionCount: history.length,
    );
  }

  /// Past sessions for [exerciseId], oldest first, each holding its standard
  /// weighted sets in set order.
  Future<List<ExerciseSessionHistory>> loadHistory(
    String exerciseId, {
    required DateTime before,
  }) async {
    final rows = await (_db.select(_db.workoutSets).join([
      innerJoin(
        _db.workoutSessions,
        _db.workoutSessions.id.equalsExp(_db.workoutSets.sessionId),
      ),
    ])
          ..where(_db.workoutSets.exerciseId.equals(exerciseId) &
              _db.workoutSessions.date.isSmallerThanValue(before))
          ..orderBy([
            OrderingTerm.asc(_db.workoutSessions.date),
            OrderingTerm.asc(_db.workoutSets.setNumber),
          ]))
        .get();

    final bySession = <String, ({DateTime date, List<double> weights, List<int> reps})>{};
    for (final row in rows) {
      final set = row.readTable(_db.workoutSets);
      // Plain external-load sets only: skip bodyweight variants, cardio
      // (distance recorded) and timed holds (stored with weight 0).
      final isStandard = set.weightType == null || set.weightType == 'standard';
      if (!isStandard || set.distance != null || set.weight <= 0 || set.reps <= 0) {
        continue;
      }
      final session = row.readTable(_db.workoutSessions);
      final entry = bySession.putIfAbsent(
        session.id,
        () => (date: session.date, weights: <double>[], reps: <int>[]),
      );
      entry.weights.add(set.weight);
      entry.reps.add(set.reps);
    }

    // Map preserves insertion order, which is already date-ascending.
    return bySession.values
        .map((s) => ExerciseSessionHistory(date: s.date, weights: s.weights, reps: s.reps))
        .toList();
  }

  /// The rep target APRE compares against: the median first-set reps of the
  /// sessions before the latest one (up to 5). Beating your usual reps
  /// suggests going heavier; falling well short suggests backing off.
  static int _usualReps(List<ExerciseSessionHistory> history) {
    final earlier = history.length > 1 ? history.sublist(0, history.length - 1) : history;
    final recent = earlier.length > 5 ? earlier.sublist(earlier.length - 5) : earlier;
    final reps = recent.map((s) => s.reps.first).toList()..sort();
    return reps[reps.length ~/ 2];
  }
}
