import 'package:aegymer/core/databases/app_database.dart';

/// Values to use when reading a saved set back for stats and charts.
extension WorkoutSetMetrics on WorkoutSet {
  /// Load counted for volume and e1RM: the exercise's custom load formula
  /// result if one applied when the set was saved, else the stored weight.
  double get loadKg => effectiveLoad ?? weight;
}
