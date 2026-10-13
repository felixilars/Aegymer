import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/databases/app_database.dart';
import 'package:flutter_application_1/presentation/screen/routine_editor_screen.dart';
import 'package:flutter_application_1/presentation/screen/active_workout_screen.dart';

class WorkoutLauncherScreen extends StatefulWidget {
  final AppDatabase db;

  const WorkoutLauncherScreen({super.key, required this.db});

  @override
  State<WorkoutLauncherScreen> createState() => _WorkoutLauncherScreenState();
}

class _WorkoutLauncherScreenState extends State<WorkoutLauncherScreen> {
  List<RoutineWithExercises> _routines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoutines();
  }

  Future<void> _loadRoutines() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final list = await widget.db.getRoutinesWithExercises();
      setState(() {
        _routines = list;
      });
    } catch (e) {
      debugPrint('Error loading routines: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startFreeStyleWorkout() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) =>
                ActiveWorkoutScreen(db: widget.db, routine: null),
          ),
        )
        .then((_) => _loadRoutines());
  }

  void _startRoutineWorkout(RoutineWithExercises routineWithEx) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) =>
                ActiveWorkoutScreen(db: widget.db, routine: routineWithEx),
          ),
        )
        .then((_) => _loadRoutines());
  }

  void _startWorkoutWithDate({RoutineWithExercises? routine, DateTime? date}) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => ActiveWorkoutScreen(
              db: widget.db,
              routine: routine,
              initialDate: date,
            ),
          ),
        )
        .then((_) => _loadRoutines());
  }

  Future<void> _showLogPastWorkoutDialog() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: yesterday,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: 'Select Past Workout Date',
    );

    if (pickedDate == null || !mounted) return;

    if (_routines.isNotEmpty) {
      final dateStr = '${pickedDate.day}/${pickedDate.month}/${pickedDate.year}';
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history_rounded, color: Colors.blue, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Log Workout for $dateStr',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isDark ? const Color(0xFF334155) : Colors.blue.shade50,
                      child: Icon(
                        Icons.fitness_center,
                        color: isDark ? const Color(0xFF38BDF8) : Colors.blue,
                        size: 20,
                      ),
                    ),
                    title: const Text('Free-style Workout', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Add exercises freely on the fly'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _startWorkoutWithDate(routine: null, date: pickedDate);
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Or select a saved routine:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(ctx).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _routines.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 6),
                      itemBuilder: (context, idx) {
                        final r = _routines[idx];
                        return ListTile(
                          dense: true,
                          title: Text(r.routine.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${r.exercises.length} exercises'),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _startWorkoutWithDate(routine: r, date: pickedDate);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      _startWorkoutWithDate(routine: null, date: pickedDate);
    }
  }

  void _createNewRoutine() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RoutineEditorScreen(
          db: widget.db,
          routineToEdit: null,
        ),
      ),
    ).then((_) => _loadRoutines());
  }

  Future<void> _deleteRoutine(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete routine'),
        content: const Text(
          'Are you sure you want to delete this routine? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.db.deleteRoutine(id);
      _loadRoutines();
    }
  }

  void _editRoutine(RoutineWithExercises routineWithEx) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RoutineEditorScreen(
          db: widget.db,
          routineToEdit: routineWithEx,
        ),
      ),
    ).then((_) => _loadRoutines());
  }

  void _showRoutineDetailsSheet(RoutineWithExercises routineWithEx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.only(top: 20.0, bottom: 20.0),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          routineWithEx.routine.name,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () {
                              Navigator.of(context).pop();
                              _editRoutine(routineWithEx);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              Navigator.of(context).pop();
                              _deleteRoutine(routineWithEx.routine.id);
                            },
                          ),
                        ],
                      )
                    ],
                  ),
                  if (routineWithEx.routine.description != null &&
                      routineWithEx.routine.description!.isNotEmpty) ...[
                    const SizedBox(height: 8.0),
                    Text(
                      routineWithEx.routine.description!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                    ),
                  ],
                  const SizedBox(height: 16.0),
                  Text(
                    'Exercises (${routineWithEx.exercises.length})',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8.0),
                  if (routineWithEx.exercises.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: Center(
                        child: Text('No exercises in this routine'),
                      ),
                    )
                  else
                    ...routineWithEx.exercises.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final ex = entry.value;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        elevation: 0.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Text(
                              '${idx + 1}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            ex.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text('${ex.targetMuscle} • ${ex.equipment}'),
                        ),
                      );
                    }),
                  const SizedBox(height: 24.0),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _startRoutineWorkout(routineWithEx);
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_arrow),
                          SizedBox(width: 8.0),
                          Text(
                            'Start this routine',
                            style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.history_rounded, size: 18),
                      label: const Text('Log for a past date'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.of(context).pop();
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: now.subtract(const Duration(days: 1)),
                          firstDate: DateTime(2020),
                          lastDate: now,
                          helpText: 'Select Workout Date',
                        );
                        if (picked != null) {
                          _startWorkoutWithDate(
                            routine: routineWithEx,
                            date: picked,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadRoutines,
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                children: [
                  // Free-style Workout Card
                  Card(
                    elevation: 3,
                    shadowColor: isDark
                        ? Colors.black.withOpacity(0.4)
                        : Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? const [
                                  Color(0xFF1E293B), // Dark Slate
                                  Color(0xFF0F172A), // Deep Navy Charcoal
                                ]
                              : [
                                  Theme.of(context).colorScheme.primary,
                                  Theme.of(context).colorScheme.secondary,
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: isDark
                            ? Border.all(
                                color: const Color(0xFF334155),
                                width: 1,
                              )
                            : null,
                      ),
                      child: InkWell(
                        onTap: _startFreeStyleWorkout,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Free-style Workout',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 8.0),
                                    Text(
                                      'Start a workout without a predefined routine. You can add exercises on the fly.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Colors.white.withOpacity(
                                              0.85,
                                            ),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF334155)
                                      : Colors.white24,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.play_arrow,
                                  color: isDark
                                      ? const Color(0xFF38BDF8)
                                      : Colors.white,
                                  size: 36,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12.0),

                  // Log Past Workout Card
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isDark
                            ? const Color(0xFF334155)
                            : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    color: isDark
                        ? const Color(0xFF131D2D)
                        : Colors.white,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _showLogPastWorkoutDialog,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 14.0,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E293B)
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.history_edu_rounded,
                                color: isDark
                                    ? const Color(0xFF38BDF8)
                                    : Colors.blue.shade700,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Log Past Workout',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Record a workout completed yesterday or earlier',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: isDark
                                              ? Colors.white60
                                              : Colors.black54,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: isDark ? Colors.white38 : Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24.0),

                  // Routines Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Your Routines',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _createNewRoutine,
                        icon: const Icon(Icons.add),
                        label: const Text('Create New'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),

                  if (_routines.isEmpty)
                    Card(
                      elevation: 0,
                      color: isDark
                          ? Colors.white12
                          : Colors.black12.withOpacity(0.04),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 40.0,
                          horizontal: 20.0,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 48,
                              color: isDark ? Colors.white30 : Colors.black26,
                            ),
                            const SizedBox(height: 16.0),
                            const Text(
                              'No routines found',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8.0),
                            const Text(
                              'Create a new routine to get started with your workout.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._routines.map((routineWithEx) {
                      final exerciseNames = routineWithEx.exercises
                          .map((e) => e.name)
                          .join(', ');
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _showRoutineDetailsSheet(routineWithEx),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        routineWithEx.routine.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      if (routineWithEx.routine.description !=
                                              null &&
                                          routineWithEx
                                              .routine
                                              .description!
                                              .isNotEmpty) ...[
                                        const SizedBox(height: 4.0),
                                        Text(
                                          routineWithEx.routine.description!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(color: Colors.grey),
                                        ),
                                      ],
                                      const SizedBox(height: 12.0),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.fitness_center,
                                            size: 16,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                          const SizedBox(width: 6.0),
                                          Expanded(
                                            child: Text(
                                              routineWithEx.exercises.isEmpty
                                                  ? 'No exercises added'
                                                  : exerciseNames,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isDark
                                                    ? Colors.white70
                                                    : Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8.0),
                                Align(
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.chevron_right,
                                    color: isDark
                                        ? Colors.white30
                                        : Colors.black26,
                                  ),
                                ),
                                
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}