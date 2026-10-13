import 'dart:math';

class WorkoutCalculator {
  static double calculateE1RM(double weight, int reps) {
    if (reps <= 0) {
      return 0.0;
    }
    if (reps == 1) {
      return weight;
    }
    return weight * (1 + (reps / 30.0));
  }

  static double calculateCaloriesBurned({
    required double bodyweightKg,
    required int durationMinutes,
    required double met,
    double distanceKm = 0.0,
    String exerciseName = '',
  }) {
    if (bodyweightKg <= 0) bodyweightKg = 70.0;
    final nameLower = exerciseName.toLowerCase();

    if (distanceKm > 0) {
      if (nameLower.contains('cycl') || nameLower.contains('bike')) {
        return 0.35 * bodyweightKg * distanceKm;
      } else if (nameLower.contains('walk')) {
        return 0.75 * bodyweightKg * distanceKm;
      } else {
        return 1.036 * bodyweightKg * distanceKm;
      }
    }

    if (durationMinutes <= 0 || met <= 0) {
      return 0.0;
    }
    return (met * 3.5 * bodyweightKg / 200.0 * durationMinutes);
  }

  static String calculatePaceString(double distanceKm, int durationSeconds) {
    if (distanceKm <= 0 || durationSeconds <= 0) return '--:-- min/km';
    final paceSecs = (durationSeconds / distanceKm).round();
    final mins = paceSecs ~/ 60;
    final secs = paceSecs % 60;
    return '$mins:${secs.toString().padLeft(2, '0')} min/km';
  }

  static double calculateSpeedKmh(double distanceKm, int durationSeconds) {
    if (distanceKm <= 0 || durationSeconds <= 0) return 0.0;
    final hours = durationSeconds / 3600.0;
    return distanceKm / hours;
  }

  static double calculateSetCalories({
    required String exerciseName,
    required String targetMuscle,
    required String equipment,
    required String trackingType,
    required double bodyweightKg,
    double weight = 0.0,
    int reps = 0,
    double distanceKm = 0.0,
    int durationSeconds = 0,
  }) {
    if (bodyweightKg <= 0) bodyweightKg = 70.0;
    final nameLower = exerciseName.toLowerCase();
    final durationMinutes = durationSeconds / 60.0;

    // Cardio
    if (trackingType == 'cardio_time' || targetMuscle.toLowerCase() == 'cardio') {
      if (distanceKm <= 0 && durationSeconds <= 0) {
        return 0.0;
      }

      // Running / Treadmill
      if (nameLower.contains('run') ||
          nameLower.contains('treadmill') ||
          nameLower.contains('jog')) {
        if (distanceKm > 0) {
          return 1.036 * bodyweightKg * distanceKm;
        }
        const met = 9.5;
        return (met * 3.5 * bodyweightKg / 200.0) * durationMinutes;
      }

      // Cycling / Bike
      if (nameLower.contains('cycl') ||
          nameLower.contains('bike')) {
        if (distanceKm > 0) {
          return 0.35 * bodyweightKg * distanceKm;
        }
        const met = 7.5;
        return (met * 3.5 * bodyweightKg / 200.0) * durationMinutes;
      }

      // Jump Rope
      if (nameLower.contains('jump rope') ||
          nameLower.contains('skipping')) {
        const met = 11.0;
        return (met * 3.5 * bodyweightKg / 200.0) * durationMinutes;
      }

      // Rowing
      if (nameLower.contains('row')) {
        const met = 7.5;
        return (met * 3.5 * bodyweightKg / 200.0) * durationMinutes;
      }

      // Walking
      if (nameLower.contains('walk')) {
        if (distanceKm > 0) {
          return 0.75 * bodyweightKg * distanceKm;
        }
        const met = 3.8;
        return (met * 3.5 * bodyweightKg / 200.0) * durationMinutes;
      }

      // Generic cardio default
      if (distanceKm > 0) {
        return 0.85 * bodyweightKg * distanceKm;
      }
      const met = 7.0;
      return (met * 3.5 * bodyweightKg / 200.0) * durationMinutes;
    }

    // Time-only isometric holds
    if (trackingType == 'time_only') {
      if (durationSeconds <= 0 && reps <= 0) return 0.0;
      const met = 3.8;
      final effectiveMins = durationMinutes > 0 ? durationMinutes : (reps > 0 ? reps / 60.0 : 0.0);
      return (met * 3.5 * bodyweightKg / 200.0) * effectiveMins;
    }

    // Bodyweight movements
    if (trackingType == 'bodyweight' ||
        trackingType == 'bodyweight_weighted' ||
        trackingType == 'bodyweight_assisted' ||
        equipment.toLowerCase() == 'bodyweight') {
      if (reps <= 0 && durationSeconds <= 0) return 0.0;
      double met = 4.5;
      if (nameLower.contains('pull-up') ||
          nameLower.contains('chin-up') ||
          nameLower.contains('dip') ||
          nameLower.contains('burpee')) {
        met = 6.0;
      }
      if (trackingType == 'bodyweight_weighted') met += 0.5;

      final mins = durationMinutes > 0 ? durationMinutes : (reps > 0 ? reps * 0.05 : 1.0);
      final baseMetKcal = (met * 3.5 * bodyweightKg / 200.0) * mins;
      final workKcal = (weight * reps) * 0.0005;
      return baseMetKcal + workKcal;
    }

    // External resistance / weight training
    if (reps <= 0 && weight <= 0 && durationSeconds <= 0) return 0.0;
    double met = 4.5;
    if (nameLower.contains('deadlift') ||
        nameLower.contains('squat') ||
        nameLower.contains('bench press') ||
        equipment.toLowerCase().contains('barbell')) {
      met = 6.0;
    }
    final mins = durationMinutes > 0 ? durationMinutes : (reps > 0 ? reps * 0.05 : 1.0);
    final baseMetKcal = (met * 3.5 * bodyweightKg / 200.0) * mins;
    final workKcal = (weight * reps) * 0.0005;
    return baseMetKcal + workKcal;
  }

