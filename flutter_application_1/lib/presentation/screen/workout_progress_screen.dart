import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:aegymer/core/databases/app_database.dart';
import 'package:aegymer/core/utils/workout_cal.dart';
import 'package:aegymer/core/services/streak_service.dart';

class WorkoutProgressScreen extends StatefulWidget {
  final AppDatabase db;

  const WorkoutProgressScreen({super.key, required this.db});

  @override
  State<WorkoutProgressScreen> createState() => _WorkoutProgressScreenState();
}

class _WorkoutProgressScreenState extends State<WorkoutProgressScreen> {
  bool _isLoading = true;
  List<Exercise> _exercises = [];
  Exercise? _selectedExercise;

  String _viewMode = 'Exercise';
  String _dateRange = 'All Time';

  Set<String> _muscleGroups = {};
  String? _selectedMuscleGroup;

  List<Map<String, dynamic>> _chartData = [];
  List<_PrRecord> _prRecords = [];

  @override
  void initState() {
    super.initState();
    _loadExercises();
    StreakService.workoutUpdateNotifier.addListener(_onWorkoutUpdated);
  }

  @override
  void dispose() {
    StreakService.workoutUpdateNotifier.removeListener(_onWorkoutUpdated);
    super.dispose();
  }

  void _onWorkoutUpdated() {
    if (mounted) {
      _loadExercises();
    }
  }

  Future<void> _loadExercises() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final doneExerciseIdsQuery = widget.db.selectOnly(widget.db.workoutSets, distinct: true)
        ..addColumns([widget.db.workoutSets.exerciseId]);
      final doneExerciseIdsRows = await doneExerciseIdsQuery.get();
      final doneExerciseIds = doneExerciseIdsRows
          .map((row) => row.read(widget.db.workoutSets.exerciseId))
          .whereType<String>()
          .toSet();

      final allExercises = await widget.db.select(widget.db.exercises).get();
      final list = allExercises.where((ex) => doneExerciseIds.contains(ex.id)).toList();

      list.sort((a, b) => a.name.compareTo(b.name));

      final allSets = await widget.db.select(widget.db.workoutSets).get();
      final allSessions = await widget.db.select(widget.db.workoutSessions).get();

      double maxE1rm = 0.0;
      String maxE1rmExName = 'Top Lift';

      for (var set in allSets) {
        double currentE1RM = set.calculated1rm ?? WorkoutCalculator.calculateE1RM(set.weight, set.reps);
        if (currentE1RM > maxE1rm) {
          maxE1rm = currentE1RM;
          final matchEx = list.firstWhere((e) => e.id == set.exerciseId, orElse: () => list.isNotEmpty ? list.first : allExercises.first);
          maxE1rmExName = matchEx.name;
        }
      }

      final List<_PrRecord> records = [];
      if (maxE1rm > 0) {
        records.add(
          _PrRecord(
            title: maxE1rmExName,
            value: '${maxE1rm.round()} kg 1RM',
            badgeLabel: 'Best Lift',
          ),
        );
      }
      records.addAll([
        _PrRecord(
          title: 'Total Workouts',
          value: '${allSessions.length} Sessions',
          badgeLabel: 'All Time',
        ),
        _PrRecord(
          title: 'Exercises Trained',
          value: '${list.length} Movements',
          badgeLabel: 'Logged',
        ),
      ]);

      final Set<String> musclesSet = {};
      for (var ex in list) {
        final splitMuscles = ex.targetMuscle.split(',');
        for (var m in splitMuscles) {
          final trimmed = m.trim();
          if (trimmed.isNotEmpty) {
            final capitalized = trimmed.isNotEmpty
                ? '${trimmed[0].toUpperCase()}${trimmed.substring(1)}'
                : trimmed;
            musclesSet.add(capitalized);
          }
        }
      }

      final sortedMuscles = musclesSet.toList()..sort();

      setState(() {
        _exercises = list;
        _muscleGroups = sortedMuscles.toSet();
        _prRecords = records;
        if (_exercises.isNotEmpty) {
          _selectedExercise = _exercises.first;
        } else {
          _selectedExercise = null;
        }
        if (_muscleGroups.isNotEmpty) {
          _selectedMuscleGroup = sortedMuscles.first;
        } else {
          _selectedMuscleGroup = null;
        }
      });

