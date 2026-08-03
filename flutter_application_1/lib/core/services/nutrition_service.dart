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

  /// Calculates personalized daily water intake target in milliliters (ml)
  /// Based on body weight (35ml / kg) and activity level.
  int calculateDailyWaterTarget({
    required double weight,
    double activityLevel = 1.55,
  }) {
    // Base intake: 35 ml per kg of body weight
    double baseWaterMl = weight * 35.0;

    // Activity adjustment bonus (in ml)
    double activityBonus = 500.0;
    if (activityLevel >= 1.9) {
      activityBonus = 1000.0;
    } else if (activityLevel >= 1.725) {
      activityBonus = 750.0;
    } else if (activityLevel >= 1.55) {
      activityBonus = 500.0;
    } else if (activityLevel >= 1.375) {
      activityBonus = 350.0;
    } else {
      activityBonus = 0.0;
    }

    final totalTarget = baseWaterMl + activityBonus;
    // Clamp between 1500 ml and 4500 ml for safety
    return totalTarget.clamp(1500.0, 4500.0).round();
  }
}