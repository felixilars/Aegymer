import 'package:aegymer/core/databases/app_database.dart';
import 'package:aegymer/models/nutrition_macros.dart';

class UserRepository {
  final AppDatabase _db;

  UserRepository(this._db);

  Future<NutritionMacros> getCurrentUser() async {
    try {
      final query = _db.select(_db.userProfiles);
      final user = await query.getSingleOrNull();
      if (user != null) {
        return NutritionMacros(
          calories: user.dailyCalories,
          protein: user.dailyProtein,
          carbs: user.dailyCarbs,
          fat: user.dailyFat,
        );
      }
    } catch (e) {
      // Safe fallback if local user_profiles table has malformed/legacy row types
    }
    return const NutritionMacros(
      calories: 2000.0,
      protein: 150.0,
      carbs: 200.0,
      fat: 60.0,
    );
  }
}
