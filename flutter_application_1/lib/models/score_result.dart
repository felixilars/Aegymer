class ScoreResult {
  final double score;
  final String explanation;
  final Map<String, double> breakdown;
  final List<String> reasons;

  const ScoreResult({
    required this.score,
    required this.explanation,
    this.breakdown = const {},
    this.reasons = const [],
  });
}