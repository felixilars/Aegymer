import 'package:flutter_application_1/core/databases/app_database.dart';import 'package:flutter_application_1/models/mealitem_with_food.dart';
import 'package:drift/drift.dart';
class MealRepository {
  final AppDatabase _db;

  MealRepository(this._db);

  Future<List<MealItemWithFood>> getTodaysFoodItems() async {
  final start = DateTime.now();
  final today = DateTime(start.year, start.month, start.day);
  final end_today = today.add(const Duration(days: 1));

  final query = _db.select(_db.mealItems).join([
      innerJoin(
        _db.userMeals,
        _db.userMeals.id.equalsExp(_db.mealItems.mealId),
      ),
      innerJoin(
        _db.foods,
        _db.foods.id.equalsExp(_db.mealItems.foodId),
      ),
    ])
      ..where(_db.userMeals.date.isBetweenValues(today, end_today));
  final rows = await query.get();

  return rows.map((row) {
    return MealItemWithFood(
      mealItem: row.readTable(_db.mealItems),
      food: row.readTable(_db.foods),
    );
  }).toList();
}
}