
import 'package:aegymer/models/nutrition_macros.dart';
import 'package:aegymer/models/score_result.dart';






class MacroScorer {
  // Weights inside the macro scorer
  static const double _proteinWeight = 0.50;
  static const double _carbWeight = 0.30;
  static const double _fatWeight = 0.20;

  // Overshooting is punished 25% more than undershooting
  static const double _overshootMultiplier = 1.25;

  ScoreResult score({
    required NutritionMacros providedMacros,
    required NutritionMacros remainingMacros,
  }) {
    final proteinScore = _macroScore(
      foodValue: providedMacros.protein,
      targetValue: remainingMacros.protein,
    );

    final carbScore = _macroScore(
      foodValue: providedMacros.carbs,
      targetValue: remainingMacros.carbs,
    );

    final fatScore = _macroScore(
      foodValue: providedMacros.fat,
      targetValue: remainingMacros.fat,
    );

    final total =
        proteinScore * _proteinWeight +
        carbScore * _carbWeight +
        fatScore * _fatWeight;

    return ScoreResult(
      score: total,
      explanation: _buildExplanation(
        proteinScore: proteinScore,
        carbScore: carbScore,
        fatScore: fatScore,
      ),
      reasons: _buildReasons(
        proteinScore: proteinScore,
        carbScore: carbScore,
        fatScore: fatScore,
      ),
    );
  }

  /// Returns a score between 0 and 100
  double _macroScore({
    required double foodValue,
    required double targetValue,
  }) {
    // Nothing left to consume
    if (targetValue <= 0) {
      return foodValue <= 0 ? 100 : 0;
    }

    double error = (foodValue - targetValue).abs() / targetValue;

    // Penalize overshooting slightly more
    if (foodValue > targetValue) {
      error *= _overshootMultiplier;
    }

    final score = (100 * (1 - error)).clamp(0, 100);

    return score.toDouble();
  }

  String _buildExplanation({
    required double proteinScore,
    required double carbScore,
    required double fatScore,
  }) {
    return _buildReasons(
      proteinScore: proteinScore,
      carbScore: carbScore,
      fatScore: fatScore,
    ).join(' ');
  }

  List<String> _buildReasons({
    required double proteinScore,
    required double carbScore,
    required double fatScore,
  }) {
    final messages = <String>[];

    if (proteinScore >= 90) {
      messages.add("Excellent protein match.");
    } else if (proteinScore < 60) {
      messages.add("Protein differs significantly from target.");
    }

    if (carbScore >= 90) {
      messages.add("Carbohydrates closely match target.");
    } else if (carbScore < 60) {
      messages.add("Carbohydrates are far from target.");
    }

    if (fatScore >= 90) {
      messages.add("Fat target is well matched.");
    } else if (fatScore < 60) {
      messages.add("Fat content is not ideal.");
    }

    if (messages.isEmpty) {
      messages.add("Reasonable overall macro balance.");
    }

    return messages;
  }
}