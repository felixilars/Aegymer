import 'dart:math';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:aegymer/core/databases/app_database.dart';
import 'package:aegymer/core/utils/workout_cal.dart';
import 'package:aegymer/core/services/streak_service.dart';

class _EditableSet {
  final TextEditingController weightController;
  final TextEditingController repsController;
  final TextEditingController distanceController;
  final TextEditingController durationController;
  String weightType;

  _EditableSet({
    required double weight,
    required int reps,
    this.weightType = 'standard',
    double distance = 0.0,
    int durationSeconds = 0,
  })  : weightController = TextEditingController(text: _formatWeight(weight)),
        repsController = TextEditingController(text: reps > 0 ? reps.toString() : ''),
        distanceController = TextEditingController(
          text: distance > 0 ? distance.toStringAsFixed(2) : '',
        ),
        durationController = TextEditingController(
          text: durationSeconds > 0 ? _formatDurationString(durationSeconds) : '',
        );

  static String _formatWeight(double weight) {
    if (weight <= 0) return '';
    if (weight % 1 == 0) return weight.toInt().toString();
    return weight.toStringAsFixed(1);
  }

  static String _formatDurationString(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  int get parsedDurationSeconds {
    final text = durationController.text.trim();
    if (text.isEmpty) return 0;
    if (text.contains(':')) {
      final parts = text.split(':');
      if (parts.length == 2) {
        final m = int.tryParse(parts[0]) ?? 0;
        final s = int.tryParse(parts[1]) ?? 0;
        return m * 60 + s;
      }
    }
    return int.tryParse(text) ?? 0;
  }

  double get parsedWeight => double.tryParse(weightController.text.trim()) ?? 0.0;
  int get parsedReps => int.tryParse(repsController.text.trim()) ?? 0;
  double get parsedDistance => double.tryParse(distanceController.text.trim()) ?? 0.0;

  void dispose() {
    weightController.dispose();
    repsController.dispose();
    distanceController.dispose();
    durationController.dispose();
  }
}

class _EditableExerciseGroup {
  final Exercise exercise;
  final List<_EditableSet> sets;

  _EditableExerciseGroup({
    required this.exercise,
    required this.sets,
  });

  void dispose() {
    for (final s in sets) {
      s.dispose();
    }
  }
}

class EditWorkoutSessionScreen extends StatefulWidget {
  final AppDatabase db;
  final WorkoutSession session;

  const EditWorkoutSessionScreen({
    super.key,
    required this.db,
    required this.session,
  });

  @override
  State<EditWorkoutSessionScreen> createState() => _EditWorkoutSessionScreenState();
}

class _EditWorkoutSessionScreenState extends State<EditWorkoutSessionScreen> {
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late TextEditingController _notesController;

  List<_EditableExerciseGroup> _groups = [];
  double _userWeight = 70.0;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.session.date.toLocal();
    _selectedTime = TimeOfDay.fromDateTime(widget.session.date.toLocal());
    _notesController = TextEditingController(text: widget.session.notes ?? '');
    _loadSessionData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (final g in _groups) {
      g.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSessionData() async {
    final profile = await (widget.db.select(widget.db.userProfiles)..limit(1)).getSingleOrNull();
    final profileWeight = profile?.weight ?? 70.0;

    final sets = await (widget.db.select(widget.db.workoutSets).join([
      drift.innerJoin(
        widget.db.exercises,
        widget.db.exercises.id.equalsExp(widget.db.workoutSets.exerciseId),
      ),
    ])
      ..where(widget.db.workoutSets.sessionId.equals(widget.session.id))
      ..orderBy([drift.OrderingTerm.asc(widget.db.workoutSets.setNumber)]))
      .get();

    if (!mounted) return;

    final map = <String, _EditableExerciseGroup>{};

    for (final row in sets) {
      final s = row.readTable(widget.db.workoutSets);
      final ex = row.readTable(widget.db.exercises);

      map.putIfAbsent(
        ex.id,
        () => _EditableExerciseGroup(
          exercise: ex,
          sets: [],
        ),
      );

      final editableSet = _EditableSet(
        weight: s.weight,
        reps: s.reps,
        weightType: s.weightType ?? 'standard',
        distance: s.distance ?? 0.0,
        durationSeconds: s.durationSeconds ?? 0,
      );

      editableSet.weightController.addListener(_onSetValuesChanged);
      editableSet.repsController.addListener(_onSetValuesChanged);
      editableSet.distanceController.addListener(_onSetValuesChanged);
      editableSet.durationController.addListener(_onSetValuesChanged);

      map[ex.id]!.sets.add(editableSet);
    }

    setState(() {
      _userWeight = profileWeight > 0 ? profileWeight : 70.0;
      _groups = map.values.toList();
      _loading = false;
    });
  }

  void _onSetValuesChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  double _calculateSetCalories(Exercise ex, _EditableSet s) {
    final trackingType = WorkoutCalculator.normalizeTrackingType(
      s.weightType,
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
      weight: s.parsedWeight,
      reps: s.parsedReps,
      distanceKm: s.parsedDistance,
      durationSeconds: s.parsedDurationSeconds > 0 ? s.parsedDurationSeconds : 90,
    );
  }

  double get _totalCalories {
    double total = 0.0;
    for (final g in _groups) {
      for (final s in g.sets) {
        total += _calculateSetCalories(g.exercise, s);
      }
    }
    return total;
  }

  double get _totalVolume {
    double total = 0.0;
    for (final g in _groups) {
      for (final s in g.sets) {
        total += (s.parsedWeight * s.parsedReps);
      }
    }
    return total;
  }

  int get _totalSetsCount {
    int count = 0;
    for (final g in _groups) {
      count += g.sets.length;
    }
    return count;
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: 'Select Workout Date',
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      helpText: 'Select Workout Time',
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _selectedDate = pickedDate;
      _selectedTime = pickedTime;
    });
  }

