import 'package:flutter_application_1/models/score_result.dart';




class CalorieScorer {
  static const double _overshootMultiplier = 1.25;

  ScoreResult score({
    required double providedCalories,
    required double remainingCalories,
  }) {
    if (remainingCalories <= 0) {
      return ScoreResult(
        score: providedCalories <= 0 ? 100 : 0,
        explanation: "No calorie budget remaining.",
        reasons: const ["No calorie budget remaining."],
      );
    }

    double error =
        (providedCalories - remainingCalories).abs() / remainingCalories;

    if (providedCalories > remainingCalories) {
      error *= _overshootMultiplier;
    }

    final score = (100 * (1 - error)).clamp(0, 100).toDouble();
    final explanation = _explanation(providedCalories, remainingCalories);

    return ScoreResult(
      score: score,
      explanation: explanation,
      reasons: [explanation],
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