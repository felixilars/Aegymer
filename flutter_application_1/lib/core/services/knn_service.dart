import 'dart:math';

class KNearestNeighborsService {
  final int k;
  KNearestNeighborsService({this.k = 3});

  /// Predicts the target value using KNN regression with inverse distance weighting.
  /// [X] is a list of training feature vectors.
  /// [y] is a list of training target values.
  /// [targetX] is the feature vector of the target to predict.
  /// [weights] is an optional vector of feature importance weights for weighted Euclidean distance.
  double predict(
    List<List<double>> X,
    List<double> y,
    List<double> targetX, {
    List<double>? weights,
  }) {
    if (X.isEmpty || y.isEmpty || X.length != y.length || targetX.isEmpty) {
      return 0.0;
    }

    if (X.any((row) => row.length != targetX.length)) {
      return 0.0;
    }

    int numSamples = X.length;
    int numFeatures = targetX.length;

    // Min-Max Normalization
    List<double> mins = List.filled(numFeatures, double.infinity);
    List<double> maxs = List.filled(numFeatures, -double.infinity);

    for (int j = 0; j < numFeatures; j++) {
      double targetVal = targetX[j];
      mins[j] = min(mins[j], targetVal);
      maxs[j] = max(maxs[j], targetVal);

      for (int i = 0; i < numSamples; i++) {
        double val = X[i][j];
        mins[j] = min(mins[j], val);
        maxs[j] = max(maxs[j], val);
      }
    }

    // Normalize X and targetX
    List<List<double>> normX = List.generate(
      numSamples,
      (i) => List.filled(numFeatures, 0.0),
    );
    List<double> normTargetX = List.filled(numFeatures, 0.0);

    for (int j = 0; j < numFeatures; j++) {
      double range = maxs[j] - mins[j];
      if (range == 0) {
        normTargetX[j] = 0.5;
        for (int i = 0; i < numSamples; i++) {
          normX[i][j] = 0.5;
        }
      } else {
        normTargetX[j] = (targetX[j] - mins[j]) / range;
        for (int i = 0; i < numSamples; i++) {
          normX[i][j] = (X[i][j] - mins[j]) / range;
        }
      }
    }

    // Weighted Euclidean distances
    List<MapEntry<int, double>> distances = [];
    for (int i = 0; i < numSamples; i++) {
      double sumSquares = 0.0;
      for (int j = 0; j < numFeatures; j++) {
        double diff = normTargetX[j] - normX[i][j];
        double featWeight = (weights != null && j < weights.length) ? weights[j] : 1.0;
        sumSquares += featWeight * diff * diff;
      }
      double dist = sqrt(sumSquares);
      distances.add(MapEntry(i, dist));
    }

    // Sort by distance ascending
    distances.sort((a, b) => a.value.compareTo(b.value));

    // Check if closest neighbor is an exact match
    if (distances.first.value < 1e-7) {
      return y[distances.first.key];
    }

    // Top K neighbors with Inverse Distance Weighting
    int actualK = min(k, numSamples);
    double sumWeights = 0.0;
    double weightedSumY = 0.0;

    for (int i = 0; i < actualK; i++) {
      int idx = distances[i].key;
      double dist = distances[i].value;
      double weight = 1.0 / (dist + 1e-5);

      sumWeights += weight;
      weightedSumY += weight * y[idx];
    }

    return sumWeights > 0 ? (weightedSumY / sumWeights) : 0.0;
  }
}
