import 'package:aegymer/core/databases/app_database.dart';
import 'package:aegymer/models/mealRec_helper/amount_recommendation.dart';
import 'package:aegymer/models/score_result.dart';

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
