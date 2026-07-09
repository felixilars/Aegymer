import 'package:flutter_application_1/core/databases/app_database.dart';

class NutritionService {
  NutritionService._internal();

  static final NutritionService _instance = NutritionService._internal();

  factory NutritionService() => _instance;

  final AppDatabase db = AppDatabase();
}