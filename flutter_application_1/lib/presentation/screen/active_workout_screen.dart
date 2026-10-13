import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter_application_1/core/databases/app_database.dart';
import 'package:flutter_application_1/core/utils/workout_cal.dart';
import 'package:flutter_application_1/core/services/sync_service.dart';
import 'package:url_launcher/url_launcher.dart';

class LocalWorkoutSet {
  final TextEditingController weightController;
  final TextEditingController repsController;
  final TextEditingController distanceController;
  final TextEditingController durationController;

  String weightType; // 'standard', 'added', 'assisted', 'bodyweight'

  LocalWorkoutSet({
    required double weight,
    required int reps,
    this.weightType = 'standard',
    double distance = 0.0,
    int duration = 0,
  }) : weightController = TextEditingController(text: formatWeight(weight)),
       repsController = TextEditingController(text: reps.toString()),
       distanceController = TextEditingController(
         text: distance > 0 ? distance.toStringAsFixed(2) : '',
       ),
       durationController = TextEditingController(
         text: duration > 0 ? _formatDurationString(duration) : '',
       );

  static String formatWeight(double weight) {
    if (weight % 1 == 0) {
      return weight.toStringAsFixed(0);
    } else if ((weight * 10) % 1 == 0) {
      return weight.toStringAsFixed(1);
    } else {
      return weight.toStringAsFixed(2);
    }
  }

  static String _formatDurationString(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  int get durationInSeconds {
    final text = durationController.text.trim();
    if (text.isEmpty) return 0;
    if (text.contains(':')) {
      final parts = text.split(':');
      if (parts.length == 2) {
        final m = int.tryParse(parts[0]) ?? 0;
        final s = int.tryParse(parts[1]) ?? 0;
        return m * 60 + s;
      } else if (parts.length == 3) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        final s = int.tryParse(parts[2]) ?? 0;
        return h * 3600 + m * 60 + s;
      }
    }
    return int.tryParse(text) ?? 0;
  }

  void dispose() {
    weightController.dispose();
    repsController.dispose();
    distanceController.dispose();
    durationController.dispose();
  }
}

class ActiveWorkoutScreen extends StatefulWidget {
  final AppDatabase db;
  final RoutineWithExercises? routine;

  const ActiveWorkoutScreen({super.key, required this.db, this.routine});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  final _notesController = TextEditingController();
  final _pageController = PageController();
  final _headerScrollController = ScrollController();

  Timer? _timer;
  int _secondsElapsed = 0;
  bool _isLoading = true;

  // Active workout exercises and their sets
  List<Exercise> _sessionExercises = [];
  final Map<String, List<LocalWorkoutSet>> _exerciseSets = {};

  // Active tracking type per exercise
  final Map<String, String> _activeTrackingTypes = {};

  // Barbell state maps per exercise
  final Map<String, bool> _useBarbell = {};
  final Map<String, double> _barbellWeight = {};
  final Map<String, TextEditingController> _barbellWeightControllers = {};

  // Exercise-specific stopwatches
  final Map<String, int> _exerciseStopwatchSeconds = {};
  final Map<String, bool> _exerciseStopwatchRunning = {};

  // All available exercises for adding custom ones dynamically
  List<Exercise> _allAvailableExercises = [];

