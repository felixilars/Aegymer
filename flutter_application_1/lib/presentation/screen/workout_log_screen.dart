import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/databases/app_database.dart';
import 'package:flutter_application_1/core/utils/workout_cal.dart';
import 'package:flutter_application_1/presentation/welcome_page.dart';
import 'package:drift/drift.dart' hide Column;

class WorkoutLogScreen extends StatefulWidget {
  const WorkoutLogScreen({super.key, this.database});

  final AppDatabase? database;

  @override
  State<WorkoutLogScreen> createState() => _WorkoutLogScreenState();
}

class _WorkoutLogScreenState extends State<WorkoutLogScreen> {
  late final AppDatabase _db;
  final bodyweightController = TextEditingController();
  final durationController = TextEditingController();
  final metController = TextEditingController();
  final weightsController = TextEditingController();
  final repsController = TextEditingController();
  final notesController = TextEditingController();

  double caloriesBurned = 0;
  double e1rm = 0;
  bool _saving = false;
  String? _saveMessage;

  @override
  void initState() {
    super.initState();
    _db = widget.database ?? AppDatabase();
  }

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

    setState(() {
      e1rm = WorkoutCalculator.calculateE1RM(weight, reps);
    });
  }

  Future<bool> saveSession() async {
    final weight = double.tryParse(weightsController.text) ?? 0;
    final reps = int.tryParse(repsController.text) ?? 0;
    final bodyweight = double.tryParse(bodyweightController.text) ?? 0;
    final duration = int.tryParse(durationController.text) ?? 0;
    final met = double.tryParse(metController.text) ?? 0;

    setState(() {
      caloriesBurned = WorkoutCalculator.calculateCaloriesBurned(
        bodyweightKg: bodyweight,
        durationMinutes: duration,
        met: met,
      );
      _saving = true;
      _saveMessage = null;
    });

    try {
      final sessionId = 'session-${DateTime.now().microsecondsSinceEpoch}';
      await _db.saveWorkoutSession(
        sessionId: sessionId,
        date: DateTime.now(),
        notes: notesController.text.isNotEmpty ? notesController.text : null,
        setsCompanions: [
          WorkoutSetsCompanion.insert(
            id: '$sessionId-set-1',
            sessionId: sessionId,
            exerciseId: 'exercise-test',
            setNumber: 1,
            weight: weight,
            reps: reps,
            rpe: const Value.absent(),
            calculated1rm: Value(e1rm > 0 ? e1rm : null),
            weightType: const Value.absent(),
            distance: const Value.absent(),
            durationSeconds: const Value.absent(),
          ),
        ],
      );

      setState(() {
        _saveMessage = 'Session saved successfully';
      });
      return true;
    } catch (e) {
      setState(() {
        _saveMessage = 'Failed to save session';
      });
      return false;
    } finally {
      setState(() {
        _saving = false;
      });
    }
  }

  @override
  void dispose() {
    bodyweightController.dispose();
    durationController.dispose();
    metController.dispose();
    weightsController.dispose();
    repsController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("workout_log_screen"),
      ),
      body: SingleChildScrollView(
        child: Padding(
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
            ),

            const SizedBox(height: 20),

            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Session notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving
                    ? null
                    : () async {
                        final saved = await saveSession();
                        if (!mounted) return;
                        if (saved) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const WelcomePage(),
                            ),
                          );
                        }
                      },
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save Session'),
              ),
            ),

            if (_saveMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _saveMessage!,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}

