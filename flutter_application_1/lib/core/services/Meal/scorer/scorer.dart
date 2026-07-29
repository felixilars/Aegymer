
import 'package:flutter_application_1/core/databases/app_database.dart';
import 'package:flutter_application_1/models/nutrition_macros.dart';
import 'package:flutter_application_1/models/score_result.dart';
import 'package:flutter_application_1/core/services/Meal/scorer/heuristics/food_calories_scorer.dart';
import 'package:flutter_application_1/core/services/Meal/scorer/heuristics/food_macro_scorer.dart';
import 'package:flutter_application_1/core/services/Meal/scorer/heuristics/variety_scorer.dart';

class Scorer {
  static const double macroWeight = 0.45;
  static const double calorieWeight = 0.20;
  static const double varietyWeight = 0.35;

  final MacroScorer macroScorer;
  final CalorieScorer calorieScorer;
  final VarietyScorer varietyScorer;

  const Scorer({
    required this.macroScorer,
    required this.calorieScorer,
    required this.varietyScorer,
  });

  ScoreResult calculate({
    required Food food,
    required NutritionMacros macros,
    required double remainingCalories,
    required List<Food> recentFoods,
  }) {
    final macroResult = macroScorer.score(
      food: food,
      remainingMacros: macros,
    );

    final calorieResult = calorieScorer.score(
      food: food,
      remainingCalories: remainingCalories,
    );

    final varietyResult = varietyScorer.score(
      food: food,
      recentFoods: recentFoods,
    );

    final totalScore =
        macroResult.score * macroWeight +
        calorieResult.score * calorieWeight +
        varietyResult.score * varietyWeight;

    final explanation = [
      macroResult.explanation,
      calorieResult.explanation,
      varietyResult.explanation,
    ].join('\n');

    return ScoreResult(
      score: totalScore,
      explanation: explanation,
    );
  }
}