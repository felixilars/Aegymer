import 'package:flutter_application_1/lib/models/nutrition_macros.dart';

class OpenFoodFactsService {

  Future<List<NutritionMacro>> searchFood(String query);

  Future<NutritionMacro?> getFoodByBarcode(String barcode);

}