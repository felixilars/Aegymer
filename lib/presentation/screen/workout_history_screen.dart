import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:aegymer/core/databases/app_database.dart';
import 'package:aegymer/core/services/streak_service.dart';
import 'package:aegymer/core/utils/workout_cal.dart';
import 'package:aegymer/core/utils/workout_session_helper.dart';
import 'package:aegymer/presentation/recent_session_popup.dart';
import 'package:aegymer/presentation/screen/edit_workout_session_screen.dart';
import 'package:aegymer/core/utils/set_metrics.dart';

class _SessionSummaryItem {
  final WorkoutSession session;
  final String workoutName;
  final List<String> exerciseNames;
  final int totalSets;
  final double totalVolume;
  final double totalCalories;

  _SessionSummaryItem({
    required this.session,
    required this.workoutName,
    required this.exerciseNames,
    required this.totalSets,
    required this.totalVolume,
    required this.totalCalories,
  });
}

class WorkoutHistoryScreen extends StatefulWidget {
  final AppDatabase db;

  const WorkoutHistoryScreen({super.key, required this.db});

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  List<_SessionSummaryItem> _allSessions = [];
  bool _loading = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
    StreakService.workoutUpdateNotifier.addListener(_onWorkoutUpdated);
  }

  @override
  void dispose() {
    StreakService.workoutUpdateNotifier.removeListener(_onWorkoutUpdated);
    _searchController.dispose();
    super.dispose();
  }

  void _onWorkoutUpdated() {
    if (mounted) {
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
    });

    final profile = await (widget.db.select(widget.db.userProfiles)..limit(1)).getSingleOrNull();
    final userWeight = (profile?.weight != null && profile!.weight > 0) ? profile.weight : 70.0;

    final sessions = await (widget.db.select(widget.db.workoutSessions)
      ..orderBy([
        (t) => drift.OrderingTerm(expression: t.date, mode: drift.OrderingMode.desc),
      ]))
      .get();

    if (sessions.isEmpty) {
      if (!mounted) return;
      setState(() {
        _allSessions = [];
        _loading = false;
      });
      return;
    }

    final cachedRoutines = await widget.db.getRoutinesWithExercises();
    final sessionIds = sessions.map((s) => s.id).toList();

    // 1 single batch query for all sets and exercises across all sessions
    final allRows = await (widget.db.select(widget.db.workoutSets).join([
      drift.innerJoin(
        widget.db.exercises,
        widget.db.exercises.id.equalsExp(widget.db.workoutSets.exerciseId),
      ),
    ])
      ..where(widget.db.workoutSets.sessionId.isIn(sessionIds))
      ..orderBy([drift.OrderingTerm.asc(widget.db.workoutSets.setNumber)]))
      .get();

    final Map<String, List<drift.TypedResult>> rowsBySession = {};
    for (final row in allRows) {
      final s = row.readTable(widget.db.workoutSets);
      rowsBySession.putIfAbsent(s.sessionId, () => []).add(row);
    }

    final List<_SessionSummaryItem> items = [];

    for (int i = 0; i < sessions.length; i++) {
      final session = sessions[i];
      final rows = rowsBySession[session.id] ?? const [];

      final exNames = <String>[];
      final exIds = <String>[];
      int setsCount = 0;
      double volume = 0.0;
      double calories = 0.0;

      for (final row in rows) {
        final s = row.readTable(widget.db.workoutSets);
        final ex = row.readTable(widget.db.exercises);

        if (!exNames.contains(ex.name)) {
          exNames.add(ex.name);
          exIds.add(ex.id);
        }
        setsCount++;
        volume += (s.loadKg * s.reps);

        final trackingType = WorkoutCalculator.normalizeTrackingType(
          s.weightType,
          name: ex.name,
          targetMuscle: ex.targetMuscle,
          equipment: ex.equipment,
        );

        calories += s.calories ?? WorkoutCalculator.calculateSetCalories(
          exerciseName: ex.name,
          targetMuscle: ex.targetMuscle,
          equipment: ex.equipment,
          trackingType: trackingType,
          bodyweightKg: userWeight,
          weight: s.weight,
          reps: s.reps,
          distanceKm: s.distance ?? 0.0,
          durationSeconds: s.durationSeconds ?? 90,
        );
      }

      final workoutName = await WorkoutSessionHelper.resolveSessionName(
        session: session,
        db: widget.db,
        index: i,
        cachedRoutines: cachedRoutines,
        sessionExerciseIds: exIds,
      );

      items.add(
        _SessionSummaryItem(
          session: session,
          workoutName: workoutName,
          exerciseNames: exNames,
          totalSets: setsCount,
          totalVolume: volume,
          totalCalories: calories,
        ),
      );
    }

    if (!mounted) return;

    setState(() {
      _allSessions = items;
      _loading = false;
    });
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final monthName = months[local.month - 1];
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    final minuteStr = local.minute.toString().padLeft(2, '0');
    return '$monthName ${local.day}, ${local.year} • $hour:$minuteStr $ampm';
  }

  Future<void> _openSessionDetails(WorkoutSession session) async {
    await showDialog(
      context: context,
      builder: (context) => RecentSessionPopup(
        session: session,
        db: widget.db,
      ),
    );
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
      _loadHistory();
    }
  }

  Future<void> _deleteSession(WorkoutSession session) async {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final txtPrimary = isDark ? Colors.white : const Color(0xFF1F2937);
    final txtSecondary = isDark ? Colors.white60 : const Color(0xFF64748B);

    final filtered = _allSessions.where((item) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final hasName = item.workoutName.toLowerCase().contains(q);
      final hasEx = item.exerciseNames.any((name) => name.toLowerCase().contains(q));
      final hasNotes = item.session.notes?.toLowerCase().contains(q) ?? false;
      return hasName || hasEx || hasNotes;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Workout History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_allSessions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Center(
                child: Text(
                  '${_allSessions.length} total',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: txtSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: Column(
                children: [
                  if (_allSessions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by exercise or notes...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          isDense: true,
                          filled: true,
                          fillColor: cardBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim();
                          });
                        },
                      ),
                    ),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.fitness_center_outlined,
                                    size: 56,
                                    color: txtSecondary.withValues(alpha: 0.4),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No workouts match "$_searchQuery"'
                                        : 'No workout history recorded yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: txtSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: filtered.length,
                            itemBuilder: (context, idx) {
                              final item = filtered[idx];
                              return _buildHistoryCard(
                                item: item,
                                index: idx,
                                theme: theme,
                                cardBg: cardBg,
                                borderColor: borderColor,
                                txtPrimary: txtPrimary,
                                txtSecondary: txtSecondary,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHistoryCard({
    required _SessionSummaryItem item,
    required int index,
    required ThemeData theme,
    required Color cardBg,
    required Color borderColor,
    required Color txtPrimary,
    required Color txtSecondary,
  }) {
    return Card(
      color: cardBg,
      elevation: 1.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        onTap: () => _openSessionDetails(item.session),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Icon + Date + More options
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.fitness_center_rounded,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.workoutName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: txtPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(item.session.date),
                          style: TextStyle(
                            fontSize: 12,
                            color: txtSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.exerciseNames.isNotEmpty
                              ? item.exerciseNames.join(', ')
                              : 'No exercises recorded',
                          style: TextStyle(
                            fontSize: 12,
                            color: txtSecondary.withValues(alpha: 0.85),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, size: 20, color: txtSecondary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onSelected: (action) {
                      if (action == 'view') {
                        _openSessionDetails(item.session);
                      } else if (action == 'edit') {
                        _openEditSession(item.session);
                      } else if (action == 'delete') {
                        _deleteSession(item.session);
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

              const SizedBox(height: 12),

              // Summary Pills: Sets, Volume, Calories
              Row(
                children: [
                  _buildSummaryPill(
                    icon: Icons.format_list_numbered_rounded,
                    iconColor: Colors.green,
                    text: '${item.totalSets} sets',
                    theme: theme,
                  ),
                  const SizedBox(width: 8),
                  _buildSummaryPill(
                    icon: Icons.fitness_center_rounded,
                    iconColor: theme.colorScheme.primary,
                    text: item.totalVolume >= 1000
                        ? '${(item.totalVolume / 1000).toStringAsFixed(1)}k kg'
                        : '${item.totalVolume.toStringAsFixed(0)} kg',
                    theme: theme,
                  ),
                  const SizedBox(width: 8),
                  _buildSummaryPill(
                    icon: Icons.local_fire_department_rounded,
                    iconColor: Colors.orange,
                    text: WorkoutCalculator.formatCalories(item.totalCalories),
                    theme: theme,
                  ),
                ],
              ),

              Builder(
                builder: (context) {
                  final cleanNotes = WorkoutSessionHelper.cleanNotes(item.session.notes);
                  if (cleanNotes.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        cleanNotes,
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: txtSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryPill({
    required IconData icon,
    required Color iconColor,
    required String text,
    required ThemeData theme,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF2F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
