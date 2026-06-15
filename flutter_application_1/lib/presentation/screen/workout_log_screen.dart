import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/utils/workout_cal.dart';

class WorkoutLogScreen extends StatefulWidget {
  const WorkoutLogScreen({super.key});

  @override
  State<WorkoutLogScreen> createState() => _WorkoutLogScreenState();
}

class _WorkoutLogScreenState extends State<WorkoutLogScreen> {
  final bodyweightController = TextEditingController();
  final durationController = TextEditingController();
  final metController = TextEditingController();

  
  final weightsController = TextEditingController();
  final repsController = TextEditingController();

  double caloriesBurned = 0;
  double e1rm = 0;

  void calculateCalories() {
    double bodyweight =
        double.tryParse(bodyweightController.text) ?? 0;

    int duration =
        int.tryParse(durationController.text) ?? 0;

    double met =
        double.tryParse(metController.text) ?? 0;

    setState(() {
      caloriesBurned =
          WorkoutCalculator.calculateCaloriesBurned(
        bodyweightKg: bodyweight,
        durationMinutes: duration,
        met: met,
      );
    });
  }

  void calculateE1RM() {
    double weight =
        double.tryParse(weightsController.text) ?? 0;

    int reps =
        int.tryParse(repsController.text) ?? 0;

    double met =
        double.tryParse(metController.text) ?? 0;

    setState(() {
      e1rm = WorkoutCalculator.calculateE1RM(weight, reps);
    });
  }

 


  @override
  void dispose() {
    bodyweightController.dispose();
    durationController.dispose();
    metController.dispose();
    weightsController.dispose();
    repsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("workout_log_screen"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: bodyweightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Bodyweight (kg)",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Duration (minutes)",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: metController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "met",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: calculateCalories,
              child: const Text("Calculate"),
            ),

            const SizedBox(height: 25),

            Text(
              "Calories Burned: ${caloriesBurned.toStringAsFixed(2)} kcal",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            TextField(
              controller: weightsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Weight (kg)",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: repsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Reps",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: calculateE1RM,
              child: const Text("Calculate E1RM"),
            ),

            const SizedBox(height: 25),

            Text(
              "1 rep max: ${e1rm.toStringAsFixed(1)}",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            )
          ],
        ),
        
      ),
    );
  }
}

