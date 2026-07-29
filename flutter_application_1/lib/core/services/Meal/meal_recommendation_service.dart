import 'package:flutter_application_1/core/enums/meal_context.dart';
import 'package:flutter_application_1/core/repositories/FoodRepository.dart';
import 'package:flutter_application_1/core/repositories/MealRepository.dart';
import 'package:flutter_application_1/core/repositories/UserRepository.dart';
import 'package:flutter_application_1/core/services/Meal/scorer/scorer.dart';
import 'package:flutter_application_1/models/mealitem_with_food.dart';
import 'package:flutter_application_1/models/nutrition_macros.dart';
import 'package:flutter_application_1/models/score_result.dart';
import 'package:flutter_application_1/core/databases/app_database.dart';

class MealRecommendation {
  final Food food;
  final ScoreResult score;

  const MealRecommendation({
    required this.food,
    required this.score,
  });
}

class MealRecommendationService {
  MealRecommendationService(
    this._mealRepository,
    this._userRepository,
    this._foodRepository,
    this._scorer,
  );

  final MealRepository _mealRepository;
  final UserRepository _userRepository;
  final FoodRepository _foodRepository;
  final Scorer _scorer;

  Future<List<MealRecommendation>> recommendFoods({
    int limit = 10,
  }) async {
    final mealContext = await determineMealContext();
    final mealTarget = await calculateMealTarget(mealContext);
    final candidateFoods = await _foodRepository.getFoodsByMealContext(mealContext);
    final recentFoods = await _foodRepository.getRecentFoods(7);

    final recommendations = <MealRecommendation>[];

    for (final food in candidateFoods) {
      final result = _scorer.calculate(
        food: food,
        macros: mealTarget,
        remainingCalories: mealTarget.calories,
        recentFoods: recentFoods,
      );

      recommendations.add(
        MealRecommendation(
          food: food,
          score: result,
        ),
      );
    }

    recommendations.sort(
      (a, b) => b.score.score.compareTo(a.score.score),
    );

    return recommendations.take(limit).toList();
  }

  Future<MealContext> determineMealContext() async {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 11) {
      return MealContext.breakfast;
    }

    if (hour >= 11 && hour < 15) {
      return MealContext.lunch;
    }

    if (hour >= 18 && hour < 22) {
      return MealContext.dinner;
    }

    return MealContext.snack;
  }

  Future<NutritionMacros> calculateMealTarget(
    MealContext mealContext,
  ) async {
    final user = await _userRepository.getCurrentUser();

    return NutritionMacros(
      calories: user.calories * mealContext.calorieRatio,
      protein: user.protein * mealContext.proteinRatio,
      carbs: user.carbs * mealContext.carbRatio,
      fat: user.fat * mealContext.fatRatio,
    );
  }

  Future<List<MealItemWithFood>> getLoggedFoodsForCurrentMeal({
    required MealContext mealContext,
  }) async {
    return _mealRepository.getTodaysFoodItems(mealType: mealContext.displayName);
  }

  Future<List<Food>> searchFoods(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    return _foodRepository.searchFood(query.trim());
  }

  Future<void> addFoodToMeal(Food food, {required MealContext mealContext}) async {
    await _mealRepository.addFoodToMeal(
      food: food,
      mealType: mealContext.displayName,
    );
  }

  Future<void> removeFoodFromMeal(String mealItemId) async {
    await _mealRepository.removeFoodFromMeal(mealItemId);
  }
}
