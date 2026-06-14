import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/utils/workout_cal.dart';

class WorkoutLogScreen extends StatelessWidget {
  const WorkoutLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final e1rm = WorkoutCalculator.calculateE1RM(60, 10);
    final calories = WorkoutCalculator.calculateCaloriesBurned(
      bodyweightKg: 80,
      durationMinutes: 45,
      met: 7.0,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Log'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('E1RM: ${e1rm.toStringAsFixed(1)} kg'),
            const SizedBox(height: 8),
            Text('Calories burned: ${calories.toStringAsFixed(0)} kcal'),
          ],
        ),
      ),
    );
  }
}