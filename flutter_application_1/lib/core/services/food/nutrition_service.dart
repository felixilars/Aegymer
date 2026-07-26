
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
    return NutritionMacros(
      calories: calories,
      protein: weight * 2, // 2 grams of protein per kg of body weight
      carbs: (calories * 0.7 - weight * 2 * 4) / 4, // Remaining calories after protein and fat, divided by 4 (calories per gram of carbs)
      fat: (calories * 0.3) / 9, // 30% of calories from fat
    );
  }
}