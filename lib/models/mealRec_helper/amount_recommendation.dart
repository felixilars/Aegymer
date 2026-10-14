import 'package:aegymer/models/nutrition_macros.dart';

class AmountRecommendation {
  final double grams;
  final NutritionMacros macros;

  const AmountRecommendation({
    required this.grams,
    required this.macros,
  });
}
