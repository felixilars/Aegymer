import 'package:flutter_application_1/core/databases/app_database.dart';
import 'package:flutter_application_1/models/score_result.dart';



class VarietyScorer {
  ScoreResult score({
    required Food food,
    required List<Food> recentFoods,
  }) {
    final occurrences = recentFoods
        .where((f) => f.id == food.id)
        .length;

    final score = (100 - occurrences * 15)
        .clamp(20, 100)
        .toDouble();

    return ScoreResult(
      score: score,
      explanation: occurrences == 0
          ? "Provides meal variety."
          : "Recently eaten $occurrences time(s).",
      reasons: [
        occurrences == 0
            ? "Not eaten recently."
            : "Recently eaten $occurrences time(s).",
      ],
    );
  }
}