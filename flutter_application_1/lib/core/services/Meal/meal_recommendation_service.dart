import 'package:flutter_application_1/core/repositories/FoodRepository.dart';
import 'package:flutter_application_1/models/nutrition_macros.dart';
import 'package:flutter_application_1/core/repositories/MealRepository.dart';
import 'package:flutter_application_1/core/repositories/UserRepository.dart';
import 'package:flutter_application_1/core/enums/meal_context.dart';


class MealRecommendationService {
  MealRecommendationService(this._mealRepository, this._userRepository, this._foodRepository);

  final MealRepository _mealRepository;
  final UserRepository _userRepository;
  final FoodRepository _foodRepository;

  Future<MealContext> determineMealContext() async {
    final now = DateTime.now();
    final hour = now.hour;

    if (hour >= 5 && hour < 11) {
      return MealContext.breakfast;
    } else if (hour >= 11 && hour < 15) {
      return MealContext.lunch;
    } else if (hour >= 18 && hour < 22) {
      return MealContext.dinner;
    } else {
      return MealContext.snack;
    }
  }

  Future<NutritionMacros> calculateMealTarget(MealContext mealContext) async {
    final userMacros = await _userRepository.getCurrentUser();

    return NutritionMacros(
      calories: userMacros.calories * mealContext.calorieRatio,
      protein: userMacros.protein * mealContext.proteinRatio,
      carbs: userMacros.carbs * mealContext.carbRatio,
      fat: userMacros.fat * mealContext.fatRatio,
    );
  }

  



  
}