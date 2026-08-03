import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/core/databases/app_database.dart';
import 'package:flutter_application_1/core/enums/meal_context.dart';
import 'package:flutter_application_1/core/repositories/FoodRepository.dart';
import 'package:flutter_application_1/core/repositories/MealRepository.dart';
import 'package:flutter_application_1/core/repositories/UserRepository.dart';
import 'package:flutter_application_1/core/services/Meal/amount/proportional_amount_calculator.dart';
import 'package:flutter_application_1/core/services/Meal/meal_recommendation_service.dart';
import 'package:flutter_application_1/core/services/Meal/scorer/heuristics/food_calories_scorer.dart';
import 'package:flutter_application_1/core/services/Meal/scorer/heuristics/food_macro_scorer.dart';
import 'package:flutter_application_1/core/services/Meal/scorer/heuristics/variety_scorer.dart';
import 'package:flutter_application_1/core/services/Meal/scorer/scorer.dart';
import 'package:flutter_application_1/core/services/food/openfoodfacts_service.dart';
import 'package:flutter_application_1/core/services/nutrition_service.dart';
import 'package:flutter_application_1/models/mealRec_helper/meal_recommendation.dart';
import 'package:flutter_application_1/models/mealRec_helper/remaining_meal_state.dart';
import 'package:flutter_application_1/models/mealitem_with_food.dart';
import 'package:flutter_application_1/models/nutrition_macros.dart';

class MealPrepPage extends StatefulWidget {
  final AppDatabase db;
  final MealRecommendationService? service;

  const MealPrepPage({super.key, required this.db, this.service});

  @override
  State<MealPrepPage> createState() => _MealPrepPageState();
}

class _MealPrepPageState extends State<MealPrepPage> {
  late final MealRecommendationService _service;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedCards = <String>{};

  Timer? _searchDebounce;
  bool _isInitialLoading = true;
  bool _isBusy = false;
  bool _isSearching = false;
  String? _error;
  int _recommendationVersion = 0;
  int _mealVersion = 0;

  MealContext _mealContext = MealContext.breakfast;
  RemainingMealState _remainingState = RemainingMealState(
    target: NutritionMacros(calories: 0, protein: 0, carbs: 0, fat: 0),
    consumed: NutritionMacros(calories: 0, protein: 0, carbs: 0, fat: 0),
    remaining: NutritionMacros(calories: 0, protein: 0, carbs: 0, fat: 0),
  );

  List<MealRecommendation> _recommendations = <MealRecommendation>[];
  List<MealItemWithFood> _loggedFoods = <MealItemWithFood>[];
  List<Food> _searchResults = <Food>[];
  MealContext? _userSelectedContext;

