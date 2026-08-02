import 'package:flutter_application_1/models/nutrition_macros.dart';
import 'package:flutter_application_1/core/repositories/MealRepository.dart';
import 'package:flutter_application_1/core/repositories/UserRepository.dart';


class MealNutritionService {
  MealNutritionService(this._mealRepository, this._userRepository);

  final MealRepository _mealRepository;
  final UserRepository _userRepository;

  Future<NutritionMacros> getConsumedMacrosToday() async {
  final items = await _mealRepository.getTodaysFoodItems();

  double calories = 0;
  double protein = 0;
  double carbs = 0;
  double fat = 0;

  for (final item in items) {
    final amount = item.mealItem.amount;
    final ratio = amount / 100.0;

    calories += item.food.calories * ratio;
    protein += item.food.protein * ratio;
    carbs += item.food.carbs * ratio;
    fat += item.food.fat * ratio;
  }

  return NutritionMacros(
    calories: calories,
    protein: protein,
    carbs: carbs,
    fat: fat,
  );
}

  Future<NutritionMacros> getRemainingToday() async{
    final consumed = await getConsumedMacrosToday();
    final goal = await _userRepository.getCurrentUser();

    final remaining = NutritionMacros(
      calories: goal.calories - consumed.calories,
      protein: goal.protein - consumed.protein,
      carbs: goal.carbs - consumed.carbs,
      fat: goal.fat - consumed.fat,
    );
    return remaining;
  }
}