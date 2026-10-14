import 'dart:math';
import 'package:aegymer/core/services/knn_service.dart';
import 'package:aegymer/core/utils/workout_cal.dart';

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
  int get totalReps => reps.isNotEmpty ? reps.reduce((a, b) => a + b) : 0;
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

    // Lowered cold start: With 5+ sessions, we have sufficient history for ACWR and KNN
    if (history.length < 5) {
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

  // APRE protocol
  Map<String, dynamic> _suggestAPRE(ExerciseSessionHistory lastSession, int targetReps) {
    if (lastSession.reps.isEmpty || lastSession.weights.isEmpty) {
      return {'weight': 0.0, 'method': 'APRE'};
    }

    // Effective reps calculated from set 1 and session average reps.
    double sumReps = lastSession.reps.reduce((a, b) => a + b).toDouble();
    double avgReps = sumReps / lastSession.reps.length;
    double effectiveReps = (lastSession.reps.first + avgReps) / 2.0;

    double deltaR = effectiveReps - targetReps;
    double currentWeight = lastSession.workingWeight;
    double nextWeight;

    if (deltaR >= 2.0) {
      nextWeight = currentWeight + (2 * deltaW);
    } else if (deltaR >= 0.5) {
      nextWeight = currentWeight + deltaW;
    } else if (deltaR >= -1.5) {
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

  // 2. K-Nearest Neighbors Local ML Suggestion with Delta Progression
  Map<String, dynamic>? _suggestKNN(
    List<ExerciseSessionHistory> history,
    int daysRestNext,
  ) {
    if (history.length < 5) return null;

    // Training features: X, Delta weight progression target: y
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
      
      // For ACWR, we need past volumes before session i
      List<double> past4Volumes = [];
      if (i > 0) {
        int start = max(0, i - 4);
        past4Volumes = volumes.sublist(start, i);
      }
      double acwr = WorkoutCalculator.calculateACWR(volumes[i], past4Volumes);
      double restDays = nextSession.date.difference(currentSession.date).inDays.toDouble();

      X.add([w, totalReps, dropOff, acwr, restDays]);

      // Target is the weight change between consecutive sessions.
      double deltaProgression = nextSession.workingWeight - currentSession.workingWeight;
      y.add(deltaProgression);
    }

    if (X.isEmpty || y.isEmpty) return null;

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

    // Feature weights: give higher importance to readiness, fatigue, and recovery
    final featureWeights = [0.15, 0.35, 0.25, 0.15, 0.10];

    double predictedDelta = _knnService.predict(
      X,
      y,
      nextFeatures,
      weights: featureWeights,
    );
    
    // Suggested weight = last working weight + predicted progressive overload delta
    double rawSuggestedWeight = lastSession.workingWeight + predictedDelta;

    // Round to nearest deltaW
    double roundedWeight = (rawSuggestedWeight / deltaW).round() * deltaW;
    roundedWeight = max(0.0, roundedWeight);

    return {
      'weight': roundedWeight,
      'method': 'KNN (ML)',
    };
  }
}