  static double calculateVolume(List<double> weights, List<int> reps) {
    double total = 0.0;
    int limit = min(weights.length, reps.length);
    for (int i = 0; i < limit; i++) {
      total += weights[i] * reps[i];
    }
    return total;
  }

  static double calculateDropOffRate(List<int> reps) {
    if (reps.isEmpty || reps.first <= 0) return 0.0;
    int firstRep = reps.first;
    int lastRep = reps.last;
    return (firstRep - lastRep) / firstRep.toDouble();
  }

  static double calculateACWR(double currentVolume, List<double> past4Volumes) {
    if (past4Volumes.isEmpty) return 1.0;
    double avgPastVolume =
        past4Volumes.reduce((a, b) => a + b) / past4Volumes.length;
    if (avgPastVolume <= 0) return 1.0;
    return currentVolume / avgPastVolume;
  }

  static double getBodyweightFactor(String exerciseName) {
    final name = exerciseName.toLowerCase();

    // Pull-ups / Chin-ups
    if (name.contains('pull-up') ||
        name.contains('pull up') ||
        name.contains('pullup') ||
        name.contains('chin-up') ||
        name.contains('chin up') ||
        name.contains('chinup')) {
      return 1.00;
    }

    // Dips
    if (name.contains('dip')) {
      return 0.90;
    }

    // Push-up variations
    if (name.contains('push-up') ||
        name.contains('push up') ||
        name.contains('pushup')) {
      if (name.contains('decline')) return 0.74;
      if (name.contains('incline') || name.contains('knee')) return 0.50;
      return 0.65;
    }

    // Inverted rows
    if (name.contains('inverted row') || name.contains('australian')) {
      return 0.65;
    }

    // Squat / Lunges / Step-up
    if (name.contains('squat') ||
        name.contains('lunge') ||
        name.contains('step-up') ||
        name.contains('step up') ||
        name.contains('pistol')) {
      return 0.70;
    }

    // Core / Crunches / Sit-ups
    if (name.contains('crunch') ||
        name.contains('sit-up') ||
        name.contains('sit up') ||
        name.contains('situp') ||
        name.contains('leg raise')) {
      return 0.35;
    }

    return 1.00;
  }

