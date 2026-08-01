import 'package:flutter_application_1/core/databases/app_database.dart';
import 'package:flutter_application_1/models/mealRec_helper/amount_recommendation.dart';
import 'package:flutter_application_1/models/nutrition_macros.dart';

abstract class AmountCalculator {
  AmountRecommendation calculate({
    required Food food,
    required NutritionMacros remainingMacros,
  });
}
