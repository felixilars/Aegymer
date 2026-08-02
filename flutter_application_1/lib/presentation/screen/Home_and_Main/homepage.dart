import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_application_1/core/databases/app_database.dart';
import 'package:flutter_application_1/core/services/streak_service.dart';
import 'package:flutter_application_1/presentation/recent_session_popup.dart';
import 'package:flutter_application_1/presentation/screen/workout_launcher_screen.dart';
import 'package:flutter_application_1/presentation/widgets/streak_detail_sheet.dart';
// Color Palette
const backgroundColor = Color(0xffF5F7FA);
const cardColor = Colors.white;
const primaryColor = Color(0xff2563EB);
const accentColor = Color(0xffFF6B35);
const textColor = Color(0xff1F2937);
const subtitleColor = Color(0xff6B7280);

class Homepage extends StatefulWidget {
  final AppDatabase db;
  final VoidCallback onRecordWorkout;

  const Homepage({
    super.key,
    required this.db,
    required this.onRecordWorkout,
  });

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  final PageController _controller = PageController();
  List<WorkoutSession> _recentSessions = [];
  bool _loadingSessions = true;

  StreakSummary? _streakSummary;
  bool _loadingStreak = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() {
      _loadingSessions = true;
      _loadingStreak = true;
    });

    await Future.wait([
      _loadRecentSessions(),
      _loadStreakData(),
    ]);
  }

  Future<void> _refreshPage() async {
    await _loadAllData();
  }

  Future<void> _loadRecentSessions() async {
    final query = widget.db.select(widget.db.workoutSessions)
      ..orderBy([
        (t) => drift.OrderingTerm(expression: t.date, mode: drift.OrderingMode.desc),
      ])
      ..limit(3);

    final sessions = await query.get();
    if (!mounted) return;

    setState(() {
      _recentSessions = sessions;
      _loadingSessions = false;
    });
  }

  Future<void> _loadStreakData() async {
    final summary = await StreakService.loadStreakSummary(widget.db);
    if (!mounted) return;

    setState(() {
      _streakSummary = summary;
      _loadingStreak = false;
    });
  }

  Future<void> _showSetGoalDialog() async {
    final currentGoal = _streakSummary?.weeklyGoal ?? 4;
    final controller = TextEditingController(text: currentGoal.toString());

    final newGoal = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.tune, color: primaryColor),
            SizedBox(width: 8),
            Text('Set Weekly Goal'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Target workout sessions per week (1 - 7 sessions):',
              style: TextStyle(fontSize: 14, color: textColor),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Sessions / week',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixText: 'sessions',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null && val >= 1 && val <= 7) {
                Navigator.pop(context, val);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a number between 1 and 7'),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newGoal != null) {
      await StreakService.setWeeklyGoal(newGoal);
      await _loadStreakData();
    }
  }

  void _openStreakDetailSheet() {
    if (_streakSummary == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StreakDetailSheet(
        summary: _streakSummary!,
        onSetGoalPressed: _showSetGoalDialog,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgCol = isDark ? theme.scaffoldBackgroundColor : backgroundColor;
    final cardBg = isDark ? theme.cardColor : cardColor;
    final txtCol = isDark ? Colors.white : textColor;
    final subTxtCol = isDark ? Colors.white60 : subtitleColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      
      body: RefreshIndicator(
        onRefresh: _refreshPage,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24, top: 12),
          children: [
            // Top Swipeable Cards: Streak Card, Weekly Goal Card, Summary Card
            SizedBox(
              height: 235,
              child: PageView(
                controller: _controller,
                children: [
                  _buildStreakCard(cardBg, txtCol, subTxtCol),
                  _buildGoalCard(cardBg, txtCol, subTxtCol),
                  _buildWeeklySummaryCard(cardBg, txtCol, subTxtCol),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: SmoothPageIndicator(
                controller: _controller,
                count: 3,
                effect: ScrollingDotsEffect(
                  activeDotColor: primaryColor,
                  dotColor: isDark ? Colors.white24 : const Color(0xffD1D5DB),
                  dotHeight: 8,
                  dotWidth: 8,
                  spacing: 8,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Recent Sessions Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Sessions',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: txtCol,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          // Navigate to workout launcher
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WorkoutLauncherScreen(db: widget.db),
                            ),
                          ).then((_) => _loadAllData());
                        },
                        child: const Text(
                          'Start Workout',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_loadingSessions)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_recentSessions.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'No sessions logged yet',
                          style: TextStyle(color: subTxtCol),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _recentSessions.length,
                      itemBuilder: (context, index) {
                        final session = _recentSessions[index];
                        return GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => RecentSessionPopup(
                                session: session,
                              ),
                            );
                          },
                          child: _buildSessionCard(
                            session: session,
                            index: index,
                            cardBg: cardBg,
                            txtCol: txtCol,
                            subTxtCol: subTxtCol,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- CARD 1: DAILY STREAK CARD ---
  Widget _buildStreakCard(Color cardBg, Color txtCol, Color subTxtCol) {
    if (_loadingStreak || _streakSummary == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final summary = _streakSummary!;
    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final todayIndex = DateTime.now().weekday - 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Title Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Daily Streak',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: txtCol,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            summary.streakTierName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Best: ${summary.bestDailyStreak} days streak',
                      style: TextStyle(fontSize: 12, color: subTxtCol),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _openStreakDetailSheet,
                  child: const Text(
                    'Details',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Fire Icon & Count Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.local_fire_department,
                    color: accentColor,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${summary.currentDailyStreak} Days',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: txtCol,
                      ),
                    ),
                    Text(
                      summary.currentDailyStreak > 0
                          ? 'Keep the momentum going!'
                          : 'Start a workout to ignite!',
                      style: TextStyle(fontSize: 12, color: subTxtCol),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 7-Day Activity Matrix Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (index) {
                final isActive = summary.weekActivityDays[index];
                final isToday = index == todayIndex;

                return Column(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? accentColor
                            : (isToday ? primaryColor.withValues(alpha: 0.15) : Colors.transparent),
                        border: Border.all(
                          color: isActive
                              ? accentColor
                              : (isToday ? primaryColor : subTxtCol.withValues(alpha: 0.3)),
                          width: isToday ? 2 : 1,
                        ),
                      ),
                      child: Center(
                        child: isActive
                            ? const Icon(Icons.check, color: Colors.white, size: 14)
                            : (isToday
                                ? Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                : null),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dayLabels[index],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday ? primaryColor : subTxtCol,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // --- CARD 2: WEEKLY GOAL CARD ---
  Widget _buildGoalCard(Color cardBg, Color txtCol, Color subTxtCol) {
    if (_loadingStreak || _streakSummary == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final summary = _streakSummary!;
    final double completionRate = summary.weeklyGoal > 0
        ? (summary.weeklyWorkoutCount / summary.weeklyGoal).clamp(0.0, 1.0)
        : 0.0;
    final int percent = (completionRate * 100).toInt();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly Goal',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: txtCol,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Weekly streak: ${summary.currentWeeklyStreak} consecutive weeks 🏆',
                      style: TextStyle(fontSize: 12, color: subTxtCol),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _showSetGoalDialog,
                  child: const Text(
                    'Customize',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${summary.weeklyWorkoutCount} / ${summary.weeklyGoal} workouts',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: txtCol,
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: completionRate,
                    minHeight: 10,
                    backgroundColor: const Color(0xffE5E7EB),
                    valueColor: const AlwaysStoppedAnimation(primaryColor),
                  ),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkoutLauncherScreen(db: widget.db),
                    ),
                  ).then((_) => _loadAllData());
                },
                icon: const Icon(Icons.play_arrow, size: 20),
                label: const Text('Start Workout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- CARD 3: WEEKLY SUMMARY CARD ---
  Widget _buildWeeklySummaryCard(Color cardBg, Color txtCol, Color subTxtCol) {
    if (_loadingStreak || _streakSummary == null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final summary = _streakSummary!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: txtCol,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '7-day overall statistics',
                      style: TextStyle(fontSize: 12, color: subTxtCol),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _openStreakDetailSheet,
                  child: const Text(
                    'Details',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _SummaryItem(
                    icon: Icons.repeat,
                    label: 'Sessions',
                    value: summary.totalSessions,
                    txtCol: txtCol,
                    subTxtCol: subTxtCol,
                  ),
                  _SummaryItem(
                    icon: Icons.local_fire_department,
                    label: 'Calories',
                    value: summary.totalCalories,
                    txtCol: txtCol,
                    subTxtCol: subTxtCol,
                  ),
                  _SummaryItem(
                    icon: Icons.schedule,
                    label: 'Time',
                    value: summary.totalTimeFormatted,
                    txtCol: txtCol,
                    subTxtCol: subTxtCol,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard({
    required WorkoutSession session,
    required int index,
    required Color cardBg,
    required Color txtCol,
    required Color subTxtCol,
  }) {
    final formattedDate = session.date.toLocal().toString().split('.').first;

    return Card(
      color: cardBg,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.fitness_center,
                    color: primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Workout #${index + 1}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: txtCol,
                        ),
                      ),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          fontSize: 13,
                          color: subTxtCol,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (session.notes != null && session.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                session.notes!,
                style: TextStyle(
                  fontSize: 14,
                  color: txtCol,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color txtCol;
  final Color subTxtCol;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.txtCol,
    required this.subTxtCol,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: primaryColor, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: txtCol,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: subTxtCol,
          ),
        ),
      ],
    );
  }
}