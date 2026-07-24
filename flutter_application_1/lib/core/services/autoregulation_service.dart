import 'dart:math';
import 'package:flutter_application_1/core/services/knn_service.dart';
import 'package:flutter_application_1/core/utils/workout_cal.dart';

class ExerciseSessionHistory {
  final DateTime date;
  final List<double> weights;
  final List<int> reps;

  ExerciseSessionHistory({
    required this.date,
    required this.weights,
    required this.reps,
  });

  double get workingWeight => weights.isNotEmpty ? weights.first : 0.0;
  int get totalReps => reps.reduce((a, b) => a + b);
}

class AutoregulationService {
  final KNearestNeighborsService _knnService;
  final double deltaW; // Default weight step size (e.g. 2.5 kg)

  AutoregulationService({
    KNearestNeighborsService? knnService,
    this.deltaW = 2.5,
  }) : _knnService = knnService ?? KNearestNeighborsService();

  /// Suggests the weight and reps for the next session.
  /// [history] is the list of past session history sorted by date ascending.
  /// [nextSessionDate] is when the upcoming session is scheduled (usually DateTime.now()).
  /// [targetReps] is the target reps per set (default: 10).
  /// Returns a Map containing:
  ///   'weight': double - Suggested weight in kg
  ///   'method': String - 'APRE' (rule-based) or 'KNN (ML)' or 'Deload' (safety rule)
  Map<String, dynamic> suggestNextWorkout({ 
    required List<ExerciseSessionHistory> history,
    required DateTime nextSessionDate,
    int targetReps = 10,
  }) {
    if (history.isEmpty) {
      // No history, return empty or starting suggestion
      return {
        'weight': 0.0,
        'method': 'Initial',
      };
    }

    final lastSession = history.last;
    final int daysRestNext = nextSessionDate.difference(lastSession.date).inDays;

    // Hard Deload Rule: If rest is greater than 14 days, reduce by 10%
    if (daysRestNext > 14) {
      double suggestedWeight = lastSession.workingWeight * 0.9;
      // Round to nearest deltaW
      suggestedWeight = (suggestedWeight / deltaW).round() * deltaW;
      return {
        'weight': max(0.0, suggestedWeight),
        'method': 'Deload (Rest > 14 days)',
      };
    }

    // If we have less than 10 sessions, use APRE rule-based protocol (Cold Start)
    if (history.length < 10) {
      return _suggestAPRE(lastSession, targetReps);
    }

    // Otherwise, use K-Nearest Neighbors (KNN) ML model
    try {
      final suggestion = _suggestKNN(history, daysRestNext);
      if (suggestion != null) {
        return suggestion;
      }
    } catch (e) {
      // Fallback to APRE on any ML training failure
    }

    return _suggestAPRE(lastSession, targetReps);
  }

  // 1. Rule-Based APRE Protocol (AMRAP on last set)
  Map<String, dynamic> _suggestAPRE(ExerciseSessionHistory lastSession, int targetReps) {
    if (lastSession.reps.isEmpty || lastSession.weights.isEmpty) {
      return {'weight': 0.0, 'method': 'APRE'};
    }

    int actualLastSetReps = lastSession.reps.last;
    int deltaR = actualLastSetReps - targetReps;
    double currentWeight = lastSession.workingWeight;
    double nextWeight;

    if (deltaR >= 3) {
      nextWeight = currentWeight + (2 * deltaW);
    } else if (deltaR >= 1) {
      nextWeight = currentWeight + deltaW;
    } else if (deltaR >= -1) {
      nextWeight = currentWeight;
    } else {
      nextWeight = currentWeight - deltaW;
    }

    nextWeight = max(0.0, nextWeight);

    return {
      'weight': nextWeight,
      'method': 'APRE (Rule-Based)',
    };
  }

  // 2. K-Nearest Neighbors Local ML Suggestion
  Map<String, dynamic>? _suggestKNN(
    List<ExerciseSessionHistory> history,
    int daysRestNext,
  ) {
    // We need at least 10 sessions to predict.
    if (history.length < 10) return null;

    // training features: X, target: y
    List<List<double>> X = [];
    List<double> y = [];

    // Calculate all volume history to compute ACWR
    List<double> volumes = history.map((s) => WorkoutCalculator.calculateVolume(s.weights, s.reps)).toList();

    for (int i = 0; i < history.length - 1; i++) {
      final currentSession = history[i];
      final nextSession = history[i + 1];

      // Features of session i:
      // - W_i: workingWeight
      // - total_reps: sum of reps
      // - drop_off: drop-off rate
      // - acwr: acute to chronic workload ratio
      // - days_rest_next: difference between nextSession and currentSession
      double w = currentSession.workingWeight;
      double totalReps = currentSession.totalReps.toDouble();
      double dropOff = WorkoutCalculator.calculateDropOffRate(currentSession.reps);
      
      // For ACWR, we need past 4 volumes before session i
      List<double> past4Volumes = [];
      if (i > 0) {
        int start = max(0, i - 4);
        past4Volumes = volumes.sublist(start, i);
      }
      double acwr = WorkoutCalculator.calculateACWR(volumes[i], past4Volumes);
      double restDays = nextSession.date.difference(currentSession.date).inDays.toDouble();

      X.add([w, totalReps, dropOff, acwr, restDays]);
      y.add(nextSession.workingWeight);
    }

    // Predict for the upcoming session using features of the last session
    final lastSession = history.last;
    double wLast = lastSession.workingWeight;
    double repsLast = lastSession.totalReps.toDouble();
    double dropOffLast = WorkoutCalculator.calculateDropOffRate(lastSession.reps);
    
    // Past 4 volumes for last session
    int start = max(0, history.length - 5);
    List<double> past4Volumes = volumes.sublist(start, history.length - 1);
    double acwrLast = WorkoutCalculator.calculateACWR(volumes.last, past4Volumes);

    List<double> nextFeatures = [
      wLast,
      repsLast,
      dropOffLast,
      acwrLast,
      daysRestNext.toDouble(),
    ];

    double predictedWeight = _knnService.predict(X, y, nextFeatures);
    
    // Round to nearest deltaW
    double roundedWeight = (predictedWeight / deltaW).round() * deltaW;
    roundedWeight = max(0.0, roundedWeight);

    return {
      'weight': roundedWeight,
      'method': 'KNN (ML)',
    };
  }
}
