import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/services/streak_service.dart';

class StreakDetailSheet extends StatelessWidget {
  final StreakSummary summary;
  final VoidCallback onSetGoalPressed;

  const StreakDetailSheet({
    super.key,
    required this.summary,
    required this.onSetGoalPressed,
  });

  static const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgCol = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final cardBg = isDark ? const Color(0xFF2A2A3D) : const Color(0xFFF3F4F6);
    final textCol = isDark ? Colors.white : const Color(0xFF1F2937);
    final subCol = isDark ? Colors.white60 : const Color(0xFF6B7280);
    const accentFlame = Color(0xFFFF6B35);
    const accentTrophy = Color(0xFFEAB308);
    final primaryCol = theme.colorScheme.primary;

    final todayIndex = DateTime.now().weekday - 1; // 0 = Mon, 6 = Sun

    return Container(
      decoration: BoxDecoration(
        color: bgCol,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Handle Indicator bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentFlame.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_fire_department,
                        color: accentFlame,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Workout Streak Overview',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textCol,
                          ),
                        ),
                        Text(
                          'Tier: ${summary.streakTierName}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: primaryCol,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: subCol),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Dual Cards: Daily Streak vs Weekly Streak
            Row(
              children: [
                // Daily Streak Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: accentFlame.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.local_fire_department, color: accentFlame, size: 20),
                            SizedBox(width: 6),
                            Text(
                              'Daily Streak',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: accentFlame,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${summary.currentDailyStreak} days',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: textCol,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Best: ${summary.bestDailyStreak} days',
                          style: TextStyle(fontSize: 12, color: subCol),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Weekly Streak Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: accentTrophy.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.emoji_events, color: accentTrophy, size: 20),
                            SizedBox(width: 6),
                            Text(
                              'Weekly Streak',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: accentTrophy,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${summary.currentWeeklyStreak} weeks',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: textCol,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Best: ${summary.bestWeeklyStreak} weeks',
                          style: TextStyle(fontSize: 12, color: subCol),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Current Week 7-Day Activity Matrix
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'This Week Activity',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: textCol,
                        ),
                      ),
                      Text(
                        '${summary.weeklyWorkoutCount}/${summary.weeklyGoal} sessions',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: primaryCol,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(7, (index) {
                      final isActive = summary.weekActivityDays[index];
                      final isToday = index == todayIndex;

                      return Column(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive
                                  ? accentFlame
                                  : (isToday
                                      ? primaryCol.withValues(alpha: 0.15)
                                      : Colors.transparent),
                              border: Border.all(
                                color: isActive
                                    ? accentFlame
                                    : (isToday ? primaryCol : subCol.withValues(alpha: 0.3)),
                                width: isToday ? 2 : 1.5,
                              ),
                            ),
                            child: Center(
                              child: isActive
                                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                                  : (isToday
                                      ? Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: primaryCol,
                                            shape: BoxShape.circle,
                                          ),
                                        )
                                      : null),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            dayLabels[index],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              color: isToday ? primaryCol : subCol,
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Scientific Guidelines & Motivation Tips
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryCol.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: primaryCol.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: primaryCol, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Streak Rules & Science',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: primaryCol,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Daily Streak: Log at least 1 workout per day. You have a 24h grace window until midnight to maintain your streak!\n'
                    '• Weekly Streak: Reach your target of ${summary.weeklyGoal} sessions/week to build consecutive active week streaks.\n'
                    '• Scientific Insight: Consistent training triggers long-term muscular adaptations and builds sustainable habits.',
                    style: TextStyle(fontSize: 13, height: 1.4, color: textCol),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onSetGoalPressed();
                    },
                    icon: const Icon(Icons.tune),
                    label: const Text('Edit Weekly Goal'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: primaryCol),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryCol,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Got It',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