  String _formatDateTimeDisplay(DateTime date, TimeOfDay time) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final monthName = months[date.month - 1];
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$monthName ${date.day}, ${date.year} • $hour:$minute $period';
  }

  void _addSetToGroup(_EditableExerciseGroup group) {
    double initWeight = 0.0;
    int initReps = 10;
    String initWeightType = 'standard';

    if (group.sets.isNotEmpty) {
      final lastSet = group.sets.last;
      initWeight = lastSet.parsedWeight;
      initReps = lastSet.parsedReps;
      initWeightType = lastSet.weightType;
    }

    final newSet = _EditableSet(
      weight: initWeight,
      reps: initReps,
      weightType: initWeightType,
    );

    newSet.weightController.addListener(_onSetValuesChanged);
    newSet.repsController.addListener(_onSetValuesChanged);
    newSet.distanceController.addListener(_onSetValuesChanged);
    newSet.durationController.addListener(_onSetValuesChanged);

    setState(() {
      group.sets.add(newSet);
    });
  }

  void _removeSetFromGroup(_EditableExerciseGroup group, int setIndex) {
    setState(() {
      final removed = group.sets.removeAt(setIndex);
      removed.dispose();
      if (group.sets.isEmpty) {
        _groups.remove(group);
        group.dispose();
      }
    });
  }

  Future<void> _confirmRemoveExercise(_EditableExerciseGroup group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Exercise?'),
        content: Text('Remove "${group.exercise.name}" and all its sets from this workout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() {
        _groups.remove(group);
        group.dispose();
      });
    }
  }

  Future<void> _showAddExerciseSheet() async {
    final allExercises = await widget.db.select(widget.db.exercises).get();
    if (!mounted) return;

    allExercises.sort((a, b) => a.name.compareTo(b.name));

    final selectedEx = await showModalBottomSheet<Exercise>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddExercisePickerSheet(exercises: allExercises),
    );

    if (selectedEx != null && mounted) {
      // Check if exercise is already in groups
      final existingIndex = _groups.indexWhere((g) => g.exercise.id == selectedEx.id);
      if (existingIndex >= 0) {
        _addSetToGroup(_groups[existingIndex]);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added another set to ${selectedEx.name}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        final newSet = _EditableSet(weight: 0.0, reps: 10);
        newSet.weightController.addListener(_onSetValuesChanged);
        newSet.repsController.addListener(_onSetValuesChanged);
        newSet.distanceController.addListener(_onSetValuesChanged);
        newSet.durationController.addListener(_onSetValuesChanged);

        final newGroup = _EditableExerciseGroup(
          exercise: selectedEx,
          sets: [newSet],
        );

        setState(() {
          _groups.add(newGroup);
        });
      }
    }
  }

  Future<void> _saveWorkout() async {
    if (_groups.isEmpty || _totalSetsCount == 0) {
      final deleteConfirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Workout is Empty'),
          content: const Text(
            'All exercises and sets have been removed. Do you want to delete this workout session entirely?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep Editing'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete Session'),
            ),
          ],
        ),
      );

      if (deleteConfirm == true && mounted) {
        await _deleteSession();
      }
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final finalDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final companions = <WorkoutSetsCompanion>[];
      int globalSetCounter = 0;

      for (final group in _groups) {
        for (int i = 0; i < group.sets.length; i++) {
          globalSetCounter++;
          final s = group.sets[i];
          final w = s.parsedWeight;
          final r = s.parsedReps;
          final dist = s.parsedDistance;
          final dur = s.parsedDurationSeconds;
          final e1rm = WorkoutCalculator.calculateE1RM(w, r);

          companions.add(
            WorkoutSetsCompanion.insert(
              id: 'set-${widget.session.id}-${group.exercise.id}-$globalSetCounter-${DateTime.now().microsecondsSinceEpoch}',
              sessionId: widget.session.id,
              exerciseId: group.exercise.id,
              setNumber: i + 1,
              weight: w,
              reps: r,
              weightType: drift.Value(s.weightType),
              distance: drift.Value(dist > 0 ? dist : null),
              durationSeconds: drift.Value(dur > 0 ? dur : 90),
              calculated1rm: drift.Value(e1rm > 0 ? e1rm : null),
            ),
          );
        }
      }

      await widget.db.updateWorkoutSession(
        sessionId: widget.session.id,
        date: finalDate,
        notes: _notesController.text.trim(),
        setsCompanions: companions,
      );

      StreakService.notifyWorkoutUpdated();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workout session updated successfully.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving workout: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _deleteSession() async {
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
      setState(() {
        _saving = true;
      });
      await widget.db.deleteWorkoutSession(widget.session.id);
      StreakService.notifyWorkoutUpdated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workout session deleted.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
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

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Workout',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Delete Workout',
            onPressed: _deleteSession,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _saveWorkout,
              icon: _saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: const Text('Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Section 1: Date & Time and Notes
                Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_month_rounded, color: theme.colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Workout Date & Time',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: txtPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: _pickDateTime,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDateTimeDisplay(_selectedDate, _selectedTime),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: txtPrimary,
                                ),
                              ),
                              Icon(Icons.edit_calendar_rounded, size: 18, color: theme.colorScheme.primary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Session Notes',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: txtSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Add workout notes or equipment used...',
                          hintStyle: TextStyle(fontSize: 13, color: txtSecondary.withValues(alpha: 0.6)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Section 2: Live Summary Stats
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF2F6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildMetricItem(
                          icon: Icons.local_fire_department,
                          iconColor: Colors.orange,
                          label: 'Burned',
                          value: WorkoutCalculator.formatCalories(_totalCalories),
                          txtPrimary: txtPrimary,
                          txtSecondary: txtSecondary,
                        ),
                      ),
                      Container(width: 1, height: 28, color: borderColor),
                      Expanded(
                        child: _buildMetricItem(
                          icon: Icons.fitness_center,
                          iconColor: theme.colorScheme.primary,
                          label: 'Volume',
                          value: _totalVolume >= 1000
                              ? '${(_totalVolume / 1000).toStringAsFixed(1)}k kg'
                              : '${_totalVolume.toStringAsFixed(0)} kg',
                          txtPrimary: txtPrimary,
                          txtSecondary: txtSecondary,
                        ),
                      ),
                      Container(width: 1, height: 28, color: borderColor),
                      Expanded(
                        child: _buildMetricItem(
                          icon: Icons.format_list_numbered_rounded,
                          iconColor: Colors.green,
                          label: 'Total Sets',
                          value: '$_totalSetsCount sets',
                          txtPrimary: txtPrimary,
                          txtSecondary: txtSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Section 3: Exercise Groups
                ..._groups.map((group) => _buildExerciseCard(
                      group: group,
                      theme: theme,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      txtPrimary: txtPrimary,
                      txtSecondary: txtSecondary,
                    )),

                const SizedBox(height: 12),

                // Add Exercise Button
                OutlinedButton.icon(
                  onPressed: _showAddExerciseSheet,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Exercise to Workout'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(color: theme.colorScheme.primary),
                  ),
                ),

                const SizedBox(height: 24),

                // Delete Workout Session button
                Center(
                  child: TextButton.icon(
                    onPressed: _deleteSession,
                    icon: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent, size: 20),
                    label: const Text(
                      'Delete this entire workout',
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildExerciseCard({
    required _EditableExerciseGroup group,
    required ThemeData theme,
    required Color cardBg,
    required Color borderColor,
    required Color txtPrimary,
    required Color txtSecondary,
  }) {
    final ex = group.exercise;
    final isCardio = WorkoutCalculator.normalizeTrackingType(
          ex.trackingType,
          name: ex.name,
          targetMuscle: ex.targetMuscle,
          equipment: ex.equipment,
        ) ==
        'cardio_time';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Exercise Name & Delete button
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ex.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: txtPrimary,
                      ),
                    ),
                    if (ex.targetMuscle.isNotEmpty) ...[
                      const SizedBox(height: 4),
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
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                tooltip: 'Remove Exercise',
                onPressed: () => _confirmRemoveExercise(group),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Column Headers
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor, width: 0.8)),
            ),
            child: Row(
              children: [
                _buildHeaderCell('Set', flex: 2, color: txtSecondary),
                _buildHeaderCell(isCardio ? 'Km' : 'Kg', flex: 4, color: txtSecondary),
                _buildHeaderCell(isCardio ? 'Duration' : 'Reps', flex: 4, color: txtSecondary),
                _buildHeaderCell('Mode', flex: 4, color: txtSecondary),
                const SizedBox(width: 32), // space for delete button
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Sets list
          ...group.sets.asMap().entries.map((entry) {
            final idx = entry.key;
            final setItem = entry.value;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  // Set #
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

                  // Weight or Distance input
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: TextField(
                        controller: isCardio ? setItem.distanceController : setItem.weightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: txtPrimary),
                        decoration: InputDecoration(
                          hintText: isCardio ? '0.0' : '0',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ),

                  // Reps or Duration input
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: TextField(
                        controller: isCardio ? setItem.durationController : setItem.repsController,
                        keyboardType: isCardio ? TextInputType.text : TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: txtPrimary),
                        decoration: InputDecoration(
                          hintText: isCardio ? 'mm:ss' : '0',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ),

                  // Weight Mode / Tracking Type selector
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: PopupMenuButton<String>(
                        initialValue: setItem.weightType,
                        tooltip: 'Weight Mode',
                        onSelected: (val) {
                          setState(() {
                            setItem.weightType = val;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _weightTypeLabel(setItem.weightType),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(value: 'standard', child: Text('Standard (Kg)')),
                          const PopupMenuItem(value: 'bodyweight', child: Text('Bodyweight (BW)')),
                          const PopupMenuItem(value: 'added', child: Text('BW + Added (+Kg)')),
                          const PopupMenuItem(value: 'assisted', child: Text('Assisted (-Kg)')),
                        ],
                      ),
                    ),
                  ),

                  // Delete set button
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
                    tooltip: 'Remove Set',
                    onPressed: () => _removeSetFromGroup(group, idx),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 8),

          // Add set button
          Center(
            child: TextButton.icon(
              onPressed: () => _addSetToGroup(group),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Set'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _weightTypeLabel(String type) {
    switch (type) {
      case 'bodyweight':
        return 'BW';
      case 'added':
        return '+ Added';
      case 'assisted':
        return '- Assist';
      case 'standard':
      default:
        return 'Standard';
    }
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
            Text(label, style: TextStyle(fontSize: 11, color: txtSecondary)),
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

class _AddExercisePickerSheet extends StatefulWidget {
  final List<Exercise> exercises;

  const _AddExercisePickerSheet({required this.exercises});

  @override
  State<_AddExercisePickerSheet> createState() => _AddExercisePickerSheetState();
}

class _AddExercisePickerSheetState extends State<_AddExercisePickerSheet> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final filtered = widget.exercises.where((ex) {
      if (_filter.isEmpty) return true;
      final q = _filter.toLowerCase();
      return ex.name.toLowerCase().contains(q) || ex.targetMuscle.toLowerCase().contains(q);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(top: const Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Select Exercise to Add',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            autofocus: false,
            decoration: InputDecoration(
              hintText: 'Search exercise or muscle...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              isDense: true,
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (val) {
              setState(() {
                _filter = val.trim();
              });
            },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No exercises found'))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, idx) {
                      final ex = filtered[idx];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                          child: Icon(Icons.fitness_center_rounded, color: theme.colorScheme.primary, size: 18),
                        ),
                        title: Text(ex.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: ex.targetMuscle.isNotEmpty
                            ? Text(ex.targetMuscle, style: TextStyle(fontSize: 12, color: theme.hintColor))
                            : null,
                        trailing: const Icon(Icons.add_circle_outline_rounded, size: 20),
                        onTap: () => Navigator.pop(context, ex),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
