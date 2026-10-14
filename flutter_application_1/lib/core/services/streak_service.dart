import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aegymer/core/databases/app_database.dart';
import 'package:aegymer/core/utils/workout_cal.dart';

/// Data class holding summary of all streak metrics
class StreakSummary {
  final int currentDailyStreak;
  final int bestDailyStreak;
  final int currentWeeklyStreak;
  final int bestWeeklyStreak;
  final int weeklyGoal;
  final int weeklyWorkoutCount;
  final List<bool> weekActivityDays; // Mon (0) to Sun (6)
  final String totalSessions;
  final String totalCalories;
  final String totalTimeFormatted;
  final String totalVolume;
  final int totalSets;

  StreakSummary({
    required this.currentDailyStreak,
    required this.bestDailyStreak,
    required this.currentWeeklyStreak,
    required this.bestWeeklyStreak,
    required this.weeklyGoal,
    required this.weeklyWorkoutCount,
    required this.weekActivityDays,
    required this.totalSessions,
    required this.totalCalories,
    required this.totalTimeFormatted,
    this.totalVolume = '0 kg',
    this.totalSets = 0,
  });

  /// Streak level tier indicator based on daily streak
  String get streakTierName {
    if (currentDailyStreak >= 14) return 'Legendary';
    if (currentDailyStreak >= 7) return 'Unstoppable';
    if (currentDailyStreak >= 3) return 'On Fire';
    if (currentDailyStreak >= 1) return 'Warmup';
    return 'Start Today';
  }
}

class StreakService {
  static const String keyWeeklyGoal = 'weekly_workout_goal';
  static const String keyBestDailyStreak = 'best_daily_streak';
  static const String keyBestWeeklyStreak = 'best_weekly_streak';

  /// Global notifier that fires whenever workouts are logged, updated, or removed
  static final ValueNotifier<int> workoutUpdateNotifier = ValueNotifier<int>(0);

  /// Call this whenever a workout is saved or deleted to notify all screens
  static void notifyWorkoutUpdated() {
    workoutUpdateNotifier.value++;
  }

