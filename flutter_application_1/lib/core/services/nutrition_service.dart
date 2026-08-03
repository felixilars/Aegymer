class NutritionService {
  double calculateBMR({
    required double weight,
    required double height,
    required int age,
    required String gender,
  }) {
    final genderValue = gender.toLowerCase().trim();
    if (genderValue == 'male' || genderValue == 'nam') {
      return (10.0 * weight) + (6.25 * height) - (5.0 * age) + 5.0;
    }
    return (10.0 * weight) + (6.25 * height) - (5.0 * age) - 161.0;
  }

  double calculateTDEE({
    required double bmr,
    required String activityLevel,
  }) {
    double factor = 1.55;
    switch (activityLevel.toLowerCase().trim()) {
      case 'sedentary':
        factor = 1.2;
        break;
      case 'lightly active':
        factor = 1.375;
        break;
      case 'moderately active':
        factor = 1.55;
        break;
      case 'very active':
        factor = 1.725;
        break;
      case 'extra active':
        factor = 1.9;
        break;
    }
    return bmr * factor;
  }

  Map<String, double> calculateMacroTargets({
    required double tdee,
    required String target,
    required double weight,
  }) {
    double targetCalories = tdee;
    final lowerTarget = target.toLowerCase();

    if (lowerTarget.contains('lose')) {
      targetCalories = tdee - 500.0;
    } else if (lowerTarget.contains('gain')) {
      targetCalories = tdee + 300.0;
    }

    if (targetCalories < 1200.0) {
      targetCalories = 1200.0;
    }

    double proteinGrams = 2.0 * weight;
    if (proteinGrams < 40.0) {
      proteinGrams = 40.0;
    }

    final fatGrams = (targetCalories * 0.22) / 9.0;
    final proteinCalories = proteinGrams * 4.0;
    final fatCalories = fatGrams * 9.0;
    var carbCalories = targetCalories - proteinCalories - fatCalories;
    if (carbCalories < 0.0) {
      carbCalories = 0.0;
    }

    return {
      'calories': targetCalories,
      'protein': proteinGrams,
      'carbs': carbCalories / 4.0,
      'fat': fatGrams,
    };
  }

  int calculateDailyWaterTarget({
    required double weight,
    required String activityLevel,
  }) {
    double factor = 1.0;
    switch (activityLevel.toLowerCase().trim()) {
      case 'sedentary':
        factor = 1.0;
        break;
      case 'lightly active':
        factor = 1.15;
        break;
      case 'moderately active':
        factor = 1.3;
        break;
      case 'very active':
        factor = 1.45;
        break;
      case 'extra active':
        factor = 1.6;
        break;
    }
    final waterMl = (weight * 35.0) * factor;
    return waterMl.round().clamp(1500, 4500);
  }
}