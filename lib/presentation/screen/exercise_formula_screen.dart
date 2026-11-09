import 'package:flutter/material.dart';

import 'package:aegymer/core/databases/app_database.dart';
import 'package:aegymer/core/utils/exercise_formula.dart';
import 'package:aegymer/core/utils/workout_cal.dart';

/// Lets the user write their own load and calorie formulas for one exercise,
/// e.g. a leg press whose sled angle and weight differ from gym to gym.
class ExerciseFormulaScreen extends StatefulWidget {
  final AppDatabase db;
  final Exercise exercise;
  final String trackingType;

  const ExerciseFormulaScreen({
    super.key,
    required this.db,
    required this.exercise,
    required this.trackingType,
  });

  @override
  State<ExerciseFormulaScreen> createState() => _ExerciseFormulaScreenState();
}

class _ExerciseFormulaScreenState extends State<ExerciseFormulaScreen> {
  final _loadController = TextEditingController();
  final _kcalController = TextEditingController();
  final _loadFocus = FocusNode();
  final _kcalFocus = FocusNode();
  TextEditingController? _lastFocused;

  String _savedLoad = '';
  String _savedKcal = '';
  double _bodyweight = 70.0;
  bool _loading = true;
  bool _saving = false;

  bool get _isCardio => widget.trackingType == 'cardio_time';
  bool get _isTimed => widget.trackingType == 'time_only';

  // Sample set used for the live previews.
  double get _sampleWeight => (_isCardio || _isTimed) ? 0 : 100;
  int get _sampleReps => _isCardio ? 1 : (_isTimed ? 60 : 10);
  int get _sampleSeconds => _isCardio ? 1800 : (_isTimed ? 60 : 90);
  double get _sampleKm => _isCardio ? 5 : 0;

  static const _loadExamples = [
    ('Leg press 45°, 30 kg sled', 'weight * sin(45) + 30'),
    ('Machine with 2:1 pulley', 'weight / 2'),
    ('Hack squat 45° + body', 'weight * sin(45) + bw * 0.7'),
  ];

  static const _kcalExamples = [
    ('Work done (~0.5 m per rep) + effort', '0.0047 * load * reps + 3.5 * 3.5 * bw / 200 * minutes'),
    ('MET 6 for the set duration', '6 * 3.5 * bw / 200 * minutes'),
    ('Fixed kcal per rep', '0.5 * reps'),
  ];

  @override
  void initState() {
    super.initState();
    _loadFocus.addListener(() {
      if (_loadFocus.hasFocus) _lastFocused = _loadController;
    });
    _kcalFocus.addListener(() {
      if (_kcalFocus.hasFocus) _lastFocused = _kcalController;
    });
    _load();
  }

