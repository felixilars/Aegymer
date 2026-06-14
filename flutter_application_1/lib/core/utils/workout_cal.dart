// Calculates the calories burned during a workout based on parameters such as duration, intensity, and type of exercise.

class WorkoutCalculator {
  // e1RM - Estimated 1 Rep Max
  // e1RM = weight * (1 + (reps / 30))
  static double calculateE1RM(double weight, int reps) {
    if (reps <= 0) {
      return 0.0;
    }
    return weight * (1 + (reps / 30));
  }

  // Calories burned during a workout
  // MET (Metabolic Equivalent of Task) values for different exercises
  // Example MET values: Running (8.0), Cycling (7.5), Swimming (6.0)
  // Calories burned = MET * 3.5 * bodyweight (kg) / 200 * duration (minutes)
  // Reference MET value:
  // - Light/Moderate weight training: 3.0 to 5.0
  // - Heavy weight training: 6.0
  // - Cardio exercises: 5.0 to 7.0
  static double calculateCaloriesBurned({
    required double bodyweightKg,
    required int durationMinutes,
    required double met,
  }) {
    if (durationMinutes <= 0 || bodyweightKg <= 0 || met <= 0) {
      return 0.0;
    }
    return (met * 3.5 * bodyweightKg / 200.0 * durationMinutes);
  }
}