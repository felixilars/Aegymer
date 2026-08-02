import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/services/knn_service.dart';

void main() {
  group('KNearestNeighborsService', () {
    test('predicts a value close to nearby training samples', () {
      final service = KNearestNeighborsService(k: 3);

      final x = <List<double>>[
        [100, 10, 0.10, 1.00, 3],
        [102.5, 11, 0.12, 1.05, 3],
        [105, 12, 0.15, 1.10, 4],
        [107.5, 13, 0.18, 1.12, 4],
        [110, 14, 0.20, 1.15, 5],
      ];
      final y = <double>[102.5, 105, 107.5, 110, 112.5];
      final targetX = <double>[108, 13, 0.17, 1.13, 4];

      final prediction = service.predict(x, y, targetX);

      expect(prediction, isNotNull);
      expect(prediction, greaterThan(105));
      expect(prediction, lessThan(112.5));
    });

    test('returns 0 for invalid input shapes', () {
      final service = KNearestNeighborsService();

      final prediction = service.predict(
        [
          [1, 2],
          [3, 4, 5],
        ],
        [10, 20],
        [2, 3],
      );

      expect(prediction, equals(0.0));
    });

    test('returns 0 for empty input', () {
      final service = KNearestNeighborsService();

      expect(service.predict([], [], []), equals(0.0));
    });
  });
}
