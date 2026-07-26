import "package:flutter_application_1/core/databases/app_database.dart";
import 'package:drift/drift.dart';
import "package:flutter_application_1/core/services/food/openfoodfacts_service.dart";

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
      final foods = openFoodFactsResults.map((ingredient) => Food(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name : ingredient.name,
        calories: ingredient.calories,  
        protein: ingredient.protein,
        carbs: ingredient.carbs,
        fat: ingredient.fat,
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
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: "Food with barcode $barcode",
          calories: ingredient.calories,
          protein: ingredient.protein,
          carbs: ingredient.carbs,
          fat: ingredient.fat,
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

  /// Delete a food
  Future<void> deleteFood(String id){
    return (_db.delete(_db.foods)..where((tbl)=>tbl.id.equals(id))).go();
  }

 
}