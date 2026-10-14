import 'dart:math';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:aegymer/models/exercises_with_sets.dart';
import 'package:aegymer/core/databases/app_database.dart';
import 'package:aegymer/core/utils/workout_cal.dart';

class RecentSessionPopup extends StatefulWidget {
  final WorkoutSession session;
  final AppDatabase db;

  const RecentSessionPopup({
    super.key,
    required this.session,
    required this.db,
  });

  @override
  State<RecentSessionPopup> createState() => _RecentSessionPopupState();
}

class _RecentSessionPopupState extends State<RecentSessionPopup> {
  List<ExerciseWithSets> _exerciseGroups = [];
  double _userWeight = 70.0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkoutSets();
  }

  Future<void> _loadWorkoutSets() async {
    final profile = await (widget.db.select(widget.db.userProfiles)..limit(1)).getSingleOrNull();
    final profileWeight = profile?.weight ?? 70.0;

    final sets = await (widget.db.select(widget.db.workoutSets).join([
      drift.innerJoin(
        widget.db.exercises,
        widget.db.exercises.id.equalsExp(widget.db.workoutSets.exerciseId),
      ),
    ])
      ..where(
        widget.db.workoutSets.sessionId.equals(widget.session.id),
      )
      ..orderBy([
        drift.OrderingTerm.asc(widget.db.workoutSets.setNumber),
      ]))
    .get();

    if (!mounted) return;

    final map = <String, ExerciseWithSets>{};

    for (final row in sets) {
      final set = row.readTable(widget.db.workoutSets);
      final exercise = row.readTable(widget.db.exercises);

      map.putIfAbsent(
        exercise.id,
        () => ExerciseWithSets(
          exercise: exercise,
          sets: [],
        ),
      );

      map[exercise.id]!.sets.add(set);
    }

    setState(() {
      _userWeight = profileWeight > 0 ? profileWeight : 70.0;
      _exerciseGroups = map.values.toList();
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

  String _formatNum(double val) {
    if (val % 1 == 0) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(1);
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '--:--';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  double _calculateSetCalories(Exercise ex, WorkoutSet s) {
    final trackingType = s.weightType != null && s.weightType!.isNotEmpty
        ? WorkoutCalculator.normalizeTrackingType(
            s.weightType,
            name: ex.name,
            targetMuscle: ex.targetMuscle,
            equipment: ex.equipment,
          )
        : WorkoutCalculator.normalizeTrackingType(
            ex.trackingType,
            name: ex.name,
            targetMuscle: ex.targetMuscle,
            equipment: ex.equipment,
          );

    return WorkoutCalculator.calculateSetCalories(
      exerciseName: ex.name,
      targetMuscle: ex.targetMuscle,
      equipment: ex.equipment,
      trackingType: trackingType,
      bodyweightKg: _userWeight,
      weight: s.weight,
      reps: s.reps,
      distanceKm: s.distance ?? 0.0,
      durationSeconds: s.durationSeconds ?? 90,
    );
  }

  double get _totalSessionCalories {
    double total = 0.0;
    for (final group in _exerciseGroups) {
      for (final s in group.sets) {
        total += _calculateSetCalories(group.exercise, s);
      }
    }
    return total;
  }

  double get _totalSessionVolume {
    double total = 0.0;
    for (final group in _exerciseGroups) {
      for (final s in group.sets) {
        total += (s.weight * s.reps);
      }
    }
    return total;
  }

  int get _totalSetsCount {
    int total = 0;
    for (final group in _exerciseGroups) {
      total += group.sets.length;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final txtPrimary = isDark ? Colors.white : const Color(0xFF1F2937);
    final txtSecondary = isDark ? Colors.white60 : const Color(0xFF64748B);

    final totalCal = _totalSessionCalories;
    final totalVol = _totalSessionVolume;
    final totalSets = _totalSetsCount;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                        'Workout Details',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(widget.session.date),
                        style: TextStyle(
                          fontSize: 13,
                          color: txtSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (!_loading && _exerciseGroups.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF2F6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildMetricItem(
                        icon: Icons.local_fire_department,
                        iconColor: Colors.orange,
                        label: 'Burned',
                        value: WorkoutCalculator.formatCalories(totalCal),
                        txtPrimary: txtPrimary,
                        txtSecondary: txtSecondary,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: borderColor,
                    ),
                    Expanded(
                      child: _buildMetricItem(
                        icon: Icons.fitness_center,
                        iconColor: theme.colorScheme.primary,
                        label: 'Volume',
                        value: totalVol >= 1000
                            ? '${(totalVol / 1000).toStringAsFixed(1)}k kg'
                            : '${totalVol.toStringAsFixed(0)} kg',
                        txtPrimary: txtPrimary,
                        txtSecondary: txtSecondary,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: borderColor,
                    ),
                    Expanded(
                      child: _buildMetricItem(
                        icon: Icons.format_list_numbered_rounded,
                        iconColor: Colors.green,
                        label: 'Total Sets',
                        value: '$totalSets sets',
                        txtPrimary: txtPrimary,
                        txtSecondary: txtSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_exerciseGroups.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40.0),
                child: Center(
                  child: Text(
                    'No exercises recorded for this session',
                    style: TextStyle(color: txtSecondary),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _exerciseGroups.length,
                  itemBuilder: (context, index) {
                    final exerciseWithSets = _exerciseGroups[index];
                    final ex = exerciseWithSets.exercise;
                    final sets = exerciseWithSets.sets;

                    final isCardio = WorkoutCalculator.normalizeTrackingType(
                          ex.trackingType,
                          name: ex.name,
                          targetMuscle: ex.targetMuscle,
                          equipment: ex.equipment,
                        ) ==
                        'cardio_time';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    ex.name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: txtPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (ex.targetMuscle.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      ex.targetMuscle,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 10),

                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: borderColor, width: 0.8),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _buildHeaderCell('Set', flex: 2, color: txtSecondary),
                                  _buildHeaderCell(isCardio ? 'Distance' : 'Weight', flex: 4, color: txtSecondary),
                                  _buildHeaderCell(isCardio ? 'Time' : 'Reps', flex: 4, color: txtSecondary),
                                  _buildHeaderCell('Calories', flex: 4, color: txtSecondary),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),

                            ...sets.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final set = entry.value;
                              final setCal = _calculateSetCalories(ex, set);

                              String weightText;
                              if (isCardio) {
                                final dist = set.distance ?? 0.0;
                                weightText = dist > 0 ? '${dist.toStringAsFixed(2)} km' : '--';
                              } else {
                                final isBw = set.weightType == 'bodyweight' ||
                                    (set.weightType == null &&
                                        (ex.equipment.toLowerCase() == 'bodyweight' ||
                                            ex.trackingType?.contains('bodyweight') == true));
                                if (isBw) {
                                  if (set.weight > 0) {
                                    weightText = '+${_formatNum(set.weight)} kg';
                                  } else {
                                    weightText = 'BW';
                                  }
                                } else if (set.weightType == 'assisted') {
                                  weightText = '-${_formatNum(set.weight)} kg';
                                } else {
                                  weightText = '${_formatNum(set.weight)} kg';
                                }
                              }

                              String repsText;
                              if (isCardio) {
                                repsText = _formatDuration(set.durationSeconds ?? 0);
                              } else if (ex.trackingType == 'time_only') {
                                repsText = '${set.durationSeconds ?? set.reps}s';
                              } else {
                                repsText = '${set.reps} reps';
                              }

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Center(
                                        child: Text(
                                          '${idx + 1}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: txtPrimary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 4,
                                      child: Center(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            weightText,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: txtPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 4,
                                      child: Center(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            repsText,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: txtPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 4,
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              WorkoutCalculator.formatCalories(setCal),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            if (_exerciseGroups.isNotEmpty && widget.session.notes != null && widget.session.notes!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notes',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: txtPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.session.notes ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: txtSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color txtPrimary,
    required Color txtSecondary,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: txtSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: txtPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCell(String text, {required int flex, required Color color}) {
    return Expanded(
      flex: flex,
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}