      await _loadChartData();
    } catch (e) {
      debugPrint('Error loading exercises for progress chart: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadChartData() async {
    List<Map<String, dynamic>> tempChartData = [];

    double userWeight = 70.0;
    final profile = await (widget.db.select(widget.db.userProfiles)..limit(1)).getSingleOrNull();
    if (profile != null && profile.weight > 0) {
      userWeight = profile.weight;
    }

    if (_viewMode == 'Exercise') {
      if (_selectedExercise == null) return;
      final rawHistory = await widget.db.getRawExerciseHistory(
        _selectedExercise!.id,
      );

      final Map<DateTime, List<WorkoutSet>> grouped = {};
      for (final row in rawHistory) {
        final session = row.readTable(widget.db.workoutSessions);
        final set = row.readTable(widget.db.workoutSets);

        final date = session.date;
        final dateKey = DateTime(date.year, date.month, date.day);
        if (!grouped.containsKey(dateKey)) {
          grouped[dateKey] = [];
        }
        grouped[dateKey]!.add(set);
      }

      final trackingType = WorkoutCalculator.normalizeTrackingType(
        _selectedExercise!.trackingType,
        name: _selectedExercise!.name,
        targetMuscle: _selectedExercise!.targetMuscle,
        equipment: _selectedExercise!.equipment,
      );
      final bool isCardio = trackingType == 'cardio_time';

      final sortedDates = grouped.keys.toList()..sort();
      for (final date in sortedDates) {
        final sets = grouped[date]!;
        if (isCardio) {
          double totalDist = 0.0;
          double totalCal = 0.0;
          for (var set in sets) {
            final dist = set.distance ?? 0.0;
            totalDist += dist;
            totalCal += WorkoutCalculator.calculateSetCalories(
              exerciseName: _selectedExercise!.name,
              targetMuscle: _selectedExercise!.targetMuscle,
              equipment: _selectedExercise!.equipment,
              trackingType: 'cardio_time',
              bodyweightKg: userWeight,
              distanceKm: dist,
              durationSeconds: set.durationSeconds ?? 0,
            );
          }
          tempChartData.add({'date': date, 'e1rm': totalDist, 'volume': totalCal});
        } else {
          final weights = sets.map((s) => s.weight).toList();
          final reps = sets.map((s) => s.reps).toList();
          final double volume = WorkoutCalculator.calculateVolume(weights, reps);

          double maxE1RM = 0.0;
          for (var set in sets) {
            double currentE1RM =
                set.calculated1rm ??
                WorkoutCalculator.calculateE1RM(set.weight, set.reps);
            if (currentE1RM > maxE1RM) {
              maxE1RM = currentE1RM;
            }
          }

          tempChartData.add({'date': date, 'e1rm': maxE1RM, 'volume': volume});
        }
      }
    } else if (_viewMode == 'Muscle') {
      if (_selectedMuscleGroup == null) return;

      final groupExercises = _exercises.where((e) {
        if (_selectedMuscleGroup == null) return false;
        final splitMuscles = e.targetMuscle
            .split(',')
            .map((m) => m.trim().toLowerCase());
        return splitMuscles.contains(_selectedMuscleGroup!.toLowerCase());
      }).toList();
      if (groupExercises.isEmpty) {
        setState(() {
          _chartData = [];
        });
        return;
      }

      final Map<DateTime, List<WorkoutSet>> grouped = {};

      for (final ex in groupExercises) {
        final rawHistory = await widget.db.getRawExerciseHistory(ex.id);
        for (final row in rawHistory) {
          final session = row.readTable(widget.db.workoutSessions);
          final set = row.readTable(widget.db.workoutSets);

          final date = session.date;
          final dateKey = DateTime(date.year, date.month, date.day);
          if (!grouped.containsKey(dateKey)) {
            grouped[dateKey] = [];
          }
          grouped[dateKey]!.add(set);
        }
      }

      final sortedDates = grouped.keys.toList()..sort();
      for (final date in sortedDates) {
        final sets = grouped[date]!;
        final weights = sets.map((s) => s.weight).toList();
        final reps = sets.map((s) => s.reps).toList();
        final double volume = WorkoutCalculator.calculateVolume(weights, reps);

        tempChartData.add({
          'date': date,
          'volume': volume,
          'e1rm': 0.0,
        });
      }
    } else {
      final query = (widget.db.select(widget.db.workoutSets).join([
        innerJoin(
          widget.db.workoutSessions,
          widget.db.workoutSessions.id.equalsExp(
            widget.db.workoutSets.sessionId,
          ),
        ),
      ])..orderBy([OrderingTerm.asc(widget.db.workoutSessions.date)]));

      final rawHistory = await query.get();
      final Map<DateTime, List<WorkoutSet>> grouped = {};

      for (final row in rawHistory) {
        final session = row.readTable(widget.db.workoutSessions);
        final set = row.readTable(widget.db.workoutSets);

        final date = session.date;
        final dateKey = DateTime(date.year, date.month, date.day);
        if (!grouped.containsKey(dateKey)) {
          grouped[dateKey] = [];
        }
        grouped[dateKey]!.add(set);
      }

      final sortedDates = grouped.keys.toList()..sort();
      for (final date in sortedDates) {
        final sets = grouped[date]!;
        final weights = sets.map((s) => s.weight).toList();
        final reps = sets.map((s) => s.reps).toList();
        final double volume = WorkoutCalculator.calculateVolume(weights, reps);

        tempChartData.add({'date': date, 'volume': volume, 'e1rm': 0.0});
      }
    }

    final now = DateTime.now();
    List<Map<String, dynamic>> filtered = tempChartData;
    if (_dateRange == 'Last 7 Days') {
      filtered = tempChartData
          .where((data) => now.difference(data['date'] as DateTime).inDays <= 7)
          .toList();
    } else if (_dateRange == 'Last 30 Days') {
      filtered = tempChartData
          .where(
            (data) => now.difference(data['date'] as DateTime).inDays <= 30,
          )
          .toList();
    }

    setState(() {
      _chartData = filtered;
    });
  }

  Widget _buildLineChart({
    required String title,
    required String yAxisLabel,
    required List<FlSpot> spots,
    required Color lineColor,
    required Color gradientColor,
    required double minY,
    required double maxY,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (spots.length < 2) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.black12.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        ),
        child: Text(
          "At least 2 workouts are required to display the chart.",
          style: TextStyle(
            color: isDark ? Colors.white30 : Colors.black38,
            fontSize: 14,
          ),
        ),
      );
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.fromLTRB(10, 16, 20, 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black12.withValues(alpha: 0.01),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (spots.length - 1).toDouble(),
          minY: max(0.0, minY - (minY * 0.1)),
          maxY: maxY <= minY ? (minY == 0 ? 10.0 : minY * 1.2) : (maxY + (maxY * 0.1)),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(0),
                    style: TextStyle(
                      color: isDark ? Colors.white30 : Colors.black38,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  int step = max(1, (_chartData.length / 5).ceil());
                  if (index >= 0 && index < _chartData.length && (index % step == 0 || index == _chartData.length - 1)) {
                    DateTime date = _chartData[index]['date'] as DateTime;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        "${date.day}/${date.month}",
                        style: TextStyle(
                          color: isDark ? Colors.white30 : Colors.black38,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: lineColor,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) =>
                    FlDotCirclePainter(
                      radius: 4,
                      color: lineColor,
                      strokeWidth: 2,
                      strokeColor: isDark ? Colors.black : Colors.white,
                    ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    gradientColor.withValues(alpha: 0.4),
                    gradientColor.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    List<FlSpot> e1rmSpots = [];
    List<FlSpot> volumeSpots = [];
    double minE1rm = double.maxFinite;
    double maxE1rm = 0.0;
    double minVolume = double.maxFinite;
    double maxVolume = 0.0;

    for (int i = 0; i < _chartData.length; i++) {
      double e1rm = _chartData[i]['e1rm'] as double;
      double volume = _chartData[i]['volume'] as double;

      e1rmSpots.add(FlSpot(i.toDouble(), e1rm));
      volumeSpots.add(FlSpot(i.toDouble(), volume));

      if (e1rm < minE1rm) minE1rm = e1rm;
      if (e1rm > maxE1rm) maxE1rm = e1rm;
      if (volume < minVolume) minVolume = volume;
      if (volume > maxVolume) maxVolume = volume;
    }

    final bool isCardio = _viewMode == 'Exercise' &&
        _selectedExercise != null &&
        (WorkoutCalculator.normalizeTrackingType(
              _selectedExercise!.trackingType,
              name: _selectedExercise!.name,
              targetMuscle: _selectedExercise!.targetMuscle,
              equipment: _selectedExercise!.equipment,
            ) ==
            'cardio_time');

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Progress Chart",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _exercises.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.show_chart,
                      color: isDark ? Colors.white24 : Colors.black26,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "No progress chart available",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Exercise list is empty or no workout data available to display the chart.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PRTrophyShelf(records: _prRecords),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('By Exercise'),
                        selected: _viewMode == 'Exercise',
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _viewMode = 'Exercise';
                              _loadChartData();
                            });
                          }
                        },
                      ),
                      ChoiceChip(
                        label: const Text('By Muscle Group'),
                        selected: _viewMode == 'Muscle',
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _viewMode = 'Muscle';
                              _loadChartData();
                            });
                          }
                        },
                      ),
                      ChoiceChip(
                        label: const Text('By Date'),
                        selected: _viewMode == 'Day',
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _viewMode = 'Day';
                              _loadChartData();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_viewMode != 'Day') ...[
                    Text(
                      _viewMode == 'Exercise' ? "Select Exercise" : "Select Muscle Group",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black12.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: _viewMode == 'Exercise'
                            ? DropdownButton<Exercise>(
                                value: _selectedExercise,
                                dropdownColor: Theme.of(context).cardColor,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontSize: 16,
                                ),
                                icon: Icon(
                                  Icons.keyboard_arrow_down,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                                isExpanded: true,
                                items: _exercises.map((Exercise ex) {
                                  return DropdownMenuItem<Exercise>(
                                    value: ex,
                                    child: Text(
                                      "${ex.name} (${ex.targetMuscle})",
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (Exercise? value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedExercise = value;
                                    });
                                    _loadChartData();
                                  }
                                },
                              )
                            : DropdownButton<String>(
                                value: _selectedMuscleGroup,
                                dropdownColor: Theme.of(context).cardColor,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontSize: 16,
                                ),
                                icon: Icon(
                                  Icons.keyboard_arrow_down,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                                isExpanded: true,
                                items: _muscleGroups.map((String muscle) {
                                  return DropdownMenuItem<String>(
                                    value: muscle,
                                    child: Text(muscle),
                                  );
                                }).toList(),
                                onChanged: (String? value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedMuscleGroup = value;
                                    });
                                    _loadChartData();
                                  }
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            color: isDark ? Colors.white70 : Colors.black54,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Time Range",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black12.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.black12,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _dateRange,
                            dropdownColor: Theme.of(context).cardColor,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: isDark ? Colors.white70 : Colors.black54,
                              size: 18,
                            ),
                            isDense: true,
                            items: const [
                              DropdownMenuItem(
                                value: 'Last 7 Days',
                                child: Text('7 Days'),
                              ),
                              DropdownMenuItem(
                                value: 'Last 30 Days',
                                child: Text('30 Days'),
                              ),
                              DropdownMenuItem(
                                value: 'All Time',
                                child: Text('All'),
                              ),
                            ],
                            onChanged: (String? value) {
                              if (value != null) {
                                setState(() {
                                  _dateRange = value;
                                });
                                _loadChartData();
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  if (_viewMode == 'Exercise') ...[
                    Row(
                      children: [
                        Icon(
                          isCardio ? Icons.directions_run : Icons.fitness_center,
                          color: isCardio ? Colors.blueAccent : Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isCardio ? "Total Distance (km)" : "Estimated 1 Rep Max (E1RM)",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildLineChart(
                      title: isCardio ? "Distance (km)" : "Estimated 1RM (kg)",
                      yAxisLabel: isCardio ? "km" : "kg",
                      spots: e1rmSpots,
                      lineColor: isCardio ? Colors.blueAccent : Theme.of(context).colorScheme.primary,
                      gradientColor: isCardio ? Colors.blueAccent : Theme.of(context).colorScheme.primary,
                      minY: minE1rm,
                      maxY: maxE1rm,
                    ),
                    const SizedBox(height: 30),
                  ],

                  Row(
                    children: [
                      Icon(
                        isCardio ? Icons.local_fire_department : Icons.stacked_bar_chart,
                        color: isCardio ? Colors.orange : Colors.amber.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isCardio
                              ? "Calories Burned (kcal)"
                              : (_viewMode == 'Exercise'
                                  ? "Total Volume Load"
                                  : _viewMode == 'Muscle'
                                  ? "Total Volume By Muscle Group ($_selectedMuscleGroup)"
                                  : "Total Daily Volume"),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildLineChart(
                    title: isCardio ? "Calories (kcal)" : "Volume Load (kg)",
                    yAxisLabel: isCardio ? "kcal" : "kg",
                    spots: volumeSpots,
                    lineColor: isCardio ? Colors.orange : Colors.amber.shade700,
                    gradientColor: isCardio ? Colors.orangeAccent : Colors.amber,
                    minY: minVolume,
                    maxY: maxVolume,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}

class _PrRecord {
  final String title;
  final String value;
  final String badgeLabel;

  const _PrRecord({
    required this.title,
    required this.value,
    required this.badgeLabel,
  });
}

class _PRTrophyShelf extends StatelessWidget {
  final List<_PrRecord> records;

  const _PRTrophyShelf({required this.records});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (records.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personal Records & Milestones',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: records.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, idx) {
              final pr = records[idx];
              return Container(
                width: 152,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                      : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? theme.colorScheme.outline.withValues(alpha: 0.2)
                        : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      pr.badgeLabel.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      pr.value,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      pr.title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
