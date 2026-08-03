import "package:flutter_application_1/core/databases/app_database.dart";
import 'package:drift/drift.dart';
import "package:flutter_application_1/core/services/food/openfoodfacts_service.dart";
import "package:flutter_application_1/core/enums/meal_context.dart";
import "package:flutter_application_1/core/enums/food_category.dart";


class FoodRepository {
  final AppDatabase _db;
  final OpenFoodFactsService _openFoodFactsService;

  FoodRepository({
    required AppDatabase database,
    required OpenFoodFactsService openFoodFactsService,
  })  : _db = database,
        _openFoodFactsService = openFoodFactsService;

  /// Search for foods
  Future<List<Food>> searchFood(String name) async{
    final query = _db.select(_db.foods)..where((tbl) => tbl.name.lower().like('%${name.toLowerCase()}%'));
    final response = await query.get();
    if (response.isNotEmpty) {
      return response;
    } else {
      final openFoodFactsResults = await _openFoodFactsService.searchFood(name);
      final foods = openFoodFactsResults.asMap().entries.map((entry) => Food(
        id: _buildFoodId(entry.value.name, entry.key),
        name : entry.value.name,
        calories: entry.value.calories,  
        protein: entry.value.protein,
        carbs: entry.value.carbs,
        fat: entry.value.fat,
        category: entry.value.category,
        fiber: entry.value.fiber,
        sugar: entry.value.sugar,
        saturatedFat: entry.value.saturatedFat,
        sodium: entry.value.sodium,
        isCustom: true,
      )).toList();
      await saveFoods(foods);
      return foods;
    }
  }


  /// Get a food by its barcode
  Future<Food?> getFoodByBarcode(String barcode) {
    return _openFoodFactsService.getFoodByBarcode(barcode).then((ingredient) async{
      if (ingredient == null){
        return null;
      } else {
        final food = Food(
          id: _buildFoodId(ingredient.name, 0),
          name : ingredient.name,
          calories: ingredient.calories,  
          protein: ingredient.protein,
          carbs: ingredient.carbs,
          fat: ingredient.fat,
          category: ingredient.category,
          fiber: ingredient.fiber,
          sugar: ingredient.sugar,
          saturatedFat: ingredient.saturatedFat,
          sodium: ingredient.sodium,
          isCustom: true,
        );
        await saveFood(food);
        return food;
      }
    });
    }
  

  /// Save a food to the local database
  Future<void> saveFood(Food food) {
     return _db.into(_db.foods).insertOnConflictUpdate(food);
  }

  /// Save multiple foods
  Future<void> saveFoods(List<Food> foods){
    return _db.batch((batch) {
      batch.insertAll(_db.foods, foods);
    });
  }

  /// Update a food
  Future<void> updateFood(Food food){
    return _db.update(_db.foods).replace(food);
  }

  Future<List<Food>> getFoodsByMealContext(MealContext context){
    const Map<MealContext, List<FoodCategory>> mealCategoryMap = {
    MealContext.breakfast: [
      FoodCategory.protein,
      FoodCategory.fruit,
      FoodCategory.dairy,
      FoodCategory.carbohydrate,
    ],

    MealContext.lunch: [
      FoodCategory.protein,
      FoodCategory.vegetable,
      FoodCategory.carbohydrate,
      FoodCategory.fat,
    ],

    MealContext.dinner: [
      FoodCategory.protein,
      FoodCategory.vegetable,
      FoodCategory.carbohydrate,
      FoodCategory.fat,
    ],

    MealContext.snack: [
      FoodCategory.fruit,
      FoodCategory.dairy,
      FoodCategory.fat,
    ],
  };
    final categories = mealCategoryMap[context]!;

    return (_db.select(_db.foods)
          ..where((food) => food.category.isIn(
                categories.map((e) => e.name).toList(),
              )))
        .get();
  }


  Future<List<Food>> getRecentFoods(int days) async {
  final cutoffDate = DateTime.now().subtract(Duration(days: days));

  final query = _db.select(_db.foods).join([
    innerJoin(
      _db.mealItems,
      _db.mealItems.foodId.equalsExp(_db.foods.id),
    ),
    innerJoin(
      _db.userMeals,
      _db.userMeals.id.equalsExp(_db.mealItems.mealId),
    ),
  ])
    ..where(_db.userMeals.date.isBiggerOrEqualValue(cutoffDate));

  final rows = await query.get();

  return rows.map((row) => row.readTable(_db.foods)).toList();
}


       



  /// Delete a food
  Future<void> deleteFood(String id){
    return (_db.delete(_db.foods)..where((tbl)=>tbl.id.equals(id))).go();
  }

  String _buildFoodId(String name, int index) {
    final sanitized = name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return 'off-$sanitized-${DateTime.now().microsecondsSinceEpoch}-$index';
  }

 
}