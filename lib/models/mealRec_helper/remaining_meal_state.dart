import 'package:aegymer/models/nutrition_macros.dart';

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
