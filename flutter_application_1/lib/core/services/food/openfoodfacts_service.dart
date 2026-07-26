import 'package:flutter_application_1/models/ingredient.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';

class OpenFoodFactsService {
  final http.Client _client = http.Client();

  Future<List<Ingredient>> searchFood(String query) async {
    final uri = Uri.parse('https://world.openfoodfacts.org/api/v2/search?categories_tags_en=$query&json=1');

    final response =  await _client.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load food data');
    }else {
      final data = jsonDecode(response.body);
      if (data['status'] != 1) {
        return [];
      }
      final products = data['products'] as List<dynamic>;
      return products.map((product) => _mapProduct(product)).toList();
    }
  }

  Future<Ingredient?> getFoodByBarcode(String barcode) async {
    final uri = Uri.parse('https://world.openfoodfacts.org/api/v2/product/$barcode.json');

    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load food data');
    } else {
      final data = jsonDecode(response.body);
      if (data['status'] != 1) {
        return null;
      }
      return _mapProduct(data['product']);
    }
  }

  Ingredient _mapProduct(Map<String, dynamic> product) {
  final nutriments =
      product['nutriments'] as Map<String, dynamic>? ?? {};

  return Ingredient(
    name: product['product_name'] as String? ?? 'Unknown',
    calories: (nutriments['energy-kcal_100g'] ?? 0).toDouble(),
    protein: (nutriments['proteins_100g'] ?? 0).toDouble(),
    carbs: (nutriments['carbohydrates_100g'] ?? 0).toDouble(),
    fat: (nutriments['fat_100g'] ?? 0).toDouble(),
    );
  }

  void dispose() {
    _client.close();
  }
}