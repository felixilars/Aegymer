import 'package:flutter_application_1/core/databases/app_database.dart';
import 'package:flutter_application_1/models/nutrition_macros.dart';
import 'package:drift/drift.dart';
class UserRepository {
  final AppDatabase _db;

  UserRepository(this._db);

  Future<NutritionMacros> getCurrentUser() async {
    final query = _db.select(_db.userProfiles);
    final user = await query.getSingleOrNull();
    if (user != null) {
      return NutritionMacros(
        calories: user.dailyCalories,
        protein: user.dailyProtein,
        carbs: user.dailyCarbs,
        fat: user.dailyFat,
      );
    } else {
      throw Exception('No user found in the database');
    }
  }
}
