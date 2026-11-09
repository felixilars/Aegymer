import 'package:aegymer/core/utils/formula_expression.dart';

/// Load and calorie values a custom formula produced for one set. A null
/// field means "no custom value": use the stored weight / built-in estimate.
class SetFormulaResult {
  final double? load;
  final double? kcal;
  const SetFormulaResult({this.load, this.kcal});
}

/// A user's custom load and/or calorie formula for one exercise, compiled.
///
/// Variables (all per set):
///   weight  – the weight entered (total for barbell/dumbbell; for bodyweight
///             exercises, the stored effective load including body weight)
///   reps    – repetitions
///   bw      – the user's body weight in kg
///   minutes – set duration (entered, or estimated for strength sets)
///   km      – distance (cardio)
///   load    – the result of the load formula (calorie formula only)
class ExerciseFormula {
  static const Set<String> loadVariables = {'weight', 'reps', 'bw', 'minutes', 'km'};
  static const Set<String> kcalVariables = {...loadVariables, 'load'};

  final FormulaExpression? load;
  final FormulaExpression? kcal;

  const ExerciseFormula({this.load, this.kcal});

  bool get isEmpty => load == null && kcal == null;

  /// Compiles stored formula text. Blank or invalid text is ignored (treated
  /// as "use the default"), so a bad formula can never break saving.
  factory ExerciseFormula.fromSource({String? load, String? kcal}) {
    return ExerciseFormula(
      load: _tryParse(load, loadVariables),
      kcal: _tryParse(kcal, kcalVariables),
    );
  }

  /// Returns a user-facing error for [source], or null when it's valid or blank.
  static String? validate(String? source, {required bool isKcal}) {
    if (source == null || source.trim().isEmpty) return null;
    try {
      FormulaExpression.parse(source, variables: isKcal ? kcalVariables : loadVariables);
      return null;
    } on FormulaException catch (e) {
      return e.message;
    }
  }

  static FormulaExpression? _tryParse(String? source, Set<String> variables) {
    if (source == null || source.trim().isEmpty) return null;
    try {
      return FormulaExpression.parse(source, variables: variables);
    } on FormulaException {
      return null;
    }
  }

  /// Applies the formulas to one set. Negative results count as 0; results
  /// that aren't a number (e.g. division by zero) fall back to the default.
  SetFormulaResult apply({
    required double weight,
    required int reps,
    required double bodyweight,
    int durationSeconds = 0,
    double distanceKm = 0,
  }) {
    final vars = <String, double>{
      'weight': weight,
      'reps': reps.toDouble(),
      'bw': bodyweight,
      'minutes': durationSeconds / 60.0,
      'km': distanceKm,
    };

    final double? loadValue = load == null ? null : _clean(load!.evaluate(vars));
    vars['load'] = loadValue ?? weight;
    final double? kcalValue = kcal == null ? null : _clean(kcal!.evaluate(vars));
    return SetFormulaResult(load: loadValue, kcal: kcalValue);
  }

  static double? _clean(double v) => v.isFinite ? (v < 0 ? 0.0 : v) : null;
}