  /// Fetch complete streak metrics in one unified service call
  static Future<StreakSummary> loadStreakSummary(AppDatabase db) async {
    final prefs = await SharedPreferences.getInstance();
    final weeklyGoal = prefs.getInt(keyWeeklyGoal) ?? 4;

    // Fetch all workout sessions ordered by date desc
    final sessions =
        await (db.select(db.workoutSessions)..orderBy([
              (t) => drift.OrderingTerm(
                expression: t.date,
                mode: drift.OrderingMode.desc,
              ),
            ]))
            .get();

    final sessionDates =
        sessions
            .map((s) => DateTime(s.date.year, s.date.month, s.date.day))
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a)); // Descending order

    // 1. Calculate Daily Streak & All-Time Historical Best Streak
    final dailyStreak = _calculateCurrentDailyStreak(sessionDates);
    final allTimeBestFromHistory = _calculateAllTimeBestDailyStreak(sessionDates);
    int bestDaily = max(prefs.getInt(keyBestDailyStreak) ?? 0, allTimeBestFromHistory);
    if (dailyStreak > bestDaily) {
      bestDaily = dailyStreak;
    }
    await prefs.setInt(keyBestDailyStreak, bestDaily);

    // 2. Calculate current week details
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Monday of current week
    final startOfWeek = DateTime(today.year, today.month, today.day - (today.weekday - 1));

    final weekActivityDays = List<bool>.filled(7, false);
    final thisWeekSessions = <WorkoutSession>[];

    final sessionDaysSet = <DateTime>{};
    for (final s in sessions) {
      final sessionDay = DateTime(s.date.year, s.date.month, s.date.day);
      sessionDaysSet.add(sessionDay);

      if (sessionDay.isAfter(
        startOfWeek.subtract(const Duration(seconds: 1)),
      )) {
        thisWeekSessions.add(s);
        final dayIndex = sessionDay.weekday - 1; // 0 = Mon, 6 = Sun
        if (dayIndex >= 0 && dayIndex < 7) {
          weekActivityDays[dayIndex] = true;
        }
      }
    }

    final weeklyWorkoutCount = weekActivityDays
        .where((active) => active)
        .length;

    // 3. Calculate Weekly Streak
    final weeklyStreak = _calculateWeeklyStreak(
      sessionDaysSet,
      weeklyGoal,
      startOfWeek,
    );
    int bestWeekly = prefs.getInt(keyBestWeeklyStreak) ?? 0;
    if (weeklyStreak > bestWeekly) {
      bestWeekly = weeklyStreak;
      await prefs.setInt(keyBestWeeklyStreak, bestWeekly);
    }

    // 4. Calculate Weekly Stats (Calories, Time, Sessions)
    final stats = await _calculateWeeklyStats(
      db,
      thisWeekSessions,
      startOfWeek,
    );

    return StreakSummary(
      currentDailyStreak: dailyStreak,
      bestDailyStreak: bestDaily,
      currentWeeklyStreak: weeklyStreak,
      bestWeeklyStreak: bestWeekly,
      weeklyGoal: weeklyGoal,
      weeklyWorkoutCount: weeklyWorkoutCount,
      weekActivityDays: weekActivityDays,
      totalSessions: stats['sessions'] ?? '0',
      totalCalories: stats['calories'] ?? '0',
      totalTimeFormatted: stats['time'] ?? '0m',
      totalVolume: stats['volume'] ?? '0 kg',
      totalSets: int.tryParse(stats['sets'] ?? '0') ?? 0,
    );
  }

  /// Updates weekly goal in SharedPreferences
  static Future<void> setWeeklyGoal(int goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyWeeklyGoal, goal);
    notifyWorkoutUpdated();
  }

  /// Internal logic for Daily Streak
  static int _calculateCurrentDailyStreak(List<DateTime> sessionDates) {
    if (sessionDates.isEmpty) return 0;

    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final yesterdayKey = DateTime(today.year, today.month, today.day - 1);

    // Must have a session today or yesterday to maintain active streak
    if (sessionDates.first != todayKey && sessionDates.first != yesterdayKey) {
      return 0;
    }

    int streak = 1;
    DateTime currentDay = sessionDates.first;

    for (int i = 1; i < sessionDates.length; i++) {
      final previousDay = sessionDates[i];
      final expectedPrev = DateTime(currentDay.year, currentDay.month, currentDay.day - 1);
      if (previousDay == expectedPrev) {
        streak++;
        currentDay = previousDay;
      } else {
        break;
      }
    }

    return streak;
  }

  /// Calculates the longest consecutive daily streak across all recorded history
  static int _calculateAllTimeBestDailyStreak(List<DateTime> sortedDescDates) {
    if (sortedDescDates.isEmpty) return 0;

    int maxStreak = 1;
    int currentStreak = 1;

    for (int i = 0; i < sortedDescDates.length - 1; i++) {
      final current = sortedDescDates[i];
      final next = sortedDescDates[i + 1];
      final expectedNext = DateTime(current.year, current.month, current.day - 1);

      if (next == expectedNext) {
        currentStreak++;
        if (currentStreak > maxStreak) {
          maxStreak = currentStreak;
        }
      } else {
        currentStreak = 1;
      }
    }

    return maxStreak;
  }

  /// Internal logic for Weekly Streak (consecutive target-reaching weeks)
  static int _calculateWeeklyStreak(
    Set<DateTime> sessionDays,
    int weeklyGoal,
    DateTime currentWeekMonday,
  ) {
    if (sessionDays.isEmpty) return 0;

    int streak = 0;
    DateTime mondayOfEvaluatedWeek = currentWeekMonday;

    // First, check if current week already met goal
    int currentWeekCount = 0;
    for (int i = 0; i < 7; i++) {
      final day = DateTime(mondayOfEvaluatedWeek.year, mondayOfEvaluatedWeek.month, mondayOfEvaluatedWeek.day + i);
      if (sessionDays.contains(day)) currentWeekCount++;
    }

    if (currentWeekCount >= weeklyGoal) {
      streak++;
    }

    // Move to previous week
    mondayOfEvaluatedWeek = DateTime(
      mondayOfEvaluatedWeek.year,
      mondayOfEvaluatedWeek.month,
      mondayOfEvaluatedWeek.day - 7,
    );

    while (true) {
      int weekWorkoutCount = 0;
      for (int i = 0; i < 7; i++) {
        final day = DateTime(mondayOfEvaluatedWeek.year, mondayOfEvaluatedWeek.month, mondayOfEvaluatedWeek.day + i);
        if (sessionDays.contains(day)) weekWorkoutCount++;
      }

      if (weekWorkoutCount >= weeklyGoal) {
        streak++;
        mondayOfEvaluatedWeek = DateTime(
          mondayOfEvaluatedWeek.year,
          mondayOfEvaluatedWeek.month,
          mondayOfEvaluatedWeek.day - 7,
        );
      } else {
        break; // Streak ends at first missed week
      }
    }

    return streak;
  }

  /// Calculate calories, volume, and total workout time for this week
  static Future<Map<String, String>> _calculateWeeklyStats(
    AppDatabase db,
    List<WorkoutSession> thisWeekSessions,
    DateTime startOfWeek,
  ) async {
    final sessionsCount = thisWeekSessions.length;

    // Get user weight for accurate workout calories burned calculation
    double userWeight = 70.0;
    try {
      final profile = await (db.select(db.userProfiles)..limit(1)).getSingleOrNull();
      if (profile != null && profile.weight > 0) {
        userWeight = profile.weight;
      }
    } catch (_) {}

    final sessionIds = thisWeekSessions.map((s) => s.id).toList();
    int totalSeconds = 0;
    double totalVolume = 0.0;
    int totalSets = 0;
    double totalBurnedCalories = 0.0;
    double totalDistanceKm = 0.0;

    if (sessionIds.isNotEmpty) {
      final sets = await (db.select(
        db.workoutSets,
      )..where((t) => t.sessionId.isIn(sessionIds))).get();
      totalSets = sets.length;

      // Query only relevant exercises for these sets to avoid full table scans on startup
      final exIds = sets.map((s) => s.exerciseId).toSet().toList();
      final relevantExercises = exIds.isNotEmpty
          ? await (db.select(db.exercises)..where((e) => e.id.isIn(exIds))).get()
          : <Exercise>[];
      final exerciseMap = {for (var e in relevantExercises) e.id: e};

      final setsBySession = <String, List<WorkoutSet>>{};
      for (var set in sets) {
        setsBySession.putIfAbsent(set.sessionId, () => []).add(set);
        totalVolume += (set.weight * set.reps);
        if (set.distance != null && set.distance! > 0) {
          totalDistanceKm += set.distance!;
        }

        final ex = exerciseMap[set.exerciseId];
        final exName = ex?.name ?? '';
        final targetMuscle = ex?.targetMuscle ?? '';
        final equip = ex?.equipment ?? '';
        final trackingType = WorkoutCalculator.normalizeTrackingType(
          ex?.trackingType,
          name: exName,
          targetMuscle: targetMuscle,
          equipment: equip,
        );

        final setCalories = WorkoutCalculator.calculateSetCalories(
          exerciseName: exName,
          targetMuscle: targetMuscle,
          equipment: equip,
          trackingType: trackingType,
          bodyweightKg: userWeight,
          weight: set.weight,
          reps: set.reps,
          distanceKm: set.distance ?? 0.0,
          durationSeconds: set.durationSeconds ?? 90,
        );
        totalBurnedCalories += setCalories;
      }

      for (var entry in setsBySession.entries) {
        final sessionSets = entry.value;
        int sessionSeconds = 0;
        for (var s in sessionSets) {
          if (s.durationSeconds != null && s.durationSeconds! > 0) {
            sessionSeconds += s.durationSeconds!;
          }
        }
        // If session had no recorded duration seconds (e.g. legacy sets), estimate 90s per set
        if (sessionSeconds == 0 && sessionSets.isNotEmpty) {
          sessionSeconds = sessionSets.length * 90;
        }
        totalSeconds += sessionSeconds;
      }
    }

    String timeString = "0m";
    if (totalSeconds > 0) {
      final hours = totalSeconds ~/ 3600;
      final minutes = (totalSeconds % 3600) ~/ 60;
      if (hours > 0) {
        timeString = "${hours}h ${minutes}m";
      } else {
        timeString = "${minutes}m";
      }
    }

    // Fallback if no sets were recorded but duration was tracked
    if (totalBurnedCalories <= 0 && totalSeconds > 0) {
      final durationMinutes = (totalSeconds / 60.0).round();
      totalBurnedCalories = WorkoutCalculator.calculateCaloriesBurned(
        bodyweightKg: userWeight,
        durationMinutes: durationMinutes,
        met: 5.0,
      );
    }

    String volumeString = '0 kg';
    if (totalVolume >= 1000) {
      volumeString = '${(totalVolume / 1000).toStringAsFixed(1)}k kg';
    } else if (totalVolume > 0) {
      volumeString = '${totalVolume.toStringAsFixed(0)} kg';
    }

    return {
      'sessions': sessionsCount.toString(),
      'calories': totalBurnedCalories.round().toString(),
      'time': timeString,
      'volume': volumeString,
      'sets': totalSets.toString(),
      'distance': totalDistanceKm.toStringAsFixed(2),
    };
  }
}
