import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_application_1/core/databases/app_database.dart'; // Import your Drift AppDatabase file here

class MealPrepPage extends StatelessWidget {
  final AppDatabase db;

  const MealPrepPage({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Prep'),
        centerTitle: true,
      ),
      // Watch query automatically streams live updates from SQLite
      body: StreamBuilder<List<Food>>(
        stream: db.select(db.foods).watch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final foods = snapshot.data ?? [];

          if (foods.isEmpty) {
            return const Center(
              child: Text(
                'No food items in the database.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: foods.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final food = foods[index];
              return FoodCard(food: food);
            },
          );
        },
      ),
    );
  }
}

class FoodCard extends StatelessWidget {
  final Food food;

  const FoodCard({super.key, required this.food});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Food Name & Custom Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    food.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Chip(
                  label: Text(
                    food.isCustom ? 'Custom' : 'System',
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                  backgroundColor: food.isCustom ? Colors.orange : Colors.blue,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            
            // Subtitle: Category & Calories
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Category: ${food.category ?? "Uncategorized"}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const Spacer(),
                Text(
                  '${food.calories.toStringAsFixed(0)} kcal',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            
            const Divider(height: 20),

            // Macros Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MacroIndicator(
                  label: 'Protein',
                  value: '${food.protein.toStringAsFixed(1)}g',
                  color: Colors.redAccent,
                ),
                _MacroIndicator(
                  label: 'Carbs',
                  value: '${food.carbs.toStringAsFixed(1)}g',
                  color: Colors.amber[800]!,
                ),
                _MacroIndicator(
                  label: 'Fat',
                  value: '${food.fat.toStringAsFixed(1)}g',
                  color: Colors.blueAccent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroIndicator extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroIndicator({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}