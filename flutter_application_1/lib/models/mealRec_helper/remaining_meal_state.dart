import 'package:flutter_application_1/models/nutrition_macros.dart';

class RemainingMealState {
  final NutritionMacros target;
  final NutritionMacros consumed;
  final NutritionMacros remaining;

  const RemainingMealState({
    required this.target,
    required this.consumed,
    required this.remaining,
  });
}
