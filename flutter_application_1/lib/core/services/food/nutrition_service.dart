
import 'package:flutter_application_1/models/nutrition_macros.dart';


class NutritionService {
  double calculateBMR({
    required String gender,
    required double weight,
    required double height,
    required int age,
  })
  {
    if (gender == 'male') {
      return 10 * weight + 6.25 * height - 5 * age + 5;
    } else {
      return 10 * weight + 6.25 * height - 5 * age - 161;
    }
  }

  double calculateTDEE({
    required double bmr,
    required double activityMultiplier,
  })
  {
    return bmr * activityMultiplier;
  }
  

  double calculateTargetCalories({
    required double tdee,
    required String goal,
  })
  {
    if (goal == 'lose') {
      return tdee - 500; // 500 calorie deficit for weight loss
    } else if (goal == 'gain') {
      return tdee + 300; // 300 calorie surplus for weight gain
    } else {
      return tdee; // maintain weight
    }
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