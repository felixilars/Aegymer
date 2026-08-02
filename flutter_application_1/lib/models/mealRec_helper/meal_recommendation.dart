import 'package:flutter_application_1/core/databases/app_database.dart';
import 'package:flutter_application_1/models/mealRec_helper/amount_recommendation.dart';
import 'package:flutter_application_1/models/score_result.dart';

class MealRecommendation {
  final Food food;
  final AmountRecommendation amount;
  final ScoreResult score;

  const MealRecommendation({
    required this.food,
    required this.amount,
    required this.score,
  });
}
