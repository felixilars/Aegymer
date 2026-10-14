import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aegymer/core/databases/app_database.dart';
import 'package:aegymer/core/utils/workout_cal.dart';
import 'package:aegymer/core/services/sync_service.dart';
import 'package:aegymer/core/services/streak_service.dart';
import 'package:aegymer/core/utils/url_launcher_helper.dart';

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
  final DateTime? initialDate;

  const ActiveWorkoutScreen({
    super.key,
    required this.db,
    this.routine,
    this.initialDate,
  });

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  final _notesController = TextEditingController();
  final _pageController = PageController();
  final _headerScrollController = ScrollController();

  Timer? _timer;
  int _secondsElapsed = 0;
  DateTime? _sessionStartTime;
  bool _isLoading = true;
  SharedPreferences? _prefs;

  Future<({String? mode, int? setCount, String? weightType})> _getSavedOrHistoricalOptions(
    String exerciseId,
  ) async {
    _prefs ??= await SharedPreferences.getInstance();

    final prefMode = _prefs?.getString('pref_ex_mode_$exerciseId');
    final prefSets = _prefs?.getInt('pref_ex_sets_$exerciseId');
    final prefWType = _prefs?.getString('pref_ex_wtype_$exerciseId');

    if (prefMode != null && prefSets != null) {
      return (mode: prefMode, setCount: prefSets, weightType: prefWType);
    }

    try {
      final query = widget.db.select(widget.db.workoutSets).join([
        innerJoin(
          widget.db.workoutSessions,
          widget.db.workoutSessions.id.equalsExp(widget.db.workoutSets.sessionId),
        ),
      ])
        ..where(widget.db.workoutSets.exerciseId.equals(exerciseId))
        ..orderBy([OrderingTerm.desc(widget.db.workoutSessions.date)]);

      final rows = await query.get();
      if (rows.isNotEmpty) {
        final latestSessionId = rows.first.readTable(widget.db.workoutSets).sessionId;
        final latestSets = rows
            .map((r) => r.readTable(widget.db.workoutSets))
            .where((s) => s.sessionId == latestSessionId)
            .toList();

        if (latestSets.isNotEmpty) {
          final count = latestSets.length;
          final first = latestSets.first;
          final wType = first.weightType;

          String inferredMode = 'weight_reps';
          if (wType == 'added') {
            inferredMode = 'bodyweight_weighted';
          } else if (wType == 'assisted') {
            inferredMode = 'bodyweight_assisted';
          } else if (wType == 'bodyweight') {
            inferredMode = 'bodyweight';
          } else if (first.distance != null && (first.distance ?? 0.0) > 0) {
            inferredMode = 'cardio_time';
          } else if (first.durationSeconds != null &&
              (first.durationSeconds ?? 0) > 0 &&
              first.weight == 0 &&
              first.reps == (first.durationSeconds ?? 0)) {
            inferredMode = 'time_only';
          }

          final finalMode = prefMode ?? inferredMode;
          final finalCount = prefSets ?? count;
          final finalWType = prefWType ?? wType;

          await _prefs?.setString('pref_ex_mode_$exerciseId', finalMode);
          await _prefs?.setInt('pref_ex_sets_$exerciseId', finalCount);
          if (finalWType != null) {
            await _prefs?.setString('pref_ex_wtype_$exerciseId', finalWType);
          }

          return (
            mode: finalMode,
            setCount: finalCount,
            weightType: finalWType,
          );
        }
      }
    } catch (e) {
      debugPrint('Error retrieving historical exercise options: $e');
    }

    return (mode: prefMode, setCount: prefSets, weightType: prefWType);
  }

  Future<void> _saveExerciseOptions({
    required String exerciseId,
    String? mode,
    int? setCount,
    String? weightType,
  }) async {
    _prefs ??= await SharedPreferences.getInstance();
    if (mode != null) {
      await _prefs!.setString('pref_ex_mode_$exerciseId', mode);
    }
    if (setCount != null && setCount > 0) {
      await _prefs!.setInt('pref_ex_sets_$exerciseId', setCount);
    }
    if (weightType != null) {
      await _prefs!.setString('pref_ex_wtype_$exerciseId', weightType);
    }
  }
  late DateTime _workoutDate = widget.initialDate ?? DateTime.now();

  bool get _isPastDate {
    final now = DateTime.now();
    return _workoutDate.year != now.year ||
        _workoutDate.month != now.month ||
        _workoutDate.day != now.day;
  }

  String get _formattedWorkoutDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay =
        DateTime(_workoutDate.year, _workoutDate.month, _workoutDate.day);
    final diff = today.difference(selectedDay).inDays;
    final day = _workoutDate.day.toString().padLeft(2, '0');
    final month = _workoutDate.month.toString().padLeft(2, '0');
    final dateStr = '$day/$month/${_workoutDate.year}';
    if (diff == 0) return 'Today ($dateStr)';
    if (diff == 1) return 'Yesterday ($dateStr)';
    return dateStr;
  }

  Future<void> _pickWorkoutDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _workoutDate.isAfter(now) ? now : _workoutDate,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: 'Select Workout Date',
    );
    if (picked != null) {
      setState(() {
        _workoutDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _workoutDate.hour,
          _workoutDate.minute,
        );
      });
    }
  }

  // Active workout exercises and their sets
  List<Exercise> _sessionExercises = [];
  final Map<String, List<LocalWorkoutSet>> _exerciseSets = {};

  // Active tracking type per exercise
  final Map<String, String> _activeTrackingTypes = {};

  // Barbell state maps per exercise
  final Map<String, bool> _useBarbell = {};
  final Map<String, double> _barbellWeight = {};
  final Map<String, TextEditingController> _barbellWeightControllers = {};

  // Bodyweight state maps per exercise
  final Map<String, double> _exerciseBodyweight = {};
  final Map<String, TextEditingController> _bodyweightControllers = {};

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
    for (final controller in _bodyweightControllers.values) {
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
    _sessionStartTime ??= DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        final elapsed = DateTime.now().difference(_sessionStartTime!).inSeconds;
        setState(() {
          _secondsElapsed = elapsed;
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

    _prefs = await SharedPreferences.getInstance();

    // 4. Init sets and tracking types
    for (final ex in _sessionExercises) {
      final opts = await _getSavedOrHistoricalOptions(ex.id);
      final initialType = opts.mode ??
          WorkoutCalculator.normalizeTrackingType(
            ex.trackingType,
            name: ex.name,
            targetMuscle: ex.targetMuscle,
            equipment: ex.equipment,
          );
      _activeTrackingTypes[ex.id] = initialType;
      _initSetsForExercise(
        ex,
        explicitSetCount: opts.setCount,
        explicitWeightType: opts.weightType,
      );
    }

    setState(() {
      _isLoading = false;
    });
  }  
  
  void _initSetsForExercise(
    Exercise ex, {
    int? explicitSetCount,
    String? explicitWeightType,
  }) {
    final String trackingType = _activeTrackingTypes[ex.id] ?? 'weight_reps';
    final double initW = WorkoutCalculator.getDefaultInputWeight(trackingType);

    int setsCount;
    if (explicitSetCount != null && explicitSetCount > 0) {
      setsCount = explicitSetCount;
    } else if (_prefs != null && _prefs!.containsKey('pref_ex_sets_${ex.id}')) {
      setsCount = _prefs!.getInt('pref_ex_sets_${ex.id}') ??
          ((trackingType == 'cardio_time') ? 1 : 3);
      if (setsCount <= 0) setsCount = 1;
    } else {
      setsCount = (trackingType == 'cardio_time') ? 1 : 3;
    }

    String wType = explicitWeightType ?? 'standard';
    if (trackingType == 'bodyweight') {
      wType = 'bodyweight';
    } else if (trackingType == 'bodyweight_weighted') {
      wType = explicitWeightType ?? _prefs?.getString('pref_ex_wtype_${ex.id}') ?? 'added';
      if (wType != 'bodyweight' && wType != 'added') {
        wType = 'added';
      }
    } else if (trackingType == 'bodyweight_assisted') {
      wType = explicitWeightType ?? _prefs?.getString('pref_ex_wtype_${ex.id}') ?? 'assisted';
      if (wType != 'bodyweight' && wType != 'assisted') {
        wType = 'assisted';
      }
    } else {
      wType = 'standard';
    }

    final oldSets = _exerciseSets[ex.id];
    if (oldSets != null) {
      for (final s in oldSets) {
        s.dispose();
      }
    }

    _exerciseSets[ex.id] = List.generate(setsCount, (index) {
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
    _saveExerciseOptions(
      exerciseId: exerciseId,
      setCount: _exerciseSets[exerciseId]?.length,
    );
  }

  void _removeLastSet(String exerciseId) {
    final sets = _exerciseSets[exerciseId] ?? [];
    if (sets.isEmpty) return;

    setState(() {
      final removed = sets.last;
      _exerciseSets[exerciseId] = List.from(sets)..removeLast();
      removed.dispose();
    });
    _saveExerciseOptions(
      exerciseId: exerciseId,
      setCount: _exerciseSets[exerciseId]?.length,
    );
  }

  void _removeExerciseFromSession(Exercise ex) {
    final sets = _exerciseSets[ex.id] ?? [];
    final bool hasData = sets.any((s) =>
        (double.tryParse(s.weightController.text) ?? 0.0) > 0 ||
        (int.tryParse(s.repsController.text) ?? 0) > 0 ||
        (double.tryParse(s.distanceController.text) ?? 0.0) > 0 ||
        s.durationInSeconds > 0);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove "${ex.name}"?'),
        content: Text(
          hasData
              ? 'Are you sure you want to remove "${ex.name}" from this workout? All entered sets and progress for this exercise will be discarded.'
              : 'Are you sure you want to remove "${ex.name}" from this workout session?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _performRemoveExercise(ex);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _performRemoveExercise(Exercise ex) {
    final indexToRemove = _sessionExercises.indexWhere((e) => e.id == ex.id);
    if (indexToRemove == -1) return;

    setState(() {
      final sets = _exerciseSets.remove(ex.id) ?? [];
      for (final s in sets) {
        s.dispose();
      }
      _barbellWeightControllers.remove(ex.id)?.dispose();
      _bodyweightControllers.remove(ex.id)?.dispose();
      _useBarbell.remove(ex.id);
      _barbellWeight.remove(ex.id);
      _exerciseBodyweight.remove(ex.id);
      _exerciseStopwatchSeconds.remove(ex.id);
      _exerciseStopwatchRunning.remove(ex.id);
      _activeTrackingTypes.remove(ex.id);
      _sessionExercises.removeAt(indexToRemove);

      if (_sessionExercises.isEmpty) {
        _currentPageIndex = 0;
      } else if (_currentPageIndex >= _sessionExercises.length) {
        _currentPageIndex = _sessionExercises.length - 1;
      }
    });

    if (_sessionExercises.isNotEmpty && _pageController.hasClients) {
      _pageController.jumpToPage(_currentPageIndex);
      _scrollToHeaderIndicator(_currentPageIndex);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed "${ex.name}" from workout.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _replaceExerciseInSession(Exercise currentEx) {
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
          sheetTitle: 'Replace "${currentEx.name}"',
          onExerciseAdded: (newEx) {
            _performReplaceExercise(currentEx, newEx);
          },
          onExerciseRemoved: (ex) {
            _performRemoveExercise(ex);
          },
          db: widget.db,
        );
      },
    );
  }

  Future<void> _performReplaceExercise(Exercise oldEx, Exercise newEx) async {
    if (oldEx.id == newEx.id) return;
    final index = _sessionExercises.indexWhere((e) => e.id == oldEx.id);
    if (index == -1) return;

    if (_sessionExercises.any((e) => e.id == newEx.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${newEx.name}" is already in this workout session.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final opts = await _getSavedOrHistoricalOptions(newEx.id);
    if (!mounted) return;

    setState(() {
      final sets = _exerciseSets.remove(oldEx.id) ?? [];
      for (final s in sets) {
        s.dispose();
      }
      _barbellWeightControllers.remove(oldEx.id)?.dispose();
      _bodyweightControllers.remove(oldEx.id)?.dispose();
      _useBarbell.remove(oldEx.id);
      _barbellWeight.remove(oldEx.id);
      _exerciseBodyweight.remove(oldEx.id);
      _exerciseStopwatchSeconds.remove(oldEx.id);
      _exerciseStopwatchRunning.remove(oldEx.id);
      _activeTrackingTypes.remove(oldEx.id);

      _sessionExercises[index] = newEx;
      final initialType = opts.mode ??
          WorkoutCalculator.normalizeTrackingType(
            newEx.trackingType,
            name: newEx.name,
            targetMuscle: newEx.targetMuscle,
            equipment: newEx.equipment,
          );
      _activeTrackingTypes[newEx.id] = initialType;
      _initSetsForExercise(
        newEx,
        explicitSetCount: opts.setCount,
        explicitWeightType: opts.weightType,
      );
      _currentPageIndex = index;
    });

    if (_pageController.hasClients) {
      _pageController.jumpToPage(_currentPageIndex);
      _scrollToHeaderIndicator(_currentPageIndex);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Replaced "${oldEx.name}" with "${newEx.name}".'),
        duration: const Duration(seconds: 2),
      ),
    );
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
      final double userBodyweight =
          _exerciseBodyweight[ex.id] ?? (_userProfile?.weight ?? 70.0);

      final bool useBar = _useBarbell[ex.id] ?? false;
      final double barW = _barbellWeight[ex.id] ?? 20.0;

      for (int i = 0; i < sets.length; i++) {
        final localSet = sets[i];
        final weight = double.tryParse(localSet.weightController.text) ?? 0.0;
        final reps = int.tryParse(localSet.repsController.text) ?? 0;
        double distanceVal =
            double.tryParse(localSet.distanceController.text) ?? 0.0;
        int durationVal = localSet.durationInSeconds;

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
          if (isCompleted) {
            // If duration was omitted by user, infer from session elapsed time or distance
            if (durationVal <= 0) {
              if (_secondsElapsed > 0) {
                durationVal = _secondsElapsed;
              } else if (distanceVal > 0) {
                durationVal = ((distanceVal / 8.5) * 3600).round();
              }
            } else if (distanceVal <= 0) {
              final nameLower = ex.name.toLowerCase();
              if (nameLower.contains('cycl') || nameLower.contains('bike')) {
                distanceVal = (durationVal / 3600.0) * 20.0;
              } else if (nameLower.contains('walk')) {
                distanceVal = (durationVal / 3600.0) * 5.0;
              } else {
                distanceVal = (durationVal / 3600.0) * 8.5;
              }
            }
          }
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
            exerciseName: ex.name,
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
                  : (wType == 'bodyweight' || wType == 'added' || wType == 'assisted'
                      ? effWeight
                      : actualWeight),
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
                  ? Value(durationVal > 0 ? durationVal : null)
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
        title: Text(_isPastDate ? 'Save Past Workout?' : 'Finish Workout?'),
        content: Text(
          _isPastDate
              ? 'Save this workout session for $_formattedWorkoutDate?'
              : 'Are you sure you want to finish this workout and save the history?',
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

      final setsNeedingDuration = setsCompanions
          .where((s) => !s.durationSeconds.present || s.durationSeconds.value == null || s.durationSeconds.value == 0)
          .length;

      // In real-world strength training, each set (work + recovery rest) averages 90-120 seconds.
      // If elapsed time is very small (e.g. quick entry or past date log), estimate 90s per set minimum
      // so calories are not artificially deflated by an unrealistically tiny duration.
      final minExpectedDuration = setsNeedingDuration * 90;
      final int effectiveSessionSeconds = (_isPastDate || _secondsElapsed < minExpectedDuration)
          ? max(_secondsElapsed, minExpectedDuration)
          : _secondsElapsed;

      final avgDuration = setsNeedingDuration > 0
          ? (effectiveSessionSeconds ~/ setsNeedingDuration)
          : 90;

      final finalCompanions = setsCompanions.map((set) {
        if (!set.durationSeconds.present || set.durationSeconds.value == null || set.durationSeconds.value == 0) {
          return set.copyWith(
            sessionId: Value(sessionId),
            durationSeconds: Value(avgDuration > 0 ? avgDuration : 90),
          );
        }
        return set.copyWith(sessionId: Value(sessionId));
      }).toList();

      await widget.db.saveWorkoutSession(
        sessionId: sessionId,
        date: _workoutDate,
        notes: _notesController.text.trim(),
        setsCompanions: finalCompanions,
      );

      StreakService.notifyWorkoutUpdated();

      for (final ex in _sessionExercises) {
        final sets = _exerciseSets[ex.id] ?? [];
        if (sets.isNotEmpty) {
          final activeType = _activeTrackingTypes[ex.id] ??
              WorkoutCalculator.normalizeTrackingType(
                ex.trackingType,
                name: ex.name,
                targetMuscle: ex.targetMuscle,
                equipment: ex.equipment,
              );
          final wType = sets.first.weightType;
          await _saveExerciseOptions(
            exerciseId: ex.id,
            mode: activeType,
            setCount: sets.length,
            weightType: wType,
          );
        }
      }

      double totalVolume = 0.0;
      double totalDistance = 0.0;
      double totalBurnedCalories = 0.0;
      final exMap = {for (var e in _sessionExercises) e.id: e};

      for (final companion in finalCompanions) {
        final w = companion.weight.value;
        final r = companion.reps.value;
        totalVolume += (w * r);

        final dist = companion.distance.present ? (companion.distance.value ?? 0.0) : 0.0;
        totalDistance += dist;

        final ex = exMap[companion.exerciseId.value];
        final exName = ex?.name ?? '';
        final tType = _activeTrackingTypes[companion.exerciseId.value] ??
            WorkoutCalculator.normalizeTrackingType(
              ex?.trackingType,
              name: exName,
              targetMuscle: ex?.targetMuscle ?? '',
              equipment: ex?.equipment ?? '',
            );

        final dur = companion.durationSeconds.present
            ? (companion.durationSeconds.value ?? avgDuration)
            : avgDuration;
        final cal = WorkoutCalculator.calculateSetCalories(
          exerciseName: exName,
          targetMuscle: ex?.targetMuscle ?? '',
          equipment: ex?.equipment ?? '',
          trackingType: tType,
          bodyweightKg: _userProfile?.weight ?? 70.0,
          weight: w,
          reps: r,
          distanceKm: dist,
          durationSeconds: dur,
        );
        totalBurnedCalories += cal;
      }

      if (mounted) {
        await _showPostWorkoutSummaryDialog(
          totalVolume: totalVolume,
          totalSets: finalCompanions.length,
          durationSeconds: _secondsElapsed > 0 ? _secondsElapsed : effectiveSessionSeconds,
          totalCalories: totalBurnedCalories,
          totalDistance: totalDistance,
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
    double totalCalories = 0.0,
    double totalDistance = 0.0,
  }) async {
    final List<Widget> statWidgets = [
      _buildSummaryStat('Duration', _formatDuration(durationSeconds), Icons.timer, Theme.of(context).colorScheme.primary),
      _buildSummaryStat('Burned', '${totalCalories.round()} kcal', Icons.local_fire_department, Colors.orange),
    ];

    if (totalDistance > 0) {
      statWidgets.add(
        _buildSummaryStat('Distance', '${totalDistance.toStringAsFixed(2)} km', Icons.directions_run, Colors.blueAccent),
      );
    }

    if (totalVolume > 0) {
      final volStr = totalVolume >= 1000
          ? '${(totalVolume / 1000).toStringAsFixed(1)}k kg'
          : '${totalVolume.toStringAsFixed(0)} kg';
      statWidgets.add(
        _buildSummaryStat('Volume', volStr, Icons.stacked_bar_chart, Colors.purpleAccent),
      );
    }

    statWidgets.add(
      _buildSummaryStat('Sets', '$totalSets', Icons.fitness_center, Colors.teal),
    );

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
              'Workout saved to history.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.spaceEvenly,
              spacing: 12,
              runSpacing: 12,
              children: statWidgets,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, IconData icon, Color iconColor) {
    return SizedBox(
      width: 78,
      child: Column(
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.routine?.routine.name ?? 'Free Workout',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Time: ${_formatDuration(_secondsElapsed)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.calendar_month_outlined,
              color: _isPastDate ? Colors.amber.shade700 : null,
            ),
            tooltip: 'Workout Date',
            onPressed: _pickWorkoutDate,
          ),
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Add Exercise',
            onPressed: _showAddExerciseSheet,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: _finishWorkout,
              child: const Text('Finish'),
            ),
          ),
        ],
      ),
      body: _sessionExercises.isEmpty
          ? _buildEmptyState()
          : Column(
              children: [
                if (_isPastDate)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF261E0F)
                          : const Color(0xFFFFFBEB),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.amber.shade700.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.history_rounded, size: 18, color: Colors.amber.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Past Workout: $_formattedWorkoutDate',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.amber.shade200
                                  : Colors.amber.shade900,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: _pickWorkoutDate,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            child: Text(
                              'Change Date',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.amber.shade300
                                    : Colors.amber.shade800,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
          // Title & Action Buttons
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
                onPressed: () => UrlLauncherHelper.openExerciseFormGuide(
                  context,
                  ex.name,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.swap_horiz_rounded, color: Colors.blue),
                tooltip: 'Replace Exercise',
                onPressed: () => _replaceExerciseInSession(ex),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                tooltip: 'Remove Exercise from Workout',
                onPressed: () => _removeExerciseFromSession(ex),
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

          // Bodyweight & Tonnage Options
          if (activeType == 'bodyweight' ||
              activeType == 'bodyweight_weighted' ||
              activeType == 'bodyweight_assisted') ...[
            _buildBodyweightOptions(ex, activeType),
            const SizedBox(height: 16.0),
          ],

          // Cardio Options
          if (activeType == 'cardio_time') ...[
            _buildCardioOptions(ex),
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
              hintText: _isPastDate
                  ? 'Enter notes for this past workout (feelings, injuries...)'
                  : 'Enter notes for today\'s workout (feelings, injuries...)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 20.0),
          Center(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () => _removeExerciseFromSession(ex),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Remove Exercise from Workout'),
            ),
          ),
          const SizedBox(height: 32.0),
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
                  padding: const EdgeInsets.only(left: 48.0, bottom: 4.0, right: 8.0),
                  child: Builder(
                    builder: (context) {
                      final sets = _exerciseSets[exerciseId] ?? [];
                      final firstSetWeight = sets.isNotEmpty
                          ? (double.tryParse(sets.first.weightController.text) ?? 0.0)
                          : 0.0;
                      final totalFirst = 2.0 * firstSetWeight + barW;
                      final text = firstSetWeight > 0
                          ? 'Example (Set 1): Total = ${LocalWorkoutSet.formatWeight(totalFirst)} kg (Bar ${LocalWorkoutSet.formatWeight(barW)} kg + 2 × ${LocalWorkoutSet.formatWeight(firstSetWeight)} kg/side)'
                          : 'Example formula: Total = Bar (${LocalWorkoutSet.formatWeight(barW)} kg) + (2 × weight/side)';
                      return Text(
                        text,
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

  Widget _buildBodyweightOptions(Exercise ex, String activeType) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBW = _userProfile?.weight ?? 70.0;

    if (!_exerciseBodyweight.containsKey(ex.id)) {
      _exerciseBodyweight[ex.id] = defaultBW;
    }
    final currentBW = _exerciseBodyweight[ex.id]!;

    if (!_bodyweightControllers.containsKey(ex.id)) {
      _bodyweightControllers[ex.id] = TextEditingController(
        text: LocalWorkoutSet.formatWeight(currentBW),
      );
    }
    final controller = _bodyweightControllers[ex.id]!;

    final factor = WorkoutCalculator.getBodyweightFactor(ex.name);
    final explanation = WorkoutCalculator.getBodyweightExplanation(ex.name);
    final baseLoad = currentBW * factor;

    return Card(
      elevation: 0,
      color: isDark ? Colors.white10 : Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.accessibility_new,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Bodyweight in workout:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                SizedBox(
                  width: 62,
                  height: 32,
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(vertical: 6),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (text) {
                      final val = double.tryParse(text);
                      if (val != null && val > 0) {
                        setState(() {
                          _exerciseBodyweight[ex.id] = val;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'kg',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.balance,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Tonnage load: $explanation • ~${LocalWorkoutSet.formatWeight(baseLoad)} kg/rep',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardioOptions(Exercise ex) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sets = _exerciseSets[ex.id] ?? [];

    double totalDist = 0.0;
    int totalDurSec = 0;
    for (var s in sets) {
      final d = double.tryParse(s.distanceController.text) ?? 0.0;
      totalDist += d;
      totalDurSec += s.durationInSeconds;
    }

    final double userWeight = _exerciseBodyweight[ex.id] ?? (_userProfile?.weight ?? 70.0);
    final double estimatedCalories = sets.fold<double>(0.0, (sum, s) {
      final d = double.tryParse(s.distanceController.text) ?? 0.0;
      final dur = s.durationInSeconds;
      return sum +
          WorkoutCalculator.calculateSetCalories(
            exerciseName: ex.name,
            targetMuscle: ex.targetMuscle,
            equipment: ex.equipment,
            trackingType: 'cardio_time',
            bodyweightKg: userWeight,
            distanceKm: d,
            durationSeconds: dur,
          );
    });

    String paceText = '--:-- min/km';
    String speedText = '';
    if (totalDist > 0 && totalDurSec > 0) {
      paceText = WorkoutCalculator.calculatePaceString(totalDist, totalDurSec);
      final speed = WorkoutCalculator.calculateSpeedKmh(totalDist, totalDurSec);
      speedText = ' • ${speed.toStringAsFixed(1)} km/h';
    }

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blueAccent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_run, size: 20, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cardio Metrics & Energy Expenditure',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department, size: 14, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      '~${estimatedCalories.round()} kcal',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.speed,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    totalDist > 0 || totalDurSec > 0
                        ? 'Total: ${totalDist.toStringAsFixed(2)} km • ${totalDurSec ~/ 60}m ${totalDurSec % 60}s • Pace: $paceText$speedText'
                        : 'Log distance and duration below.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
              onChanged: (_) => setState(() {}),
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
              onChanged: (_) => setState(() {}),
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
                _saveExerciseOptions(
                  exerciseId: exerciseId,
                  weightType: val,
                );
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
          final currentSetsCount = _exerciseSets[ex.id]?.length;
          setState(() {
            _activeTrackingTypes[ex.id] = type;
            // Re-initialize sets layout for this exercise preserving set count
            _initSetsForExercise(ex, explicitSetCount: currentSetsCount);
          });
          _saveExerciseOptions(
            exerciseId: ex.id,
            mode: type,
            setCount: currentSetsCount,
          );
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
          onExerciseAdded: (ex) async {
            final opts = await _getSavedOrHistoricalOptions(ex.id);
            if (!mounted) return;
            setState(() {
              if (!_sessionExercises.any((e) => e.id == ex.id)) {
                _sessionExercises.add(ex);
                final initialType = opts.mode ??
                    WorkoutCalculator.normalizeTrackingType(
                      ex.trackingType,
                      name: ex.name,
                      targetMuscle: ex.targetMuscle,
                      equipment: ex.equipment,
                    );
                _activeTrackingTypes[ex.id] = initialType;
                _initSetsForExercise(
                  ex,
                  explicitSetCount: opts.setCount,
                  explicitWeightType: opts.weightType,
                );
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
          onExerciseRemoved: (ex) {
            _performRemoveExercise(ex);
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
  final Function(Exercise)? onExerciseRemoved;
  final String? sheetTitle;
  final AppDatabase db;

  const _AddExerciseSheet({
    required this.allExercises,
    required this.currentSessionExercises,
    required this.onExerciseAdded,
    this.onExerciseRemoved,
    this.sheetTitle,
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

  Future<void> _confirmDeleteCustomExercise(Exercise ex) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${ex.name}"?'),
        content: const Text(
          'This will permanently delete this custom exercise from your library.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await (widget.db.delete(widget.db.exercises)
            ..where((tbl) => tbl.id.equals(ex.id)))
          .go();
      setState(() {
        _filteredExercises.removeWhere((e) => e.id == ex.id);
        widget.allExercises.removeWhere((e) => e.id == ex.id);
      });
      if (widget.currentSessionExercises.any((e) => e.id == ex.id)) {
        widget.onExerciseRemoved?.call(ex);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${ex.name}" from library.')),
        );
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
                  Text(
                    widget.sheetTitle ?? 'Add Exercise to Session',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
                                  onPressed: () =>
                                      UrlLauncherHelper.openExerciseFormGuide(
                                    context,
                                    ex.name,
                                  ),
                                ),
                                if (ex.isCustom)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.redAccent,
                                      size: 20,
                                    ),
                                    tooltip: 'Delete custom exercise',
                                    onPressed: () =>
                                        _confirmDeleteCustomExercise(ex),
                                  ),
                                if (isAlreadyAdded &&
                                    widget.onExerciseRemoved != null)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                      color: Colors.red,
                                      size: 22,
                                    ),
                                    tooltip: 'Remove from session',
                                    onPressed: () {
                                      widget.onExerciseRemoved!(ex);
                                      setState(() {});
                                    },
                                  )
                                else
                                  Icon(
                                    isAlreadyAdded
                                        ? Icons.done
                                        : Icons.add_circle_outline,
                                    color: isAlreadyAdded ? Colors.green : null,
                                  ),
                              ],
                            ),
                            onTap: isAlreadyAdded
                                ? () {
                                    if (widget.onExerciseRemoved != null) {
                                      widget.onExerciseRemoved!(ex);
                                      setState(() {});
                                    }
                                  }
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