  int _currentPageIndex = 0;
  UserProfile? _userProfile;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _loadInitialData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _notesController.dispose();
    _pageController.dispose();
    _headerScrollController.dispose();
    for (final controller in _barbellWeightControllers.values) {
      controller.dispose();
    }
    for (var sets in _exerciseSets.values) {
      for (var s in sets) {
        s.dispose();
      }
    }
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
          for (final key in _exerciseStopwatchRunning.keys) {
            if (_exerciseStopwatchRunning[key] == true) {
              _exerciseStopwatchSeconds[key] =
                  (_exerciseStopwatchSeconds[key] ?? 0) + 1;
            }
          }
        });
      }
    });
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    // 1. Load profile
    final profiles = await widget.db.select(widget.db.userProfiles).get();
    if (profiles.isNotEmpty) {
      _userProfile = profiles.first;
    }

    // 2. Load all exercises in database (for additions)
    _allAvailableExercises = await widget.db.select(widget.db.exercises).get();
    if (_allAvailableExercises.isEmpty) {
      await SyncService(widget.db).seedDefaultExercisesIfNeeded();
      _allAvailableExercises = await widget.db.select(widget.db.exercises).get();
    }

    // 3. Load routine exercises
    if (widget.routine != null) {
      _sessionExercises = List.from(widget.routine!.exercises);
    } else {
      _sessionExercises = [];
    }

    // 4. Init sets and tracking types
    for (final ex in _sessionExercises) {
      final initialType = WorkoutCalculator.normalizeTrackingType(
        ex.trackingType,
        name: ex.name,
        targetMuscle: ex.targetMuscle,
        equipment: ex.equipment,
      );
      _activeTrackingTypes[ex.id] = initialType;
      _initSetsForExercise(ex);
    }

    setState(() {
      _isLoading = false;
    });
  }  
  
  void _initSetsForExercise(Exercise ex) {
    final String trackingType = _activeTrackingTypes[ex.id] ?? 'weight_reps';
    final double initW = WorkoutCalculator.getDefaultInputWeight(trackingType);
    final int defaultSetsCount = (trackingType == 'cardio_time') ? 1 : 3;

    String wType = 'standard';
    if (trackingType == 'bodyweight') {
      wType = 'bodyweight';
    } else if (trackingType == 'bodyweight_weighted') {
      wType = 'added';
    } else if (trackingType == 'bodyweight_assisted') {
      wType = 'assisted';
    }

    _exerciseSets[ex.id] = List.generate(defaultSetsCount, (index) {
      int baseR = 10;
      int baseDuration = 0;
      double baseDistance = 0.0;

      if (trackingType == 'time_only') {
        baseR = 60;
        baseDuration = 60;
      } else if (trackingType == 'cardio_time') {
        baseR = 1;
        baseDistance = 5.0; // default 5.0 km
        baseDuration = 1200; // default 20 mins (1200 secs)
      }

      return LocalWorkoutSet(
        weight: initW,
        reps: baseR,
        weightType: wType,
        distance: baseDistance,
        duration: baseDuration,
      );
    });
  }

  void _addNewSet(String exerciseId) {
    final String trackingType =
        _activeTrackingTypes[exerciseId] ?? 'weight_reps';
    final sets = _exerciseSets[exerciseId] ?? [];

    double lastW = WorkoutCalculator.getDefaultInputWeight(trackingType);
    final bool useBar = _useBarbell[exerciseId] ?? false;
    final double barW = _barbellWeight[exerciseId] ?? 20.0;
    if (useBar && trackingType == 'weight_reps') {
      lastW = max(0.0, (lastW - barW) / 2.0);
    }
    int lastR = 10;
    double lastDist = 0.0;
    int lastDur = 0;
    String lastWType = 'standard';

    if (trackingType == 'bodyweight') {
      lastWType = 'bodyweight';
    } else if (trackingType == 'bodyweight_weighted') {
      lastWType = 'added';
    } else if (trackingType == 'bodyweight_assisted') {
      lastWType = 'assisted';
    }

    if (sets.isNotEmpty) {
      final lastSet = sets.last;
      lastW = double.tryParse(lastSet.weightController.text) ?? lastW;
      lastR = int.tryParse(lastSet.repsController.text) ?? lastR;
      lastDist = double.tryParse(lastSet.distanceController.text) ?? lastDist;
      lastDur = lastSet.durationInSeconds;
      lastWType = lastSet.weightType;
    }

    setState(() {
      _exerciseSets[exerciseId] = [
        ...sets,
        LocalWorkoutSet(
          weight: lastW,
          reps: lastR,
          weightType: lastWType,
          distance: lastDist,
          duration: lastDur,
        ),
      ];
    });
  }

  void _removeLastSet(String exerciseId) {
    final sets = _exerciseSets[exerciseId] ?? [];
    if (sets.isEmpty) return;

    setState(() {
      final removed = sets.last;
      _exerciseSets[exerciseId] = List.from(sets)..removeLast();
      removed.dispose();
    });
  }

  Future<void> _finishWorkout() async {
    // Collect all sets that are completed
    final List<WorkoutSetsCompanion> setsCompanions = [];
    bool hasCompletedSet = false;

    for (final ex in _sessionExercises) {
      final sets = _exerciseSets[ex.id] ?? [];
      final String trackingType =
          _activeTrackingTypes[ex.id] ??
          WorkoutCalculator.normalizeTrackingType(
            ex.trackingType,
            name: ex.name,
            targetMuscle: ex.targetMuscle,
            equipment: ex.equipment,
          );
      final double userBodyweight = _userProfile?.weight ?? 70.0;

      final bool useBar = _useBarbell[ex.id] ?? false;
      final double barW = _barbellWeight[ex.id] ?? 20.0;

      for (int i = 0; i < sets.length; i++) {
        final localSet = sets[i];
        final weight = double.tryParse(localSet.weightController.text) ?? 0.0;
        final reps = int.tryParse(localSet.repsController.text) ?? 0;
        final distanceVal =
            double.tryParse(localSet.distanceController.text) ?? 0.0;
        final durationVal = localSet.durationInSeconds;

        final double actualWeight = useBar ? (2.0 * weight + barW) : weight;

        final String wType =
            (trackingType == 'bodyweight' ||
                trackingType == 'bodyweight_weighted' ||
                trackingType == 'bodyweight_assisted')
            ? localSet.weightType
            : 'standard';

        bool isCompleted = false;
        if (trackingType == 'cardio_time') {
          isCompleted = durationVal > 0 || distanceVal > 0;
        } else if (trackingType == 'time_only') {
          isCompleted = durationVal > 0;
        } else if (trackingType == 'bodyweight') {
          isCompleted = reps > 0;
        } else {
          isCompleted = actualWeight > 0 && reps > 0;
        }

        if (isCompleted) {
          hasCompletedSet = true;
          final sessionId = 'temp_id'; // will be replaced in save transaction

          final double effWeight = WorkoutCalculator.getEffectiveWeight(
            weightInput:
                trackingType == 'cardio_time' || trackingType == 'time_only'
                ? 0.0
                : actualWeight,
            weightType: wType,
            userBodyweight: userBodyweight,
          );
          final double e1rm = WorkoutCalculator.calculateE1RM(
            effWeight,
            trackingType == 'time_only' ? durationVal : reps,
          );

          setsCompanions.add(
            WorkoutSetsCompanion.insert(
              id: 'set-${DateTime.now().microsecondsSinceEpoch}-$i-${Random().nextInt(1000)}',
              sessionId: sessionId,
              exerciseId: ex.id,
              setNumber: i + 1,
              weight:
                  trackingType == 'cardio_time' || trackingType == 'time_only'
                  ? 0.0
                  : actualWeight,
              reps: trackingType == 'cardio_time'
                  ? 1
                  : (trackingType == 'time_only' ? durationVal : reps),
              rpe: const Value.absent(),
              calculated1rm: Value(e1rm),
              weightType: Value(wType),
              distance: trackingType == 'cardio_time'
                  ? Value(distanceVal)
                  : const Value.absent(),
              durationSeconds:
                  (trackingType == 'cardio_time' || trackingType == 'time_only')
                  ? Value(durationVal)
                  : const Value.absent(),
            ),
          );
        }
      }
    }

    if (!hasCompletedSet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete at least one set before finishing the workout.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finish Workout?'),
        content: const Text(
          'Are you sure you want to finish this workout and save the history?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Finish'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final sessionId = 'session-${DateTime.now().millisecondsSinceEpoch}';

      final finalCompanions = setsCompanions.map((set) {
        return set.copyWith(sessionId: Value(sessionId));
      }).toList();

      await widget.db.saveWorkoutSession(
        sessionId: sessionId,
        date: DateTime.now(),
        notes: _notesController.text.trim(),
        setsCompanions: finalCompanions,
      );

      double totalVolume = 0.0;
      for (final companion in finalCompanions) {
        final w = companion.weight.value;
        final r = companion.reps.value;
        totalVolume += (w * r);
      }

      if (mounted) {
        await _showPostWorkoutSummaryDialog(
          totalVolume: totalVolume,
          totalSets: finalCompanions.length,
          durationSeconds: _secondsElapsed,
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Error saving session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving workout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showPostWorkoutSummaryDialog({
    required double totalVolume,
    required int totalSets,
    required int durationSeconds,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(Icons.emoji_events, size: 56, color: Colors.amber),
            const SizedBox(height: 8),
            const Text(
              'Workout Complete!',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Great job! Your session has been saved to your progress history.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStat('Duration', _formatDuration(durationSeconds), Icons.timer),
                _buildSummaryStat('Sets', '$totalSets', Icons.fitness_center),
                _buildSummaryStat('Volume', '${totalVolume.toStringAsFixed(0)} kg', Icons.stacked_bar_chart),
              ],
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Awesome!'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  void _scrollToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    _scrollToHeaderIndicator(index);
  }

  void _scrollToHeaderIndicator(int index) {
    if (!_headerScrollController.hasClients) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final targetOffset = index * 120.0 - (screenWidth / 2) + 60.0;
    _headerScrollController.animateTo(
      max(0.0, targetOffset),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

 @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.routine?.routine.name ?? 'Free Workout',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'Time: ${_formatDuration(_secondsElapsed)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Add Exercise',
            onPressed: _showAddExerciseSheet,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              onPressed: _finishWorkout,
              child: const Text('Finish Workout'),
            ),
          ),
        ],
      ),
      body: _sessionExercises.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                _buildHorizontalIndicatorBar(),
                const Divider(height: 1),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _sessionExercises.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPageIndex = index;
                      });
                      _scrollToHeaderIndicator(index);
                    },
                    itemBuilder: (context, index) {
                      final ex = _sessionExercises[index];
                      return _buildExercisePage(ex);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fitness_center_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'No exercises added',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add exercises to start logging your workout session.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddExerciseSheet,
              icon: const Icon(Icons.add),
              label: const Text('Add First Exercise'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalIndicatorBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 50,
      color: isDark ? Colors.black26 : Colors.grey.shade50,
      child: ListView.builder(
        controller: _headerScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: _sessionExercises.length,
        itemBuilder: (context, index) {
          final ex = _sessionExercises[index];
          final isSelected = index == _currentPageIndex;
          final sets = _exerciseSets[ex.id] ?? [];
          final bool isDone = sets.isNotEmpty;

          return GestureDetector(
            onTap: () => _scrollToPage(index),
            child: Container(
              width: 130,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isDone)
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Colors.green.shade600,
                    )
                  else
                    Icon(
                      Icons.radio_button_unchecked,
                      size: 14,
                      color: Colors.grey.shade400,
                    ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      ex.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExercisePage(Exercise ex) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sets = _exerciseSets[ex.id] ?? [];
    final activeType = _activeTrackingTypes[ex.id] ?? 'weight_reps';

    final stopwatchSeconds = _exerciseStopwatchSeconds[ex.id] ?? 0;
    final stopwatchRunning = _exerciseStopwatchRunning[ex.id] ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & Google Search Help Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ex.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${ex.targetMuscle} • ${ex.equipment}',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.help_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                tooltip: 'View Exercise Instructions',
                onPressed: () async {
                  final query = Uri.encodeComponent(
                    '${ex.name} exercise how to form',
                  );
                  final url = Uri.parse(
                    'https://www.google.com/search?q=$query',
                  );
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16.0),

          // Timer and Tracking Mode Selector Row
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTrackingTypeSelectorButton(ex),
              // Exercise stopwatch
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDuration(stopwatchSeconds),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _exerciseStopwatchRunning[ex.id] = !stopwatchRunning;
                        });
                      },
                      child: Icon(
                        stopwatchRunning
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline,
                        size: 20,
                        color: stopwatchRunning ? Colors.orange : Colors.green,
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _exerciseStopwatchSeconds[ex.id] = 0;
                          _exerciseStopwatchRunning[ex.id] = false;
                        });
                      },
                      child: const Icon(
                        Icons.replay_outlined,
                        size: 20,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16.0),

          // Barbell Calculator checkbox
          if (activeType == 'weight_reps') ...[
            _buildBarbellOptions(ex.id),
            const SizedBox(height: 16.0),
          ],

          // Excel Grid Header
          _buildTableHeader(ex.id, isDark),

          // Excel Grid Rows
          if (sets.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black12,
                  width: 0.5,
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(8),
                ),
              ),
              child: const Center(
                child: Text('No sets added. Press the (+) button below to add one.'),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: isDark ? Colors.white10 : Colors.black12,
                    width: 0.5,
                  ),
                  right: BorderSide(
                    color: isDark ? Colors.white10 : Colors.black12,
                    width: 0.5,
                  ),
                ),
              ),
              child: Column(
                children: List.generate(sets.length, (index) {
                  return _buildSetRow(ex.id, sets[index], index);
                }),
              ),
            ),

          // Excel Grid Footer / Set modifiers
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.02)
                  : Colors.grey.shade50,
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.black12,
                width: 0.5,
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(8),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: () => _removeLastSet(ex.id),
                  icon: const Icon(Icons.remove, size: 16, color: Colors.red),
                  label: const Text(
                    'Remove Last Set',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 20, child: VerticalDivider(width: 1)),
                TextButton.icon(
                  onPressed: () => _addNewSet(ex.id),
                  icon: const Icon(Icons.add, size: 16, color: Colors.green),
                  label: const Text(
                    'Add Set',
                    style: TextStyle(color: Colors.green, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24.0),

          // Notes input field
          const Text(
            'Workout Notes',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8.0),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText:
                  'Enter notes for today\'s workout (feelings, injuries...)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }

  void _onToggleBarbell(String exerciseId, bool val) {
    setState(() {
      _useBarbell[exerciseId] = val;
      final double barW = _barbellWeight[exerciseId] ?? 20.0;
      final sets = _exerciseSets[exerciseId] ?? [];
      for (final set in sets) {
        final currentVal =
            double.tryParse(set.weightController.text) ?? 0.0;
        if (val) {
          // Convert from total barbell weight to weight per side: (Total - Barbell) / 2
          final oneSide = max(0.0, (currentVal - barW) / 2.0);
          set.weightController.text = LocalWorkoutSet.formatWeight(
            oneSide,
          );
        } else {
          // Convert from weight per side to total barbell weight: 2 * (Per Side) + Barbell
          final total = 2.0 * currentVal + barW;
          set.weightController.text = LocalWorkoutSet.formatWeight(
            total,
          );
        }
      }
    });
  }

  Widget _buildBarbellOptions(String exerciseId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool useBar = _useBarbell[exerciseId] ?? false;
    final double barW = _barbellWeight[exerciseId] ?? 20.0;

    if (!_barbellWeightControllers.containsKey(exerciseId)) {
      _barbellWeightControllers[exerciseId] = TextEditingController(
        text: LocalWorkoutSet.formatWeight(barW),
      );
    }
    final controller = _barbellWeightControllers[exerciseId]!;

    return Card(
      elevation: 0,
      color: isDark ? Colors.white10 : Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _onToggleBarbell(exerciseId, !useBar),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: useBar,
                    onChanged: (val) {
                      if (val != null) {
                        _onToggleBarbell(exerciseId, val);
                      }
                    },
                  ),
                  const Expanded(
                    child: Text(
                      'Use Barbell (enter weight on one side)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (useBar) ...[
                    const SizedBox(width: 8),
                    const Text(
                      'Barbell:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 52,
                      height: 32,
                      child: TextField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(vertical: 6),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (text) {
                          final val = double.tryParse(text) ?? 20.0;
                          setState(() {
                            _barbellWeight[exerciseId] = val;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'kg',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
              if (useBar)
                Padding(
                  padding: const EdgeInsets.only(left: 48.0, bottom: 4.0),
                  child: Builder(
                    builder: (context) {
                      final sets = _exerciseSets[exerciseId] ?? [];
                      final firstSetWeight = sets.isNotEmpty
                          ? (double.tryParse(sets.first.weightController.text) ?? 0.0)
                          : 0.0;
                      final totalFirst = 2.0 * firstSetWeight + barW;
                      return Text(
                        'Total: ${LocalWorkoutSet.formatWeight(totalFirst)} kg (Bar ${LocalWorkoutSet.formatWeight(barW)} kg + 2 × ${LocalWorkoutSet.formatWeight(firstSetWeight)} kg)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeader(String exerciseId, bool isDark) {
    final String activeType = _activeTrackingTypes[exerciseId] ?? 'weight_reps';

    List<Widget> children = [];
    if (activeType == 'cardio_time') {
      children = [
        _buildHeaderCell('SET', 2, isDark),
        _buildHeaderCell('DISTANCE (KM)', 9, isDark),
        _buildHeaderCell('DURATION (MM:SS)', 9, isDark),
      ];
    } else if (activeType == 'time_only') {
      children = [
        _buildHeaderCell('SET', 2, isDark),
        _buildHeaderCell('DURATION (MM:SS)', 18, isDark),
      ];
    } else if (activeType == 'bodyweight') {
      children = [
        _buildHeaderCell('SET', 2, isDark),
        _buildHeaderCell('REPS', 18, isDark),
      ];
    } else if (activeType == 'bodyweight_weighted' ||
        activeType == 'bodyweight_assisted') {
      children = [
        _buildHeaderCell('SET', 2, isDark),
        _buildHeaderCell('TYPE', 4, isDark),
        _buildHeaderCell('WEIGHT (KG)', 7, isDark),
        _buildHeaderCell('REPS', 7, isDark),
      ];
    } else {
      final bool useBar = _useBarbell[exerciseId] ?? false;
      children = [
        _buildHeaderCell('SET', 2, isDark),
        _buildHeaderCell(useBar ? 'WEIGHT (KG/SIDE)' : 'WEIGHT (KG)', 9, isDark),
        _buildHeaderCell('REPS', 9, isDark),
      ];
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(children: children),
    );
  }

  Widget _buildHeaderCell(String label, int flex, bool isDark) {
    return Expanded(
      flex: flex,
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.grey.shade700,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildSetRow(String exerciseId, LocalWorkoutSet localSet, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String activeType = _activeTrackingTypes[exerciseId] ?? 'weight_reps';

    final bool useBar = _useBarbell[exerciseId] ?? false;
    final double step = useBar ? 1.25 : 2.5;

    List<Widget> children = [];
    if (activeType == 'cardio_time') {
      children = [
        // Set number
        Expanded(
          flex: 2,
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        // Distance
        Expanded(
          flex: 9,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: TextField(
              controller: localSet.distanceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: '0.00',
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        // Duration
        Expanded(
          flex: 9,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: TextField(
              controller: localSet.durationController,
              keyboardType: TextInputType.datetime,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: 'MM:SS',
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ];
    } else if (activeType == 'time_only') {
      children = [
        // Set number
        Expanded(
          flex: 2,
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        // Duration
        Expanded(
          flex: 18,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: TextField(
              controller: localSet.durationController,
              keyboardType: TextInputType.datetime,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: 'MM:SS',
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ];
    } else if (activeType == 'bodyweight') {
      children = [
        // Set number
        Expanded(
          flex: 2,
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        // Reps
        Expanded(flex: 18, child: _buildRepsField(localSet)),
      ];
    } else if (activeType == 'bodyweight_weighted' ||
        activeType == 'bodyweight_assisted') {
      children = [
        // Set number
        Expanded(
          flex: 2,
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        // Type selector
        Expanded(
          flex: 4,
          child: DropdownButton<String>(
            value: localSet.weightType,
            isExpanded: true,
            underline: const SizedBox(),
            items: [
              DropdownMenuItem(
                value: 'bodyweight',
                child: Center(
                  child: Text(
                    'BW',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ),
              DropdownMenuItem(
                value: activeType == 'bodyweight_weighted'
                    ? 'added'
                    : 'assisted',
                child: Center(
                  child: Text(
                    activeType == 'bodyweight_weighted' ? '+ Weight' : '- Assistance',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  localSet.weightType = val;
                });
              }
            },
          ),
        ),
        // Weight
        Expanded(flex: 7, child: _buildWeightField(localSet, step)),
        // Reps
        Expanded(flex: 7, child: _buildRepsField(localSet)),
      ];
    } else {
      children = [
        // Set number
        Expanded(
          flex: 2,
          child: Center(
            child: Text(
              '${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        // Weight
        Expanded(flex: 9, child: _buildWeightField(localSet, step)),
        // Reps
        Expanded(flex: 9, child: _buildRepsField(localSet)),
      ];
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.black12,
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(children: children),
    );
  }

  Widget _buildWeightField(LocalWorkoutSet localSet, double step) {
    if (localSet.weightType == 'bodyweight') {
      return const Center(
        child: Text(
          'Bodyweight',
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.grey,
            fontSize: 13,
          ),
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          visualDensity: VisualDensity.compact,
          onPressed: () {
            final w = double.tryParse(localSet.weightController.text) ?? 0.0;
            localSet.weightController.text = LocalWorkoutSet.formatWeight(
              max(0.0, w - step),
            );
          },
        ),
        Expanded(
          child: TextField(
            controller: localSet.weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 4),
              border: InputBorder.none,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          visualDensity: VisualDensity.compact,
          onPressed: () {
            final w = double.tryParse(localSet.weightController.text) ?? 0.0;
            localSet.weightController.text = LocalWorkoutSet.formatWeight(
              w + step,
            );
          },
        ),
      ],
    );
  }

  Widget _buildRepsField(LocalWorkoutSet localSet) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          visualDensity: VisualDensity.compact,
          onPressed: () {
            final r = int.tryParse(localSet.repsController.text) ?? 0;
            localSet.repsController.text = max(0, r - 1).toString();
          },
        ),
        Expanded(
          child: TextField(
            controller: localSet.repsController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 4),
              border: InputBorder.none,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 18),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          visualDensity: VisualDensity.compact,
          onPressed: () {
            final r = int.tryParse(localSet.repsController.text) ?? 0;
            localSet.repsController.text = (r + 1).toString();
          },
        ),
      ],
    );
  }

  Widget _buildTrackingChip(
    String label,
    String type,
    String activeType,
    Exercise ex,
    StateSetter setModalState,
  ) {
    final isSelected = type == activeType;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() {
            _activeTrackingTypes[ex.id] = type;
            // Re-initialize sets layout for this exercise
            _initSetsForExercise(ex);
          });
          setModalState(() {});
        }
      },
    );
  }

  Widget _buildTrackingTypeSelectorButton(Exercise ex) {
    final String activeType = _activeTrackingTypes[ex.id] ?? 'weight_reps';
    String label = 'Weight & Reps';
    if (activeType == 'bodyweight') label = 'Bodyweight';
    if (activeType == 'bodyweight_weighted') label = 'Bodyweight + Weight';
    if (activeType == 'bodyweight_assisted') label = 'Bodyweight - Assisted';
    if (activeType == 'cardio_time') label = 'Cardio';
    if (activeType == 'time_only') label = 'Time Only';

    return OutlinedButton.icon(
      onPressed: () => _showTrackingTypeSelector(ex),
      icon: const Icon(Icons.settings_outlined, size: 14),
      label: Text('Mode: $label', style: const TextStyle(fontSize: 12)),
    );
  }

  void _showTrackingTypeSelector(Exercise ex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final String activeType =
                _activeTrackingTypes[ex.id] ?? 'weight_reps';
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Tracking Mode',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: [
                        _buildTrackingChip(
                          'Weight & Reps',
                          'weight_reps',
                          activeType,
                          ex,
                          setModalState,
                        ),
                        _buildTrackingChip(
                          'Bodyweight',
                          'bodyweight',
                          activeType,
                          ex,
                          setModalState,
                        ),
                        _buildTrackingChip(
                          'Bodyweight + Weight',
                          'bodyweight_weighted',
                          activeType,
                          ex,
                          setModalState,
                        ),
                        _buildTrackingChip(
                          'Bodyweight - Assisted',
                          'bodyweight_assisted',
                          activeType,
                          ex,
                          setModalState,
                        ),
                        _buildTrackingChip(
                          'Cardio (Time & Distance)',
                          'cardio_time',
                          activeType,
                          ex,
                          setModalState,
                        ),
                        _buildTrackingChip(
                          'Time Only (Isometric)',
                          'time_only',
                          activeType,
                          ex,
                          setModalState,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddExerciseSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        return _AddExerciseSheet(
          allExercises: _allAvailableExercises,
          currentSessionExercises: _sessionExercises,
          onExerciseAdded: (ex) {
            setState(() {
              if (!_sessionExercises.any((e) => e.id == ex.id)) {
                _sessionExercises.add(ex);
                final initialType = WorkoutCalculator.normalizeTrackingType(
                  ex.trackingType,
                  name: ex.name,
                  targetMuscle: ex.targetMuscle,
                  equipment: ex.equipment,
                );
                _activeTrackingTypes[ex.id] = initialType;
                _initSetsForExercise(ex);
              }
              _currentPageIndex = _sessionExercises.length - 1;
            });
            // Delay to allow page view to register page count before scrolling
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                _scrollToPage(_currentPageIndex);
              }
            });
          },
          db: widget.db,
        );
      },
    );
  }
}

class _AddExerciseSheet extends StatefulWidget {
  final List<Exercise> allExercises;
  final List<Exercise> currentSessionExercises;
  final Function(Exercise) onExerciseAdded;
  final AppDatabase db;

  const _AddExerciseSheet({
    required this.allExercises,
    required this.currentSessionExercises,
    required this.onExerciseAdded,
    required this.db,
  });

  @override
  State<_AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends State<_AddExerciseSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Exercise> _filteredExercises = [];
  String _selectedMuscleFilter = 'All';

  @override
  void initState() {
    super.initState();
    _filteredExercises = List.from(widget.allExercises);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterExercises() {
    final query = _searchController.text.trim();
    setState(() {
      _filteredExercises = widget.allExercises.where((ex) {
        final matchesMuscle =
            _selectedMuscleFilter == 'All' ||
            ex.targetMuscle == _selectedMuscleFilter;
        final matchesSearch = WorkoutCalculator.matchesSearch(
          exerciseName: ex.name,
          targetMuscle: ex.targetMuscle,
          query: query,
        );
        return matchesMuscle && matchesSearch;
      }).toList();
    });
  }

  Future<void> _createNewCustomExercise() async {
    final nameController = TextEditingController();
    String targetMuscle = 'Chest';
    String equipment = 'Barbell';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create New Custom Exercise'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Exercise Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    DropdownButtonFormField<String>(
                      value: targetMuscle,
                      decoration: const InputDecoration(
                        labelText: 'Main Muscle Group',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Chest',
                          child: Text('Chest'),
                        ),
                        DropdownMenuItem(
                          value: 'Back',
                          child: Text('Back'),
                        ),
                        DropdownMenuItem(
                          value: 'Lats',
                          child: Text('Lats'),
                        ),
                        DropdownMenuItem(
                          value: 'Shoulders',
                          child: Text('Shoulders'),
                        ),
                        DropdownMenuItem(
                          value: 'Biceps',
                          child: Text('Biceps'),
                        ),
                        DropdownMenuItem(
                          value: 'Triceps',
                          child: Text('Triceps'),
                        ),
                        DropdownMenuItem(
                          value: 'Quads',
                          child: Text('Quads'),
                        ),
                        DropdownMenuItem(
                          value: 'Hamstrings',
                          child: Text('Hamstrings'),
                        ),
                        DropdownMenuItem(
                          value: 'Glutes',
                          child: Text('Glutes'),
                        ),
                        DropdownMenuItem(
                          value: 'Calves',
                          child: Text('Calves'),
                        ),
                        DropdownMenuItem(
                          value: 'Abs',
                          child: Text('Abs'),
                        ),
                        DropdownMenuItem(
                          value: 'Cardio',
                          child: Text('Cardio'),
                        ),
                        DropdownMenuItem(
                          value: 'Full Body',
                          child: Text('Full Body'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            targetMuscle = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16.0),
                    DropdownButtonFormField<String>(
                      value: equipment,
                      decoration: const InputDecoration(
                        labelText: 'Equipment',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Barbell',
                          child: Text('Barbell'),
                        ),
                        DropdownMenuItem(
                          value: 'Dumbbell',
                          child: Text('Dumbbell'),
                        ),
                        DropdownMenuItem(
                          value: 'Machine',
                          child: Text('Machine'),
                        ),
                        DropdownMenuItem(
                          value: 'Cable',
                          child: Text('Cable'),
                        ),
                        DropdownMenuItem(
                          value: 'Bodyweight',
                          child: Text('Bodyweight'),
                        ),
                        DropdownMenuItem(
                          value: 'Kettlebell',
                          child: Text('Kettlebell'),
                        ),
                        DropdownMenuItem(
                          value: 'Band',
                          child: Text('Band'),
                        ),
                        DropdownMenuItem(
                          value: 'None',
                          child: Text('None'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            equipment = val;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.trim().isNotEmpty) {
                      Navigator.of(context).pop(true);
                    }
                  },
                  child: const Text('Create Exercise'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm == true) {
      final nameText = nameController.text.trim();
      final newId = 'ex-custom-${DateTime.now().millisecondsSinceEpoch}';

      final autoDetectedTrackingType = WorkoutCalculator.normalizeTrackingType(
        null,
        name: nameText,
        targetMuscle: targetMuscle,
        equipment: equipment,
      );

      final newEx = Exercise(
        id: newId,
        name: nameText,
        targetMuscle: targetMuscle,
        equipment: equipment,
        isCustom: true,
        trackingType: autoDetectedTrackingType,
      );

      await widget.db.into(widget.db.exercises).insert(newEx);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully created exercise "$nameText"!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Automatically add it to the active list and close sheet
      widget.onExerciseAdded(newEx);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<String> muscleGroups = [
      'All',
      'Chest',
      'Back',
      'Lats',
      'Shoulders',
      'Biceps',
      'Triceps',
      'Quads',
      'Hamstrings',
      'Glutes',
      'Calves',
      'Abs',
      'Cardio',
      'Full Body',
    ];

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Pull bar indicator
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

              // Title and Custom Create Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add Exercise to Session',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  TextButton.icon(
                    onPressed: _createNewCustomExercise,
                    icon: const Icon(Icons.add),
                    label: const Text('Create New'),
                  ),
                ],
              ),
              const SizedBox(height: 12.0),

              // Search Box
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search exercises...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: (_) => _filterExercises(),
              ),
              const SizedBox(height: 10.0),

              // Muscle Group Chips
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: muscleGroups.length,
                  itemBuilder: (context, index) {
                    final m = muscleGroups[index];
                    final isSelected = m == _selectedMuscleFilter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ChoiceChip(
                        label: Text(
                          m == 'All' ? 'All muscle groups' : m,
                          style: const TextStyle(fontSize: 11),
                        ),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _selectedMuscleFilter = m;
                            });
                            _filterExercises();
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 20),

              // Exercises List
              Expanded(
                child: _filteredExercises.isEmpty
                    ? const Center(
                        child: Text('No matching exercises found.'),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _filteredExercises.length,
                        itemBuilder: (context, index) {
                          final ex = _filteredExercises[index];
                          final isAlreadyAdded = widget.currentSessionExercises
                              .any((e) => e.id == ex.id);

                          return ListTile(
                            leading: Icon(
                              isAlreadyAdded
                                  ? Icons.check_circle
                                  : Icons.fitness_center_outlined,
                              color: isAlreadyAdded
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.primary,
                            ),
                            title: Text(
                              ex.name,
                              style: TextStyle(
                                fontWeight: isAlreadyAdded
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              '${ex.targetMuscle} • ${ex.equipment}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.info_outline,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                  tooltip: 'Search for form guide',
                                  onPressed: () async {
                                    final query = Uri.encodeComponent(
                                      '${ex.name} exercise how to form',
                                    );
                                    final url = Uri.parse(
                                      'https://www.google.com/search?q=$query',
                                    );
                                    if (await canLaunchUrl(url)) {
                                      await launchUrl(
                                        url,
                                        mode: LaunchMode.externalApplication,
                                      );
                                    }
                                  },
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  isAlreadyAdded
                                      ? Icons.done
                                      : Icons.add_circle_outline,
                                  color: isAlreadyAdded ? Colors.green : null,
                                ),
                              ],
                            ),
                            onTap: isAlreadyAdded
                                ? null
                                : () {
                                    widget.onExerciseAdded(ex);
                                    Navigator.of(context).pop();
                                  },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
