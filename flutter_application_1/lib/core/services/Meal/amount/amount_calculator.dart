import 'package:aegymer/core/databases/app_database.dart';
import 'package:aegymer/models/mealRec_helper/amount_recommendation.dart';
import 'package:aegymer/models/nutrition_macros.dart';

abstract class AmountCalculator {
  AmountRecommendation calculate({
    required Food food,
    required NutritionMacros remainingMacros,
  });
}
