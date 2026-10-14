
import 'package:aegymer/models/nutrition_macros.dart';


class NutritionService {
  double calculateBMR({
    required String gender,
    required double weight,
    required double height,
    required int age,
  }) {
    final g = gender.toLowerCase().trim();
    if (g == 'male') {
      return (10.0 * weight) + (6.25 * height) - (5.0 * age) + 5.0;
    } else {
      return (10.0 * weight) + (6.25 * height) - (5.0 * age) - 161.0;
    }
  }

  double calculateTDEE({
    required double bmr,
    required double activityMultiplier,
  }) {
    return bmr * activityMultiplier;
  }

  double calculateTargetCalories({
    required double tdee,
    required String goal,
  }) {
    final g = goal.toLowerCase().trim();
    double target;
    if (g.contains('lose')) {
      target = tdee - 500.0; // 500 calorie deficit for weight loss (~0.5kg/week)
    } else if (g.contains('gain')) {
      target = tdee + 300.0; // 300 calorie surplus for lean muscle gain
    } else {
      target = tdee; // maintain weight
    }

    // Safety minimum floor (ACSM / Mayo Clinic guideline)
    if (target < 1200.0) {
      target = 1200.0;
    }
    return target;
  }

  NutritionMacros calculateMacros({
    required double calories,
    required double weight,
  }){
    final proteinGrams = weight * 2;
    final fatGrams = (calories * 0.3) / 9;
    final remainingCarbCal = calories - (proteinGrams * 4) - (fatGrams * 9);
    final carbsGrams = remainingCarbCal > 0 ? remainingCarbCal / 4 : 0.0;
    return NutritionMacros(
      calories: calories,
      protein: proteinGrams,
      carbs: carbsGrams,
      fat: fatGrams,
    );
  }
}