import 'package:flutter_application_1/core/enums/food_category.dart';

class FoodCategoryClassifier {
  static const _dairy = [
    'milk',
    'cheese',
    'yogurt',
    'yoghurt',
    'cream',
    'butter',
    'kefir',
  ];

  static const _fruit = [
    'apple',
    'banana',
    'orange',
    'pear',
    'grape',
    'kiwi',
    'mango',
    'pineapple',
    'berry',
    'melon',
    'watermelon',
    'lemon',
    'lime',
    'avocado',
  ];

  static const _vegetables = [
    'broccoli',
    'spinach',
    'lettuce',
    'carrot',
    'cucumber',
    'tomato',
    'pepper',
    'onion',
    'garlic',
    'cabbage',
    'cauliflower',
    'celery',
    'kale',
    'mushroom',
  ];

  static FoodCategory classify({
    required String name,
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    required double fiber,
    required double sugar,
  }) {

    final lower = name.toLowerCase();

    // ---------- Name based ----------

    if (_dairy.any(lower.contains)) {
      return FoodCategory.dairy;
    }

    if (_fruit.any(lower.contains)) {
      return FoodCategory.fruit;
    }

    if (_vegetables.any(lower.contains)) {
      return FoodCategory.vegetable;
    }

    // ---------- Macro based ----------

    if (calories > 0) {
      final proteinRatio = protein * 4 / calories;
      final carbRatio = carbs * 4 / calories;
      final fatRatio = fat * 9 / calories;

      if (proteinRatio >= 0.45) {
        return FoodCategory.protein;
      }

      if (fatRatio >= 0.60) {
        return FoodCategory.fat;
      }

      if (carbRatio >= 0.50) {
        return FoodCategory.carbohydrate;
      }
    }

    // ---------- Fallback ----------

    if (calories < 60 && fiber >= 2 && sugar < 5) {
      return FoodCategory.vegetable;
    }

    if (calories < 100 && sugar >= 5 && fiber >= 1) {
      return FoodCategory.fruit;
    }

    return FoodCategory.mixed;
  }
}