  @override
  void initState() {
    super.initState();
    _service =
        widget.service ??
        MealRecommendationService(
          MealRepository(widget.db),
          UserRepository(widget.db),
          FoodRepository(
            database: widget.db,
            openFoodFactsService: OpenFoodFactsService(),
          ),
          const ProportionalAmountCalculator(),
          Scorer(
            macroScorer: MacroScorer(),
            calorieScorer: CalorieScorer(),
            varietyScorer: VarietyScorer(),
          ),
        );
    _loadAllData();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData({bool showBusy = false}) async {
    if (!mounted) return;

    setState(() {
      _error = null;
      if (_isInitialLoading) {
        _isInitialLoading = true;
      } else {
        _isBusy = showBusy;
      }
    });

    try {
      final mealContext =
          _userSelectedContext ?? await _service.determineMealContext();
      final remainingState = await _service.calculateRemainingMealMacros(
        mealContext: mealContext,
      );
      final recommendations = await _service.recommendFoods(
        mealContext: mealContext,
        limit: 8,
      );
      final loggedFoods = await _service.getLoggedFoodsForCurrentMeal(
        mealContext: mealContext,
      );

      if (!mounted) return;

      setState(() {
        _mealContext = mealContext;
        _remainingState = remainingState;
        _recommendations = recommendations;
        _loggedFoods = loggedFoods;
        _recommendationVersion++;
        _mealVersion++;
        _isInitialLoading = false;
        _isBusy = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Error loading meal prep page data: $e\n$stackTrace');
      if (!mounted) return;

      setState(() {
        _error = 'Unable to load recommendations.\nPlease try again.';
        _isInitialLoading = false;
        _isBusy = false;
      });
    }
  }

  bool _recommendationsCollapsed = false;

  Future<void> _addRecommendationToMeal(
    MealRecommendation recommendation,
  ) async {
    await _service.addFoodToMeal(
      recommendation.food,
      mealContext: _mealContext,
      amount: recommendation.amount.grams,
    );
    await _loadAllData(showBusy: true);
  }

  Future<void> _addSearchResultToMeal(Food food) async {
    final double? selectedGrams = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _PortionQuantitySheet(food: food),
    );

    if (selectedGrams != null && selectedGrams > 0) {
      await _service.addFoodToMeal(
        food,
        mealContext: _mealContext,
        amount: selectedGrams,
      );
      await _loadAllData(showBusy: true);
    }
  }

  Future<void> _removeFromMeal(String mealItemId) async {
    await _service.removeFoodFromMeal(mealItemId);
    await _loadAllData(showBusy: true);
  }

  Future<void> _editMealItem(MealItemWithFood item) async {
    final double? newGrams = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _PortionQuantitySheet(
        food: item.food,
        initialGrams: item.mealItem.amount,
      ),
    );

    if (newGrams != null && newGrams > 0) {
      await _service.updateLoggedFoodAmount(item.mealItem.id, newGrams);
      await _loadAllData(showBusy: true);
    }
  }

  void _onSearchChanged(String input) {
    _searchDebounce?.cancel();
    final query = input.trim();

    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = <Food>[];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await _service.searchFoods(query);
        if (!mounted || _searchController.text.trim() != query) {
          return;
        }

        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _searchResults = <Food>[];
          _isSearching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(_mealContext.displayName), centerTitle: true),
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth > 860
                    ? 860.0
                    : constraints.maxWidth;
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      child: _buildBody(theme),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isBusy)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isInitialLoading) {
      return _LoadingState(theme: theme);
    }

    if (_error != null) {
      return _ErrorState(
        message: _error!,
        onRetry: () => _loadAllData(showBusy: true),
      );
    }

    return SingleChildScrollView(
      key: const ValueKey('content'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Meal Category Selector Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: MealContext.values.map((ctx) {
                final isSelected = ctx == _mealContext;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(ctx.displayName),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected && ctx != _mealContext) {
                        setState(() {
                          _userSelectedContext = ctx;
                        });
                        _loadAllData(showBusy: true);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          _MealSummaryCard(
            mealContext: _mealContext,
            target: _remainingState.target,
            remaining: _remainingState.remaining,
          ),
          const SizedBox(height: 16),
          _WaterTrackerCard(db: widget.db),
          const SizedBox(height: 16),
          _RemainingMacrosCard(
            target: _remainingState.target,
            remaining: _remainingState.remaining,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: _SectionHeader(
                  title: 'Recommended Foods',
                  subtitle: 'Best foods for this meal',
                ),
              ),
              IconButton(
                icon: Icon(
                  _recommendationsCollapsed
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_up,
                ),
                tooltip: _recommendationsCollapsed
                    ? 'Show Recommendations'
                    : 'Hide Recommendations',
                onPressed: () {
                  setState(() {
                    _recommendationsCollapsed = !_recommendationsCollapsed;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_recommendationsCollapsed)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: _recommendations.isEmpty
                  ? const _EmptyCard(
                      key: ValueKey('empty-recommendations'),
                      title: 'No recommendations available.',
                      message: 'Try searching for a food instead.',
                    )
                  : Column(
                      key: ValueKey<int>(_recommendationVersion),
                      children: _recommendations.map((recommendation) {
                        final isExpanded = _expandedCards.contains(
                          recommendation.food.id,
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _RecommendationCard(
                            recommendation: recommendation,
                            expanded: isExpanded,
                            onToggle: () {
                              setState(() {
                                if (isExpanded) {
                                  _expandedCards.remove(recommendation.food.id);
                                } else {
                                  _expandedCards.add(recommendation.food.id);
                                }
                              });
                            },
                            onAdd: () =>
                                _addRecommendationToMeal(recommendation),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          const SizedBox(height: 24),
          const _SectionHeader(
            title: 'Current Meal',
            subtitle: 'Foods already logged for this meal',
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: _loggedFoods.isEmpty
                ? const _EmptyCard(
                    key: ValueKey('empty-meal'),
                    title: 'Nothing has been logged for this meal.',
                    message:
                        'Start by selecting one of the recommendations below.',
                  )
                : Column(
                    key: ValueKey<int>(_mealVersion),
                    children: _loggedFoods.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _CurrentMealItemCard(
                          item: item,
                          onEdit: () => _editMealItem(item),
                          onRemove: () => _removeFromMeal(item.mealItem.id),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(
            title: 'Search Food',
            subtitle: 'Find foods and quickly add them to this meal',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search foods...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.35,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_searchController.text.trim().isEmpty)
            const _EmptyCard(
              title: 'Start typing to search for foods.',
              message: '',
            )
          else if (_searchResults.isEmpty && !_isSearching)
            const _EmptyCard(
              title: 'No foods found.',
              message: 'Try a different name or keyword.',
            )
          else
            Column(
              children: _searchResults
                  .map(
                    (food) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SearchFoodCard(
                        food: food,
                        onAdd: () => _addSearchResultToMeal(food),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _MealSummaryCard extends StatelessWidget {
  final MealContext mealContext;
  final NutritionMacros target;
  final NutritionMacros remaining;

  const _MealSummaryCard({
    required this.mealContext,
    required this.target,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final consumed = (target.calories - remaining.calories).clamp(
      0.0,
      double.infinity,
    );
    final progress = target.calories <= 0
        ? 0.0
        : (consumed / target.calories).clamp(0.0, 1.0);

    final pProgress = target.protein <= 0
        ? 0.0
        : ((target.protein - remaining.protein) / target.protein).clamp(
            0.0,
            1.0,
          );
    final cProgress = target.carbs <= 0
        ? 0.0
        : ((target.carbs - remaining.carbs) / target.carbs).clamp(0.0, 1.0);
    final fProgress = target.fat <= 0
        ? 0.0
        : ((target.fat - remaining.fat) / target.fat).clamp(0.0, 1.0);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  mealContext.displayName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(progress * 100).round()}% Completed',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                // Radial Macro Ring
                SizedBox(
                  width: 110,
                  height: 110,
                  child: CustomPaint(
                    painter: _RadialMacroPainter(
                      calProgress: progress,
                      pProgress: pProgress,
                      cProgress: cProgress,
                      fProgress: fProgress,
                      isDark: isDark,
                      primaryColor: theme.colorScheme.primary,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${remaining.calories.round()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'kcal left',
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: [
                      _MacroLegendRow(
                        color: theme.colorScheme.primary,
                        label: 'Calories',
                        value:
                            '${consumed.round()} / ${target.calories.round()} kcal',
                      ),
                      const SizedBox(height: 8),
                      _MacroLegendRow(
                        color: const Color(0xffFF6B35),
                        label: 'Protein',
                        value:
                            '${(target.protein - remaining.protein).round()} / ${target.protein.round()} g',
                      ),
                      const SizedBox(height: 8),
                      _MacroLegendRow(
                        color: const Color(0xffF59E0B),
                        label: 'Carbs',
                        value:
                            '${(target.carbs - remaining.carbs).round()} / ${target.carbs.round()} g',
                      ),
                      const SizedBox(height: 8),
                      _MacroLegendRow(
                        color: const Color(0xff10B981),
                        label: 'Fat',
                        value:
                            '${(target.fat - remaining.fat).round()} / ${target.fat.round()} g',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroLegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _MacroLegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _RadialMacroPainter extends CustomPainter {
  final double calProgress;
  final double pProgress;
  final double cProgress;
  final double fProgress;
  final bool isDark;
  final Color primaryColor;

  _RadialMacroPainter({
    required this.calProgress,
    required this.pProgress,
    required this.cProgress,
    required this.fProgress,
    required this.isDark,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = 6.0;

    void drawRing(double radius, double progress, Color color) {
      final bgPaint = Paint()
        ..color = isDark
            ? Colors.white10
            : Colors.black12.withValues(alpha: 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      final fgPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth;

      canvas.drawCircle(center, radius, bgPaint);
      if (progress > 0) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          -1.5708, // -90 degrees
          2 * 3.1415926535 * progress,
          false,
          fgPaint,
        );
      }
    }

    drawRing(48.0, calProgress, primaryColor);
    drawRing(40.0, pProgress, const Color(0xffFF6B35));
    drawRing(32.0, cProgress, const Color(0xffF59E0B));
    drawRing(24.0, fProgress, const Color(0xff10B981));
  }

  @override
  bool shouldRepaint(covariant _RadialMacroPainter oldDelegate) => true;
}

class _WaterTrackerCard extends StatefulWidget {
  final AppDatabase db;

  const _WaterTrackerCard({required this.db});

  @override
  State<_WaterTrackerCard> createState() => _WaterTrackerCardState();
}

class _WaterTrackerCardState extends State<_WaterTrackerCard> {
  int _intakeMl = 0;
  int _goalMl = 2450; // Dynamic default based on standard 70kg * 35ml

  String get _todayKey {
    final now = DateTime.now();
    return 'water_intake_${now.year}_${now.month}_${now.day}';
  }

  @override
  void initState() {
    super.initState();
    _loadUserWaterData();
  }

  Future<void> _loadUserWaterData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIntake = prefs.getInt(_todayKey) ?? 0;

      final profiles = await widget.db.select(widget.db.userProfiles).get();
      int goal = 2450;
      if (profiles.isNotEmpty) {
        final profile = profiles.first;
        final activityStr = profile.activityLevel >= 1.725
            ? 'Very Active'
            : profile.activityLevel >= 1.55
            ? 'Moderately Active'
            : profile.activityLevel >= 1.375
            ? 'Lightly Active'
            : 'Sedentary';
        goal = NutritionService().calculateDailyWaterTarget(
          weight: profile.weight,
          activityLevel: activityStr,
        );
      }
      if (mounted) {
        setState(() {
          _intakeMl = savedIntake;
          _goalMl = goal;
        });
      }
    } catch (_) {}
  }

  Future<void> _addWater(int amount) async {
    final newIntake = (_intakeMl + amount).clamp(0, 6000);
    setState(() {
      _intakeMl = newIntake;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_todayKey, newIntake);
    } catch (_) {}
  }

  Future<void> _resetWater() async {
    setState(() {
      _intakeMl = 0;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_todayKey, 0);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progress = (_intakeMl / _goalMl).clamp(0.0, 1.0);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      color: isDark
          ? Colors.blue.withValues(alpha: 0.1)
          : const Color(0xffEFF6FF),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.water_drop,
                        color: Colors.blue,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Water Intake',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$_intakeMl / $_goalMl ml (${(progress * 100).toInt()}%)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _resetWater,
                  child: const Text('Reset', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: isDark ? Colors.white10 : Colors.blue.shade100,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _addWater(250),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('+250 ml'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _addWater(500),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('+500 ml'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RemainingMacrosCard extends StatelessWidget {
  final NutritionMacros target;
  final NutritionMacros remaining;

  const _RemainingMacrosCard({required this.target, required this.remaining});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final cards = <_MacroCardData>[
      _MacroCardData(
        icon: Icons.local_fire_department_outlined,
        label: 'Calories',
        unit: 'kcal',
        remaining: remaining.calories,
        target: target.calories,
      ),
      _MacroCardData(
        icon: Icons.fitness_center_outlined,
        label: 'Protein',
        unit: 'g',
        remaining: remaining.protein,
        target: target.protein,
      ),
      _MacroCardData(
        icon: Icons.grain_outlined,
        label: 'Carbs',
        unit: 'g',
        remaining: remaining.carbs,
        target: target.carbs,
      ),
      _MacroCardData(
        icon: Icons.opacity_outlined,
        label: 'Fat',
        unit: 'g',
        remaining: remaining.fat,
        target: target.fat,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 560;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards.map((data) {
            final width = isWide
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return SizedBox(
              width: width,
              child: _MacroRemainingItem(data: data, theme: theme),
            );
          }).toList(),
        );
      },
    );
  }
}

class _MacroCardData {
  final IconData icon;
  final String label;
  final String unit;
  final double remaining;
  final double target;

  const _MacroCardData({
    required this.icon,
    required this.label,
    required this.unit,
    required this.remaining,
    required this.target,
  });
}

class _MacroRemainingItem extends StatelessWidget {
  final _MacroCardData data;
  final ThemeData theme;

  const _MacroRemainingItem({required this.data, required this.theme});

  @override
  Widget build(BuildContext context) {
    final satisfied = data.remaining <= 0;
    final consumed = (data.target - data.remaining).clamp(0, double.infinity);
    final progress = data.target <= 0
        ? 0.0
        : (consumed / data.target).clamp(0.0, 1.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: satisfied
            ? theme.colorScheme.tertiaryContainer.withValues(alpha: 0.65)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: satisfied
              ? theme.colorScheme.tertiary.withValues(alpha: 0.45)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(data.icon, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  data.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (satisfied)
                Icon(
                  Icons.check_circle,
                  size: 18,
                  color: theme.colorScheme.tertiary,
                ),
            ],
          ),
          const SizedBox(height: 10),
          _AnimatedNumberText(
            value: data.remaining,
            suffix: data.unit,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'remaining',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress),
            duration: const Duration(milliseconds: 450),
            builder: (context, value, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: value,
                  color: satisfied
                      ? theme.colorScheme.tertiary
                      : theme.colorScheme.primary,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatefulWidget {
  final MealRecommendation recommendation;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onAdd;

  const _RecommendationCard({
    required this.recommendation,
    required this.expanded,
    required this.onToggle,
    required this.onAdd,
  });

  @override
  State<_RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends State<_RecommendationCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = widget.recommendation.score.score.clamp(0.0, 100.0);
    final amount = widget.recommendation.amount;
    final scoreColor = _scoreColor(theme, score);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _pressed ? 0.10 : 0.04),
              blurRadius: _pressed ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          color: theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.recommendation.food.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${score.toStringAsFixed(0)} / 100',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scoreColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Recommended ${amount.grams.toStringAsFixed(0)} g',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                _MacroProvidedGrid(
                  calories: amount.macros.calories,
                  protein: amount.macros.protein,
                  carbs: amount.macros.carbs,
                  fat: amount.macros.fat,
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: widget.onToggle,
                  icon: Icon(
                    widget.expanded ? Icons.expand_less : Icons.expand_more,
                  ),
                  label: const Text('Why this food?'),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: widget.expanded
                      ? _RecommendationDetails(
                          key: const ValueKey('expanded'),
                          recommendation: widget.recommendation,
                        )
                      : const SizedBox.shrink(),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: widget.onAdd,
                    child: const Text('Add to Meal'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _scoreColor(ThemeData theme, double score) {
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.blue;
    if (score >= 60) return Colors.orange;
    return theme.colorScheme.outline;
  }
}

class _MacroProvidedGrid extends StatelessWidget {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  const _MacroProvidedGrid({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final items = <({String label, String value})>[
      (label: 'Calories', value: '${calories.toStringAsFixed(0)} kcal'),
      (label: 'Protein', value: '${protein.toStringAsFixed(0)} g'),
      (label: 'Carbs', value: '${carbs.toStringAsFixed(0)} g'),
      (label: 'Fat', value: '${fat.toStringAsFixed(0)} g'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 10,
          children: items
              .map(
                (item) => Container(
                  width: tileWidth,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.label, style: theme.textTheme.labelMedium),
                      const SizedBox(height: 4),
                      Text(
                        item.value,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _RecommendationDetails extends StatelessWidget {
  final MealRecommendation recommendation;

  const _RecommendationDetails({super.key, required this.recommendation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Score Breakdown',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...recommendation.score.breakdown.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(entry.key, style: theme.textTheme.bodySmall),
                  Text(
                    entry.value.toStringAsFixed(0),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Reasons',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...recommendation.score.reasons.map(
            (reason) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(reason, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentMealItemCard extends StatelessWidget {
  final MealItemWithFood item;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  const _CurrentMealItemCard({
    required this.item,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = item.mealItem.amount / 100.0;
    final calories = item.food.calories * ratio;
    final protein = item.food.protein * ratio;
    final carbs = item.food.carbs * ratio;
    final fat = item.food.fat * ratio;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.food.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.mealItem.amount.toStringAsFixed(0)} g',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${calories.toStringAsFixed(0)} kcal • P ${protein.toStringAsFixed(0)} • C ${carbs.toStringAsFixed(0)} • F ${fat.toStringAsFixed(0)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: onEdit,
                  tooltip: 'Edit portion',
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
                IconButton(
                  onPressed: onRemove,
                  tooltip: 'Remove food',
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchFoodCard extends StatelessWidget {
  final Food food;
  final VoidCallback onAdd;

  const _SearchFoodCard({required this.food, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${food.calories.toStringAsFixed(0)} kcal • P ${food.protein.toStringAsFixed(0)} • C ${food.carbs.toStringAsFixed(0)} • F ${food.fat.toStringAsFixed(0)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            FilledButton(onPressed: onAdd, child: const Text('Add')),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _AnimatedNumberText extends StatelessWidget {
  final double value;
  final String suffix;
  final TextStyle? style;

  const _AnimatedNumberText({
    required this.value,
    required this.suffix,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: const Duration(milliseconds: 420),
      builder: (context, current, child) {
        return Text('${current.toStringAsFixed(0)} $suffix', style: style);
      },
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyCard({super.key, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(message, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      key: const ValueKey('error'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 40,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  final ThemeData theme;

  const _LoadingState({required this.theme});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('loading'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonCard(theme: theme, height: 150),
          const SizedBox(height: 16),
          _SkeletonCard(theme: theme, height: 210),
          const SizedBox(height: 24),
          _SkeletonCard(theme: theme, height: 160),
          const SizedBox(height: 12),
          _SkeletonCard(theme: theme, height: 160),
          const SizedBox(height: 24),
          _SkeletonCard(theme: theme, height: 120),
          const SizedBox(height: 24),
          _SkeletonCard(theme: theme, height: 56),
          const SizedBox(height: 12),
          _SkeletonCard(theme: theme, height: 96),
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final ThemeData theme;
  final double height;

  const _SkeletonCard({required this.theme, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _PortionQuantitySheet extends StatefulWidget {
  final Food food;
  final double initialGrams;

  const _PortionQuantitySheet({required this.food, this.initialGrams = 100.0});

  @override
  State<_PortionQuantitySheet> createState() => _PortionQuantitySheetState();
}

class _PortionQuantitySheetState extends State<_PortionQuantitySheet> {
  late final TextEditingController _controller;
  late double _grams;

  @override
  void initState() {
    super.initState();
    _grams = widget.initialGrams;
    _controller = TextEditingController(text: _grams.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setGrams(double value) {
    setState(() {
      _grams = value;
      _controller.text = value.toStringAsFixed(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Select Portion: ${widget.food.name}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Select or enter amount in grams (g)',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [50.0, 100.0, 150.0, 200.0, 250.0].map((g) {
              final isSelected = _grams == g;
              return ChoiceChip(
                label: Text('${g.toInt()}g'),
                selected: isSelected,
                onSelected: (_) => _setGrams(g),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Portion Size (g)',
              border: OutlineInputBorder(),
              suffixText: 'grams',
            ),
            onChanged: (val) {
              final parsed = double.tryParse(val);
              if (parsed != null && parsed > 0) {
                _grams = parsed;
              }
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _grams),
              child: Text('Add ${_grams.toStringAsFixed(0)}g to Meal'),
            ),
          ),
        ],
      ),
    );
  }
}
