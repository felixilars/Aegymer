import 'package:flutter_application_1/core/enums/food_category.dart';

class FoodCategoryClassifier {
  static const _dairy = [
    'milk', 'cheese', 'yogurt', 'yoghurt', 'cream', 'butter', 'kefir',
    'cottage cheese', 'ricotta', 'mozzarella', 'parmesan', 'cheddar', 'gouda',
    'ghee', 'whey', 'quark', 'casein', 'sour cream',
  ];

  static const _fruit = [
    'apple', 'banana', 'orange', 'pear', 'grape', 'kiwi', 'mango',
    'pineapple', 'berry', 'strawberry', 'blueberry', 'raspberry', 'blackberry',
    'cranberry', 'melon', 'watermelon', 'cantaloupe', 'honeydew', 'lemon',
    'lime', 'avocado', 'peach', 'plum', 'cherry', 'grapefruit', 'papaya',
    'fig', 'date', 'pomegranate', 'apricot', 'coconut', 'passion fruit', 'guava',
  ];

  static const _vegetables = [
    'broccoli', 'spinach', 'lettuce', 'carrot', 'cucumber', 'tomato',
    'pepper', 'bell pepper', 'onion', 'garlic', 'cabbage', 'cauliflower',
    'celery', 'kale', 'mushroom', 'zucchini', 'asparagus', 'green bean',
    'pea', 'brussels sprout', 'eggplant', 'radish', 'beetroot', 'pumpkin',
    'artichoke', 'leek', 'arugula', 'bok choy', 'squash',
  ];

  static const _proteinKeywords = [
    'chicken', 'beef', 'pork', 'fish', 'salmon', 'tuna', 'egg', 'egg white',
    'whey', 'tofu', 'tempeh', 'shrimp', 'prawn', 'turkey', 'meat', 'steak',
    'lamb', 'veal', 'cod', 'tilapia', 'halibut', 'sardine', 'mackerel',
    'crab', 'lobster', 'scallop', 'clam', 'edamame', 'seitan', 'duck',
  ];

  static const _carbKeywords = [
    'rice', 'oat', 'oatmeal', 'bread', 'pasta', 'noodle', 'potato', 'sweet potato',
    'corn', 'quinoa', 'barley', 'cereal', 'tortilla', 'bagel', 'pita',
    'buckwheat', 'millet', 'couscous', 'spaghetti', 'macaroni', 'flour',
    'granola', 'cracker',
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

    bool hasKeyword(List<String> list) {
      return list.any((k) => lower.contains(k));
    }

    // ---------- 1. Name based keyword matching ----------

    if (hasKeyword(_dairy)) {
      return FoodCategory.dairy;
    }

    if (hasKeyword(_proteinKeywords)) {
      return FoodCategory.protein;
    }

    if (hasKeyword(_carbKeywords)) {
      return FoodCategory.carbohydrate;
    }

    if (hasKeyword(_fruit)) {
      return FoodCategory.fruit;
    }

    if (hasKeyword(_vegetables)) {
      return FoodCategory.vegetable;
    }

    // ---------- 2. Macro based analytical ratios ----------

    if (calories > 0) {
      final proteinRatio = protein * 4 / calories;
      final carbRatio = carbs * 4 / calories;
      final fatRatio = fat * 9 / calories;

      if (proteinRatio >= 0.40 || protein >= 18.0) {
        return FoodCategory.protein;
      }

      if (fatRatio >= 0.55 || fat >= 18.0) {
        return FoodCategory.fat;
      }

      if (carbRatio >= 0.45 || carbs >= 25.0) {
        return FoodCategory.carbohydrate;
      }
    }

    // ---------- 3. Heuristic Fallbacks ----------

    if (calories < 60 && fiber >= 2 && sugar < 5) {
      return FoodCategory.vegetable;
    }

    if (calories < 100 && sugar >= 5 && fiber >= 1) {
      return FoodCategory.fruit;
    }

    return FoodCategory.mixed;
  }
}