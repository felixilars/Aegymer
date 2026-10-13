// Calculates the calories burned during a workout based on parameters such as duration, intensity, and type of exercise.

import 'dart:math';

class WorkoutCalculator {
  // e1RM - Estimated 1 Rep Max
  // e1RM = weight * (1 + (reps / 30))
  static double calculateE1RM(double weight, int reps) {
    if (reps <= 0) {
      return 0.0;
    }
    if (reps == 1) {
      return weight;
    }
    return weight * (1 + (reps / 30.0));
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

  // Volume load
  // Volume = Weight * Reps * Sets
  static double calculateVolume(List<double> weights, List<int> reps) {
    double total = 0.0;
    int limit = min(weights.length, reps.length);
    for (int i = 0; i < limit; i++) {
      total += weights[i] * reps[i];
    }
    return total;
  }

  // Rep Drop-off Rate
  // DropOff = (Reps_set_1 - Reps_set_n) / Reps_set_1
  static double calculateDropOffRate(List<int> reps) {
    if (reps.isEmpty || reps.first <= 0) return 0.0;
    int firstRep = reps.first;
    int lastRep = reps.last;
    return (firstRep - lastRep) / firstRep.toDouble();
  }

  // ACWR (Acute-to-Chronic Workload Ratio)
  // ACWR = Current session volume / Average volume of the previous 4 training sessions
  static double calculateACWR(double currentVolume, List<double> past4Volumes) {
    if (past4Volumes.isEmpty) return 1.0; // Default to equilibrium
    double avgPastVolume =
        past4Volumes.reduce((a, b) => a + b) / past4Volumes.length;
    if (avgPastVolume <= 0) return 1.0;
    return currentVolume / avgPastVolume;
  }

  // Translate input weight to effective weight based on weightType and bodyweight
  static double getEffectiveWeight({
    required double weightInput,
    required String weightType,
    required double userBodyweight,
  }) {
    switch (weightType) {
      case 'added':
      case 'bodyweight_weighted':
        return userBodyweight + weightInput;
      case 'assisted':
      case 'bodyweight_assisted':
        return max(0.0, userBodyweight - weightInput);
      case 'bodyweight':
        return userBodyweight;
      default: // standard / weight_external / machine_stack
        return weightInput;
    }
  }

  // Convert effective weight back to raw input weight based on trackingType and bodyweight
  static double getRawInputWeight({
    required double effectiveWeight,
    required String trackingType,
    required double userBodyweight,
  }) {
    switch (trackingType) {
      case 'bodyweight_weighted':
        return max(0.0, effectiveWeight - userBodyweight);
      case 'bodyweight_assisted':
        return max(0.0, userBodyweight - effectiveWeight);
      case 'bodyweight':
      case 'cardio_time':
      case 'time_only':
        return 0.0;
      default: // standard / weight_external / machine_stack / mixed
        return effectiveWeight;
    }
  }

  // Normalize and resolve database tracking types to the 6 standard ones with heuristic fallbacks
  static String normalizeTrackingType(
    String? dbTrackingType, {
    required String name,
    required String targetMuscle,
    required String equipment,
  }) {
    if (dbTrackingType != null && dbTrackingType.isNotEmpty) {
      if (dbTrackingType == 'weight_reps' ||
          dbTrackingType == 'weight_external' ||
          dbTrackingType == 'machine_stack' ||
          dbTrackingType == 'mixed') {
        return 'weight_reps';
      }
      if (dbTrackingType == 'bodyweight' ||
          dbTrackingType == 'bodyweight_weighted' ||
          dbTrackingType == 'bodyweight_assisted' ||
          dbTrackingType == 'cardio_time' ||
          dbTrackingType == 'time_only') {
        return dbTrackingType;
      }
    }

    // Heuristic fallbacks if null, empty, or not matching standard types
    final nameLower = name.toLowerCase();
    final muscleLower = targetMuscle.toLowerCase();
    final equipLower = equipment.toLowerCase();

    if (muscleLower.contains('cardio') ||
        nameLower.contains('running') ||
        nameLower.contains('treadmill') ||
        nameLower.contains('cycling') ||
        nameLower.contains('jump rope') ||
        nameLower.contains('rowing') ||
        nameLower.contains('elliptical') ||
        nameLower.contains('swimming') ||
        nameLower.contains('bike') ||
        nameLower.contains('walk') ||
        nameLower.contains('jog')) {
      return 'cardio_time';
    }

    if (nameLower.contains('weighted pull-up') ||
        nameLower.contains('weighted dip') ||
        nameLower.contains('weighted pullup')) {
      return 'bodyweight_weighted';
    }

    if (nameLower.contains('assisted pull-up') ||
        nameLower.contains('assisted dip') ||
        nameLower.contains('assisted pullup')) {
      return 'bodyweight_assisted';
    }

    if (equipLower.contains('bodyweight') ||
        nameLower.contains('push-up') ||
        nameLower.contains('pushup') ||
        nameLower.contains('sit-up') ||
        nameLower.contains('situp') ||
        nameLower.contains('crunch') ||
        nameLower.contains('plank')) {
      return 'bodyweight';
    }

    return 'weight_reps';
  }

  // Default input weight by trackingType
  static double getDefaultInputWeight(String trackingType) {
    switch (trackingType) {
      case 'weight_reps':
      case 'machine_stack':
      case 'weight_external':
      case 'mixed':
        return 40.0;
      case 'bodyweight_assisted':
        return 20.0; // 20kg assistant weight
      case 'bodyweight_weighted':
      case 'bodyweight':
      case 'cardio_time':
      case 'time_only':
      default:
        return 0.0;
    }
  }
  
  // Get MET (Metabolic Equivalent of Task) for common gym exercises
  static double getMETForExercise(String exerciseName, String equipment) {
    final nameLower = exerciseName.toLowerCase();
    final equipLower = equipment.toLowerCase();
    
    if (nameLower.contains('deadlift') || 
        nameLower.contains('squat') || 
        nameLower.contains('bench press') || 
        equipLower.contains('barbell')) {
      return 6.0; // Heavy weight training
    } else if (equipLower.contains('bodyweight') || 
               nameLower.contains('pushup') || 
               nameLower.contains('pullup') || 
               nameLower.contains('chinup')) {
      return 4.0; // Moderate/Vigorous bodyweight exercises (3.0 - 5.0 range)
    } else if (nameLower.contains('running') || 
               nameLower.contains('cycling') || 
               nameLower.contains('cardio')) {
      return 6.0; // Cardio (5.0 - 7.0 range)
    }
    return 3.5; // Light/Moderate default
  }

  // Remove Vietnamese diacritics
  static String removeDiacritics(String str) {
    const vietnamese = {
      'a': '[àáạảãâầấậẩẫăằắặẳẵ]',
      'e': '[èéẹẻẽêềếệểễ]',
      'i': '[ìíịỉĩ]',
      'o': '[òóọỏõôồốộổỗơờớợởỡ]',
      'u': '[ùúụủũưừứựửữ]',
      'y': '[ỳýỵỷỹ]',
      'd': '[đ]',
      'A': '[ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴ]',
      'E': '[ÈÉẸẺẼÊỀẾỆỂỄ]',
      'I': '[ÌÍỊỈĨ]',
      'O': '[ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠ]',
      'U': '[ÙÚỤỦŨƯỪỨỰỬỮ]',
      'Y': '[ỲÝỴỶỸ]',
      'D': '[Đ]'
    };
    
    var result = str;
    for (var entry in vietnamese.entries) {
      result = result.replaceAll(RegExp(entry.value), entry.key);
    }
    return result;
  }

  // Optimize search matching by comparing simplified alphanumeric terms
  static bool matchesSearch({
    required String exerciseName,
    required String targetMuscle,
    required String query,
  }) {
    if (query.trim().isEmpty) return true;

    String clean(String s) {
      return removeDiacritics(s).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    }

    final cleanName = clean(exerciseName);
    final cleanMuscle = clean(targetMuscle);

    // Split search query into multiple words/terms
    final terms = query
        .toLowerCase()
        .split(RegExp(r'[\s\-_,\.\/]+'))
        .where((t) => t.trim().isNotEmpty);

    if (terms.isEmpty) return true;

    // Every term in the query must match either the exercise name or target muscle
    for (final term in terms) {
      final cleanTerm = clean(term);
      if (cleanTerm.isEmpty) continue;

      if (!cleanName.contains(cleanTerm) && !cleanMuscle.contains(cleanTerm)) {
        return false;
      }
    }

    return true;
  }
}
