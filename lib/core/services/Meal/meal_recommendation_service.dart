import 'package:aegymer/core/enums/meal_context.dart';
import 'package:aegymer/core/repositories/FoodRepository.dart';
import 'package:aegymer/core/repositories/MealRepository.dart';
import 'package:aegymer/core/repositories/UserRepository.dart';
import 'package:aegymer/core/services/Meal/amount/amount_calculator.dart';
import 'package:aegymer/models/mealRec_helper/meal_recommendation.dart';
import 'package:aegymer/models/mealRec_helper/remaining_meal_state.dart';
import 'package:aegymer/core/services/Meal/scorer/scorer.dart';
import 'package:aegymer/models/mealitem_with_food.dart';
import 'package:aegymer/models/nutrition_macros.dart';
import 'package:aegymer/core/databases/app_database.dart';

class MealRecommendationService {
  MealRecommendationService(
    this._mealRepository,
    this._userRepository,
    this._foodRepository,
    this._amountCalculator,
    this._scorer,
  );

  final MealRepository _mealRepository;
  final UserRepository _userRepository;
  final FoodRepository _foodRepository;
  final AmountCalculator _amountCalculator;
  final Scorer _scorer;

  Future<List<MealRecommendation>> recommendFoods({
    int limit = 10,
    MealContext? mealContext,
  }) async {
    final resolvedContext = mealContext ?? await determineMealContext();
    final remainingState = await calculateRemainingMealMacros(
      mealContext: resolvedContext,
    );

    final candidateFoods = await _foodRepository.getFoodsByMealContext(resolvedContext);
    final recentFoods = await _foodRepository.getRecentFoods(7);

    final recommendations = <MealRecommendation>[];

    for (final food in candidateFoods) {
      final amount = _amountCalculator.calculate(
        food: food,
        remainingMacros: remainingState.remaining,
      );

      final result = _scorer.calculate(
        food: food,
        amountRecommendation: amount,
        remainingMacros: remainingState.remaining,
        recentFoods: recentFoods,
      );

      recommendations.add(
        MealRecommendation(
          food: food,
          amount: amount,
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
      [MealContext? mealContext]) async {
    final resolvedContext = mealContext ?? await determineMealContext();
    final user = await _userRepository.getCurrentUser();

    return NutritionMacros(
      calories: user.calories * resolvedContext.calorieRatio,
      protein: user.protein * resolvedContext.proteinRatio,
      carbs: user.carbs * resolvedContext.carbRatio,
      fat: user.fat * resolvedContext.fatRatio,
    );
  }

  Future<RemainingMealState> calculateRemainingMealMacros({
    MealContext? mealContext,
  }) async {
    final resolvedContext = mealContext ?? await determineMealContext();
    final target = await calculateMealTarget(resolvedContext);
    final loggedFoods = await getLoggedFoodsForCurrentMeal(
      mealContext: resolvedContext,
    );
    final consumed = _sumMacros(loggedFoods);
    final remaining = _subtractAndClamp(target, consumed);

    return RemainingMealState(
      target: target,
      consumed: consumed,
      remaining: remaining,
    );
  }

  Future<List<MealItemWithFood>> getLoggedFoodsForCurrentMeal({
    MealContext? mealContext,
  }) async {
    final resolvedContext = mealContext ?? await determineMealContext();
    return _mealRepository.getTodaysFoodItems(mealType: resolvedContext.displayName);
  }

  Future<List<Food>> searchFoods(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    return _foodRepository.searchFood(query.trim());
  }

  Future<void> addFoodToMeal(
    Food food, {
    MealContext? mealContext,
    double amount = 100,
  }) async {
    final resolvedContext = mealContext ?? await determineMealContext();
    await _mealRepository.addFoodToMeal(
      food: food,
      mealType: resolvedContext.displayName,
      amount: amount,
    );
  }

  Future<void> removeFoodFromMeal(String mealItemId) async {
    await _mealRepository.removeFoodFromMeal(mealItemId);
  }

  Future<void> updateLoggedFoodAmount(String mealItemId, double newAmount) async {
    await _mealRepository.updateMealItemAmount(
      mealItemId: mealItemId,
      newAmount: newAmount,
    );
  }

  NutritionMacros _sumMacros(List<MealItemWithFood> items) {
    double calories = 0;
    double protein = 0;
    double carbs = 0;
    double fat = 0;

    for (final item in items) {
      final ratio = item.mealItem.amount / 100.0;
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

  NutritionMacros _subtractAndClamp(
    NutritionMacros target,
    NutritionMacros consumed,
  ) {
    return NutritionMacros(
      calories: (target.calories - consumed.calories).clamp(0, double.infinity).toDouble(),
      protein: (target.protein - consumed.protein).clamp(0, double.infinity).toDouble(),
      carbs: (target.carbs - consumed.carbs).clamp(0, double.infinity).toDouble(),
      fat: (target.fat - consumed.fat).clamp(0, double.infinity).toDouble(),
    );
  }
}
