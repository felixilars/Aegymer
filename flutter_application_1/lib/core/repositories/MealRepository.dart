import 'package:aegymer/core/databases/app_database.dart';
import 'package:aegymer/models/mealitem_with_food.dart';
import 'package:drift/drift.dart';

class MealRepository {
  final AppDatabase _db;

  MealRepository(this._db);

  Future<List<MealItemWithFood>> getTodaysFoodItems({String? mealType}) async {
    final start = DateTime.now();
    final today = DateTime(start.year, start.month, start.day);
    final endToday = today.add(const Duration(days: 1));

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
      ..where(_db.userMeals.date.isBetweenValues(today, endToday));

    if (mealType != null && mealType.isNotEmpty) {
      query.where(_db.userMeals.mealType.equals(mealType));
    }

    final rows = await query.get();

    return rows.map((row) {
      return MealItemWithFood(
        mealItem: row.readTable(_db.mealItems),
        food: row.readTable(_db.foods),
      );
    }).toList();
  }

  Future<void> addFoodToMeal({
    required Food food,
    required String mealType,
    required double amount,
  }) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final mealId = '${mealType.toLowerCase()}-${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';

    final existingMeal = await (_db.select(_db.userMeals)
          ..where((tbl) =>
              tbl.mealType.equals(mealType) &
              tbl.date.isBetweenValues(day, day.add(const Duration(days: 1)))))
        .getSingleOrNull();

    await _db.transaction(() async {
      if (existingMeal == null) {
        await _db.into(_db.userMeals).insert(
          UserMealsCompanion.insert(
            id: mealId,
            date: now,
            mealType: mealType,
          ),
        );
      }

      final activeMealId = existingMeal?.id ?? mealId;

      await _db.into(_db.mealItems).insert(
        MealItemsCompanion.insert(
          id: '${activeMealId}-${DateTime.now().microsecondsSinceEpoch}',
          mealId: activeMealId,
          foodId: food.id,
          amount: amount,
        ),
      );
    });
  }

  Future<void> removeFoodFromMeal(String mealItemId) async {
    await (_db.delete(_db.mealItems)
          ..where((tbl) => tbl.id.equals(mealItemId)))
        .go();
  }

  Future<void> updateMealItemAmount({
    required String mealItemId,
    required double newAmount,
  }) async {
    await (_db.update(_db.mealItems)
          ..where((tbl) => tbl.id.equals(mealItemId)))
        .write(
      MealItemsCompanion(
        amount: Value(newAmount),
      ),
    );
  }
}