  Future<void> _load() async {
    final row = await widget.db.getExerciseFormula(widget.exercise.id);
    final profile = await (widget.db.select(widget.db.userProfiles)..limit(1)).getSingleOrNull();
    if (!mounted) return;
    setState(() {
      _savedLoad = row?.loadFormula ?? '';
      _savedKcal = row?.kcalFormula ?? '';
      _loadController.text = _savedLoad;
      _kcalController.text = _savedKcal;
      final bw = profile?.weight ?? 0;
      _bodyweight = bw > 0 ? bw : 70.0;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _loadController.dispose();
    _kcalController.dispose();
    _loadFocus.dispose();
    _kcalFocus.dispose();
    super.dispose();
  }

  String? get _loadError => ExerciseFormula.validate(_loadController.text, isKcal: false);
  String? get _kcalError => ExerciseFormula.validate(_kcalController.text, isKcal: true);

  bool get _changed =>
      _loadController.text.trim() != _savedLoad.trim() ||
      _kcalController.text.trim() != _savedKcal.trim();

  SetFormulaResult _preview() {
    return ExerciseFormula.fromSource(load: _loadController.text, kcal: _kcalController.text).apply(
      weight: _sampleWeight,
      reps: _sampleReps,
      bodyweight: _bodyweight,
      durationSeconds: _sampleSeconds,
      distanceKm: _sampleKm,
    );
  }

  double get _defaultKcal => WorkoutCalculator.calculateSetCalories(
        exerciseName: widget.exercise.name,
        targetMuscle: widget.exercise.targetMuscle,
        equipment: widget.exercise.equipment,
        trackingType: widget.trackingType,
        bodyweightKg: _bodyweight,
        weight: _sampleWeight,
        reps: _sampleReps,
        distanceKm: _sampleKm,
        durationSeconds: _sampleSeconds,
      );

  String get _sampleText {
    final mins = _sampleSeconds / 60;
    final m = mins == mins.roundToDouble() ? mins.toStringAsFixed(0) : mins.toStringAsFixed(1);
    if (_isCardio) return 'Sample: ${_fmt(_sampleKm)} km in $m min, body weight ${_fmt(_bodyweight)} kg';
    if (_isTimed) return 'Sample: $m min hold, body weight ${_fmt(_bodyweight)} kg';
    return 'Sample: ${_fmt(_sampleWeight)} kg × $_sampleReps reps, $m min, body weight ${_fmt(_bodyweight)} kg';
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(v.abs() < 10 ? 2 : 1);

  void _insert(String text) {
    final c = _lastFocused ?? _loadController;
    final sel = c.selection;
    final start = sel.isValid ? sel.start : c.text.length;
    final end = sel.isValid ? sel.end : c.text.length;
    final newText = c.text.replaceRange(start, end, text);
    // Put the cursor inside "()" for functions.
    final caret = start + (text.endsWith('()') ? text.length - 1 : text.length);
    c.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: caret));
    (c == _kcalController ? _kcalFocus : _loadFocus).requestFocus();
    setState(() {});
  }

  Future<void> _save() async {
    if (_loadError != null || _kcalError != null) return;
    if (!_changed) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    final id = widget.exercise.id;
    await widget.db.saveExerciseFormula(id, load: _loadController.text, kcal: _kcalController.text);

    final pastSets = await widget.db.countSetsForExercise(id);
    var recalculated = 0;
    if (pastSets > 0 && mounted) {
      final recompute = await _askApplyToHistory(pastSets);
      if (recompute == true) {
        recalculated = await widget.db.recomputeFormulaHistory(id);
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(recalculated > 0
          ? 'Formula saved. Recalculated $recalculated past sets.'
          : 'Formula saved. It applies to sets you log from now on.'),
    ));
    Navigator.of(context).pop(true);
  }

  Future<bool?> _askApplyToHistory(int pastSets) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apply to past workouts?'),
        content: Text(
          'You have $pastSets logged sets of ${widget.exercise.name}.\n\n'
          'Keeping them leaves your history exactly as it was. Recalculating '
          'rewrites their load, e1RM and calories with the new formula, '
          'using your current body weight.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Recalculate $pastSets sets'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Only new sets'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Custom formula'),
            Text(widget.exercise.name, style: theme.textTheme.bodySmall),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _loading
                ? null
                : () => setState(() {
                      _loadController.clear();
                      _kcalController.clear();
                    }),
            child: const Text('Use defaults'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Text(
                  'Write your own formulas for this exercise. Leave a field blank '
                  'to use the app\'s default.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                if (!_isCardio && !_isTimed) ...[
                  _section(
                    title: 'Load (kg)',
                    subtitle: 'Counted for volume, e1RM and progress charts. Default: weight',
                    controller: _loadController,
                    focus: _loadFocus,
                    hint: 'weight',
                    error: _loadError,
                    preview: _loadPreviewText(),
                    examples: _loadExamples,
                  ),
                  const SizedBox(height: 20),
                ],
                _section(
                  title: 'Calories (kcal per set)',
                  subtitle: 'Used in workout summaries, history and streak stats.',
                  controller: _kcalController,
                  focus: _kcalFocus,
                  hint: 'built-in estimate',
                  error: _kcalError,
                  preview: _kcalPreviewText(),
                  examples: _kcalExamples,
                ),
                const SizedBox(height: 20),
                _buildVariableChips(theme),
                const SizedBox(height: 12),
                Text(_sampleText, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: (_saving || _loadError != null || _kcalError != null) ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save formula'),
                ),
              ],
            ),
    );
  }

  String _loadPreviewText() {
    if (_loadController.text.trim().isEmpty) {
      return 'Load = ${_fmt(_sampleWeight)} kg (default)';
    }
    final load = _preview().load;
    return load == null ? 'Result is not a number (e.g. division by zero): default is used'
        : 'Load = ${_fmt(load)} kg';
  }

  String _kcalPreviewText() {
    final def = _defaultKcal;
    if (_kcalController.text.trim().isEmpty) {
      return '${_fmt(def)} kcal per set (default)';
    }
    final kcal = _preview().kcal;
    return kcal == null ? 'Result is not a number (e.g. division by zero): default is used'
        : '${_fmt(kcal)} kcal per set (default would be ${_fmt(def)})';
  }

  Widget _section({
    required String title,
    required String subtitle,
    required TextEditingController controller,
    required FocusNode focus,
    required String hint,
    required String? error,
    required String preview,
    required List<(String, String)> examples,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focus,
          onChanged: (_) => setState(() {}),
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.visiblePassword, // plain ASCII keyboard
          style: const TextStyle(fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: hint,
            errorText: error,
            errorMaxLines: 3,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        if (error == null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(preview, style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
          ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 0,
          children: [
            for (final (label, formula) in examples)
              ActionChip(
                label: Text(label, style: const TextStyle(fontSize: 12)),
                tooltip: formula,
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() {
                  controller.text = formula;
                  controller.selection = TextSelection.collapsed(offset: formula.length);
                }),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildVariableChips(ThemeData theme) {
    const vars = [
      ('weight', 'weight entered (kg)'),
      ('reps', 'repetitions'),
      ('bw', 'your body weight (kg)'),
      ('minutes', 'set duration'),
      ('km', 'distance'),
      ('load', 'result of the load formula (calories only)'),
    ];
    const funcs = ['sin()', 'cos()', 'sqrt()', 'min()', 'max()', '^'];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tap to insert', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                for (final (name, help) in vars)
                  ActionChip(
                    label: Text(name, style: const TextStyle(fontFamily: 'monospace')),
                    tooltip: help,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _insert(name),
                  ),
                for (final f in funcs)
                  ActionChip(
                    label: Text(f, style: const TextStyle(fontFamily: 'monospace')),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _insert(f),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Angles are in degrees: sin(45) ≈ 0.71. For bodyweight exercises, weight is '
              'the load already including your body weight. Negative results count as 0.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
