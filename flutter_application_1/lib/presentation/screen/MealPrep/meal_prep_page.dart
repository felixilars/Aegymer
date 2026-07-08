import 'package:flutter/material.dart';

class MealPrepPage extends StatelessWidget {
  const MealPrepPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Prep'),
      ),
      body: const Center(
        child: Text('Meal Prep Page'),
      ),
    );
  }
}