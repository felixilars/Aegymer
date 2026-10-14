enum MealContext {
  breakfast(
    calorieRatio: 0.20,
    proteinRatio: 0.20,
    carbRatio: 0.25,
    fatRatio: 0.20,
    displayName: 'Breakfast',
  ),
  lunch(
    calorieRatio: 0.35,
    proteinRatio: 0.35,
    carbRatio: 0.35,
    fatRatio: 0.35,
    displayName: 'Lunch',
  ),
  dinner(
    calorieRatio: 0.35,
    proteinRatio: 0.35,
    carbRatio: 0.30,
    fatRatio: 0.35,
    displayName: 'Dinner',
  ),
  snack(
    calorieRatio: 0.10,
    proteinRatio: 0.10,
    carbRatio: 0.10,
    fatRatio: 0.10,
    displayName: 'Snack',
  );

  final double calorieRatio;
  final double proteinRatio;
  final double carbRatio;
  final double fatRatio;
  final String displayName;

  const MealContext({
    required this.calorieRatio,
    required this.proteinRatio,
    required this.carbRatio,
    required this.fatRatio,
    required this.displayName,
  });
}