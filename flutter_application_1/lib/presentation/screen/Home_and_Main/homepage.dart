import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:drift/drift.dart' as drift;
import 'package:aegymer/core/databases/app_database.dart';
import 'package:aegymer/core/services/streak_service.dart';
import 'package:aegymer/presentation/recent_session_popup.dart';
import 'package:aegymer/presentation/widgets/streak_detail_sheet.dart';
import 'package:aegymer/presentation/screen/workout_progress_screen.dart';
import 'package:aegymer/presentation/screen/workout_history_screen.dart';
import 'package:aegymer/presentation/screen/edit_workout_session_screen.dart';
import 'package:aegymer/presentation/screen/active_workout_screen.dart';
import 'package:aegymer/core/services/workout_draft_service.dart';

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

  Map<String, dynamic>? _activeDraft;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    StreakService.workoutUpdateNotifier.addListener(_onWorkoutUpdated);
  }

  void _onWorkoutUpdated() {
    if (mounted) {
      _loadAllData();
    }
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() {
      _loadingSessions = true;
      _loadingStreak = true;
    });

    final draft = await WorkoutDraftService.getDraft();

    await Future.wait([
      _loadRecentSessions(),
      _loadStreakData(),
    ]);

    if (mounted) {
      setState(() {
        _activeDraft = draft;
      });
    }
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

  Future<void> _openEditSession(WorkoutSession session) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (ctx) => EditWorkoutSessionScreen(
          db: widget.db,
          session: session,
        ),
      ),
    );
    if (updated == true && mounted) {
      _loadAllData();
    }
  }

  Future<void> _confirmDeleteSession(WorkoutSession session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Workout?'),
        content: const Text(
          'Are you sure you want to delete this workout session? All logged sets will be removed and streaks will be updated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await widget.db.deleteWorkoutSession(session.id);
      StreakService.notifyWorkoutUpdated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workout session deleted.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _resumeActiveDraft() async {
    if (_activeDraft == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveWorkoutScreen(
          db: widget.db,
          restoredDraft: _activeDraft,
        ),
      ),
    );
    await _loadAllData();
  }

  Future<void> _finishAndSaveDraftDirectly() async {
    if (_activeDraft == null) return;
    final success = await WorkoutDraftService.finishAndSaveDraft(widget.db, _activeDraft!);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unfinished workout saved to history successfully.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _loadAllData();
    }
  }

  Future<void> _confirmDiscardDraft() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Discard Unfinished Workout?'),
        content: const Text(
          'Are you sure you want to discard this workout? All sets and progress logged during this session will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await WorkoutDraftService.clearDraft();
      setState(() {
        _activeDraft = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Workout draft discarded.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
    StreakService.workoutUpdateNotifier.removeListener(_onWorkoutUpdated);
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
      backgroundColor: bgCol,
      
      body: RefreshIndicator(
        onRefresh: _refreshPage,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24, top: 12),
          children: [
            if (_activeDraft != null) ...[
              _buildActiveDraftBanner(cardBg, txtCol, subTxtCol, isDark),
              const SizedBox(height: 16),
            ],
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
            const SizedBox(height: 20),

            _buildProgressCard(cardBg, txtCol, subTxtCol),

            const SizedBox(height: 24),

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
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => WorkoutHistoryScreen(db: widget.db),
                                ),
                              );
                            },
                            child: const Text(
                              'View All',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          GestureDetector(
                            onTap: widget.onRecordWorkout,
                            child: const Text(
                              'Start',
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
                                db: widget.db,
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

  Widget _buildActiveDraftBanner(Color cardBg, Color txtCol, Color subTxtCol, bool isDark) {
    final draft = _activeDraft!;
    final routineName = draft['routineName']?.toString() ?? 'Free Workout';
    final rawExercises = draft['exercises'] as List<dynamic>? ?? [];
    final setsData = draft['setsData'] as Map<String, dynamic>? ?? {};

    int totalSets = 0;
    for (final sets in setsData.values) {
      if (sets is List) totalSets += sets.length;
    }

    final bannerBg = isDark ? const Color(0xFF2D1B00) : const Color(0xFFFFF7ED);
    final bannerBorder = isDark ? Colors.amber.shade800.withValues(alpha: 0.5) : const Color(0xFFFFEDD5);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bannerBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.bolt_rounded, color: Colors.amber.shade700, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Unfinished Workout Session',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.amber.shade200 : const Color(0xFF9A3412),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$routineName • ${rawExercises.length} exercises, $totalSets sets logged',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white70 : const Color(0xFFC2410C),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close_rounded, size: 18, color: subTxtCol),
                tooltip: 'Discard draft',
                onPressed: _confirmDiscardDraft,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _finishAndSaveDraftDirectly,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.amber.shade300 : const Color(0xFFC2410C),
                    side: BorderSide(
                      color: isDark ? Colors.amber.shade700 : const Color(0xFFFDBA74),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Save to History',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _resumeActiveDraft,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text(
                    'Resume',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Text(
                            'Daily Streak',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: txtCol,
                            ),
                          ),
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
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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
                Expanded(
                  child: Column(
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
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

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
                Expanded(
                  child: Column(
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
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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
                  borderRadius: BorderRadius.circular(6),
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
                onPressed: widget.onRecordWorkout,
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
                Expanded(
                  child: Column(
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
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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
                    label: 'Burned',
                    value: '${summary.totalCalories} kcal',
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
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: subTxtCol.withValues(alpha: 0.7),
                    size: 20,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onSelected: (action) {
                    if (action == 'view') {
                      showDialog(
                        context: context,
                        builder: (context) => RecentSessionPopup(
                          session: session,
                          db: widget.db,
                        ),
                      );
                    } else if (action == 'edit') {
                      _openEditSession(session);
                    } else if (action == 'delete') {
                      _confirmDeleteSession(session);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('View Details'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
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

  Widget _buildProgressCard(Color cardBg, Color txtCol, Color subTxtCol) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Card(
        color: cardBg,
        elevation: 0.5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WorkoutProgressScreen(db: widget.db),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.show_chart, color: theme.colorScheme.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Workout Progress Analytics',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: txtCol,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Track your 1RM gains & volume progress over time',
                        style: TextStyle(fontSize: 12, color: subTxtCol),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: subTxtCol),
              ],
            ),
          ),
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
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: txtCol,
            ),
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