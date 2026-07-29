import 'package:flutter_application_1/core/databases/app_database.dart';
import 'package:flutter_application_1/models/score_result.dart';




class CalorieScorer {
  static const double _overshootMultiplier = 1.25;

  ScoreResult score({
    required Food food,
    required double remainingCalories,
  }) {
    if (remainingCalories <= 0) {
      return ScoreResult(
        score: food.calories <= 0 ? 100 : 0,
        explanation: "No calorie budget remaining.",
      );
    }

    double error =
        (food.calories - remainingCalories).abs() / remainingCalories;

    if (food.calories > remainingCalories) {
      error *= _overshootMultiplier;
    }

    final score = (100 * (1 - error)).clamp(0, 100).toDouble();

    return ScoreResult(
      score: score,
      explanation: _explanation(food.calories, remainingCalories),
    );
  }

  String _explanation(double calories, double remaining) {
    if (calories > remaining) {
      return "Exceeds remaining calorie budget.";
    }

    if ((remaining - calories) < remaining * 0.1) {
      return "Excellent calorie match.";
    }

    return "Fits within calorie budget.";
  }
}