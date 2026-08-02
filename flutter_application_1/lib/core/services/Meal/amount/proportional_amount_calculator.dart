import 'dart:math';

import 'package:flutter_application_1/core/databases/app_database.dart';
import 'package:flutter_application_1/core/services/Meal/amount/amount_calculator.dart';
import 'package:flutter_application_1/models/mealRec_helper/amount_recommendation.dart';
import 'package:flutter_application_1/models/nutrition_macros.dart';

class ProportionalAmountCalculator implements AmountCalculator {
  static const double minGrams = 30;
  static const double maxGrams = 300;

  const ProportionalAmountCalculator();

  @override
  AmountRecommendation calculate({
    required Food food,
    required NutritionMacros remainingMacros,
  }) {
    final ratios = <double>[];

    final proteinRatio = _safeRatio(remainingMacros.protein, food.protein);
    if (proteinRatio != null) ratios.add(proteinRatio);

    final carbRatio = _safeRatio(remainingMacros.carbs, food.carbs);
    if (carbRatio != null) ratios.add(carbRatio);

    final fatRatio = _safeRatio(remainingMacros.fat, food.fat);
    if (fatRatio != null) ratios.add(fatRatio);

    final calorieRatio = _safeRatio(remainingMacros.calories, food.calories);
    if (calorieRatio != null) ratios.add(calorieRatio);

    final ratio = ratios.isEmpty ? 1.0 : ratios.reduce(min);
    final grams = (ratio * 100).clamp(minGrams, maxGrams).toDouble();
    final quantityRatio = grams / 100.0;

    return AmountRecommendation(
      grams: grams,
      macros: NutritionMacros(
        calories: food.calories * quantityRatio,
        protein: food.protein * quantityRatio,
        carbs: food.carbs * quantityRatio,
        fat: food.fat * quantityRatio,
      ),
    );
  }

  double? _safeRatio(double target, double per100gValue) {
    if (target <= 0 || per100gValue <= 0) {
      return null;
    }

    return target / per100gValue;
  }
}
