
import 'package:aegymer/core/databases/app_database.dart';
import 'package:aegymer/models/mealRec_helper/amount_recommendation.dart';
import 'package:aegymer/models/nutrition_macros.dart';
import 'package:aegymer/models/score_result.dart';
import 'package:aegymer/core/services/Meal/scorer/heuristics/food_calories_scorer.dart';
import 'package:aegymer/core/services/Meal/scorer/heuristics/food_macro_scorer.dart';
import 'package:aegymer/core/services/Meal/scorer/heuristics/variety_scorer.dart';

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
    required AmountRecommendation amountRecommendation,
    required NutritionMacros remainingMacros,
    required List<Food> recentFoods,
  }) {
    final macroResult = macroScorer.score(
      providedMacros: amountRecommendation.macros,
      remainingMacros: remainingMacros,
    );

    final calorieResult = calorieScorer.score(
      providedCalories: amountRecommendation.macros.calories,
      remainingCalories: remainingMacros.calories,
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

    final reasons = [
      ...macroResult.reasons,
      ...calorieResult.reasons,
      ...varietyResult.reasons,
    ];

    return ScoreResult(
      score: totalScore,
      explanation: explanation,
      reasons: reasons,
      breakdown: {
        'Macro Fit': macroResult.score,
        'Calorie Fit': calorieResult.score,
        'Variety': varietyResult.score,
      },
    );
  }
}