  static String getBodyweightExplanation(String exerciseName) {
    final factor = getBodyweightFactor(exerciseName);
    final percent = (factor * 100).toStringAsFixed(0);
    final name = exerciseName.toLowerCase();

    if (name.contains('push-up') || name.contains('pushup')) {
      return '$percent% BW (feet support remaining ~35%)';
    } else if (name.contains('pull-up') || name.contains('chin-up')) {
      return '$percent% BW (full body suspended)';
    } else if (name.contains('dip')) {
      return '$percent% BW (arms support upper and lower trunk)';
    } else if (name.contains('squat') || name.contains('lunge')) {
      return '$percent% BW (lower legs planted)';
    } else if (name.contains('crunch') || name.contains('sit-up')) {
      return '$percent% BW (upper trunk elevation)';
    }
    return '$percent% of bodyweight';
  }

  static double getEffectiveWeight({
    required double weightInput,
    required String weightType,
    required double userBodyweight,
    String exerciseName = '',
  }) {
    final factor = exerciseName.isNotEmpty ? getBodyweightFactor(exerciseName) : 1.0;
    final baseBodyweightLoad = userBodyweight * factor;

    switch (weightType) {
      case 'added':
      case 'bodyweight_weighted':
        return baseBodyweightLoad + weightInput;
      case 'assisted':
      case 'bodyweight_assisted':
        return max(0.0, baseBodyweightLoad - weightInput);
      case 'bodyweight':
        return baseBodyweightLoad;
      default:
        return weightInput;
    }
  }

  static double getRawInputWeight({
    required double effectiveWeight,
    required String trackingType,
    required double userBodyweight,
    String exerciseName = '',
  }) {
    final factor = exerciseName.isNotEmpty ? getBodyweightFactor(exerciseName) : 1.0;
    final baseBodyweightLoad = userBodyweight * factor;

    switch (trackingType) {
      case 'bodyweight_weighted':
        return max(0.0, effectiveWeight - baseBodyweightLoad);
      case 'bodyweight_assisted':
        return max(0.0, baseBodyweightLoad - effectiveWeight);
      case 'bodyweight':
      case 'cardio_time':
      case 'time_only':
        return 0.0;
      default:
        return effectiveWeight;
    }
  }

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

  static double getDefaultInputWeight(String trackingType) {
    switch (trackingType) {
      case 'weight_reps':
      case 'machine_stack':
      case 'weight_external':
      case 'mixed':
        return 40.0;
      case 'bodyweight_assisted':
        return 20.0;
      case 'bodyweight_weighted':
      case 'bodyweight':
      case 'cardio_time':
      case 'time_only':
      default:
        return 0.0;
    }
  }

  static double getMETForExercise(String exerciseName, String equipment) {
    final nameLower = exerciseName.toLowerCase();
    final equipLower = equipment.toLowerCase();

    if (nameLower.contains('deadlift') ||
        nameLower.contains('squat') ||
        nameLower.contains('bench press') ||
        equipLower.contains('barbell')) {
      return 6.0;
    } else if (equipLower.contains('bodyweight') ||
        nameLower.contains('pushup') ||
        nameLower.contains('pullup') ||
        nameLower.contains('chinup')) {
      return 4.0;
    } else if (nameLower.contains('running') ||
        nameLower.contains('cycling') ||
        nameLower.contains('cardio')) {
      return 6.0;
    }
    return 3.5;
  }

  static String cleanAlphanumeric(String str) {
    return str.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static bool matchesSearch({
    required String exerciseName,
    required String targetMuscle,
    required String query,
  }) {
    if (query.trim().isEmpty) return true;

    final cleanName = cleanAlphanumeric(exerciseName);
    final cleanMuscle = cleanAlphanumeric(targetMuscle);

    final terms = query
        .toLowerCase()
        .split(RegExp(r'[\s\-_,\.\/]+'))
        .where((t) => t.trim().isNotEmpty);

    if (terms.isEmpty) return true;

    for (final term in terms) {
      final cleanTerm = cleanAlphanumeric(term);
      if (cleanTerm.isEmpty) continue;

      if (!cleanName.contains(cleanTerm) && !cleanMuscle.contains(cleanTerm)) {
        return false;
      }
    }

    return true;
  }
}
