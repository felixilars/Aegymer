import 'package:aegymer/core/databases/app_database.dart';

class ExerciseWithSets {
  final Exercise exercise;
  final List<WorkoutSet> sets;

  ExerciseWithSets({
    required this.exercise,
    required this.sets,
  });
}