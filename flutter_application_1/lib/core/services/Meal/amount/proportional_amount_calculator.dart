import 'dart:math';

import 'package:aegymer/core/databases/app_database.dart';
import 'package:aegymer/core/services/Meal/amount/amount_calculator.dart';
import 'package:aegymer/models/mealRec_helper/amount_recommendation.dart';
import 'package:aegymer/models/nutrition_macros.dart';

class ProportionalAmountCalculator implements AmountCalculator {
  static const double minGrams = 30;
  static const double maxGrams = 300;

  const ProportionalAmountCalculator();

  @override
  AmountRecommendation calculate({
    required Food food,
    required NutritionMacros remainingMacros,
  }) {
    // Determine the primary nutritional purpose of the food
    final double proteinCal = food.protein * 4;
    final double carbCal = food.carbs * 4;
    final double fatCal = food.fat * 9;
    final double totalMacroCal = max(1.0, proteinCal + carbCal + fatCal);

    final double pShare = proteinCal / totalMacroCal;
    final double cShare = carbCal / totalMacroCal;
    final double fShare = fatCal / totalMacroCal;

    final proteinRatio = _safeRatio(remainingMacros.protein, food.protein);
    final carbRatio = _safeRatio(remainingMacros.carbs, food.carbs);
    final fatRatio = _safeRatio(remainingMacros.fat, food.fat);
    final calorieRatio = _safeRatio(remainingMacros.calories, food.calories);

    double chosenRatio;

    // High protein foods scale to protein target
    if ((pShare >= 0.35 || food.protein >= 15.0) && proteinRatio != null) {
      chosenRatio = proteinRatio;
    }
    // High carbohydrate foods scale to carb target
    else if ((cShare >= 0.45 || food.carbs >= 20.0) && carbRatio != null) {
      chosenRatio = carbRatio;
    }
    // High fat foods scale to fat target
    else if (fShare >= 0.50 && fatRatio != null) {
      chosenRatio = fatRatio;
    }
    // Balanced or mixed foods scale to calorie target
    else if (calorieRatio != null) {
      chosenRatio = calorieRatio;
    } else {
      final validRatios = [proteinRatio, carbRatio, fatRatio, calorieRatio].whereType<double>().toList();
      chosenRatio = validRatios.isNotEmpty
          ? validRatios.reduce((a, b) => a + b) / validRatios.length
          : 1.0;
    }

    // Clamp grams to realistic meal serving bounds
    final grams = (chosenRatio * 100).clamp(minGrams, maxGrams).toDouble();
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
