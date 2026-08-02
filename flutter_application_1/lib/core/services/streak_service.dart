import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/core/databases/app_database.dart';

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
  });

  /// Streak level tier indicator based on daily streak
  String get streakTierName {
    if (currentDailyStreak >= 14) return ' Legendary';
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

    // 1. Calculate Daily Streak
    final dailyStreak = _calculateCurrentDailyStreak(sessions);
    int bestDaily = prefs.getInt(keyBestDailyStreak) ?? 0;
    if (dailyStreak > bestDaily) {
      bestDaily = dailyStreak;
      await prefs.setInt(keyBestDailyStreak, bestDaily);
    }

    // 2. Calculate current week details
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Monday of current week
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));

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
    );
  }

  /// Updates weekly goal in SharedPreferences
  static Future<void> setWeeklyGoal(int goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyWeeklyGoal, goal);
  }

  /// Internal logic for Daily Streak
  static int _calculateCurrentDailyStreak(List<WorkoutSession> sessions) {
    if (sessions.isEmpty) return 0;

    final sessionDates =
        sessions
            .map((s) => DateTime(s.date.year, s.date.month, s.date.day))
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a)); // Descending order

    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final yesterdayKey = todayKey.subtract(const Duration(days: 1));

    // Must have a session today or yesterday to maintain active streak
    if (sessionDates.isEmpty ||
        (sessionDates.first != todayKey &&
            sessionDates.first != yesterdayKey)) {
      return 0;
    }

    int streak = 1;
    DateTime currentDay = sessionDates.first;

    for (int i = 1; i < sessionDates.length; i++) {
      final previousDay = sessionDates[i];
      final difference = currentDay.difference(previousDay).inDays;
      if (difference == 1) {
        streak++;
        currentDay = previousDay;
      } else if (difference > 1) {
        break;
      }
    }

    return streak;
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
      final day = mondayOfEvaluatedWeek.add(Duration(days: i));
      if (sessionDays.contains(day)) currentWeekCount++;
    }

    if (currentWeekCount >= weeklyGoal) {
      streak++;
    }

    // Move to previous week
    mondayOfEvaluatedWeek = mondayOfEvaluatedWeek.subtract(
      const Duration(days: 7),
    );

    while (true) {
      int weekWorkoutCount = 0;
      for (int i = 0; i < 7; i++) {
        final day = mondayOfEvaluatedWeek.add(Duration(days: i));
        if (sessionDays.contains(day)) weekWorkoutCount++;
      }

      if (weekWorkoutCount >= weeklyGoal) {
        streak++;
        mondayOfEvaluatedWeek = mondayOfEvaluatedWeek.subtract(
          const Duration(days: 7),
        );
      } else {
        break; // Streak ends at first missed week
      }
    }

    return streak;
  }

  /// Calculate calories and total workout time for this week
  static Future<Map<String, String>> _calculateWeeklyStats(
    AppDatabase db,
    List<WorkoutSession> thisWeekSessions,
    DateTime startOfWeek,
  ) async {
    final sessionsCount = thisWeekSessions.length;

    // Calculate total calories from user_meals, meal_items, and foods
    final query = db.select(db.mealItems).join([
      drift.innerJoin(
        db.userMeals,
        db.userMeals.id.equalsExp(db.mealItems.mealId),
      ),
      drift.innerJoin(
        db.foods,
        db.foods.id.equalsExp(db.mealItems.foodId),
      ),
    ])..where(db.userMeals.date.isBiggerOrEqualValue(startOfWeek));

    final rows = await query.get();
    double totalCalories = 0.0;
    for (var row in rows) {
      final item = row.readTable(db.mealItems);
      final food = row.readTable(db.foods);
      totalCalories += (food.calories * item.amount) / 100.0;
    }

    // Calculate total duration from workout_sets
    final sessionIds = thisWeekSessions.map((s) => s.id).toList();
    int totalSeconds = 0;
    if (sessionIds.isNotEmpty) {
      final sets = await (db.select(
        db.workoutSets,
      )..where((t) => t.sessionId.isIn(sessionIds))).get();
      for (var set in sets) {
        if (set.durationSeconds != null) {
          totalSeconds += set.durationSeconds!;
        }
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

    return {
      'sessions': sessionsCount.toString(),
      'calories': totalCalories.toStringAsFixed(0),
      'time': timeString,
    };
  }
}
