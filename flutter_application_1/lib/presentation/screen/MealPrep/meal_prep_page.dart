import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/databases/app_database.dart';
import 'package:flutter_application_1/core/enums/meal_context.dart';
import 'package:flutter_application_1/core/repositories/FoodRepository.dart';
import 'package:flutter_application_1/core/repositories/MealRepository.dart';
import 'package:flutter_application_1/core/repositories/UserRepository.dart';
import 'package:flutter_application_1/core/services/Meal/meal_recommendation_service.dart';
import 'package:flutter_application_1/core/services/Meal/scorer/heuristics/food_calories_scorer.dart';
import 'package:flutter_application_1/core/services/Meal/scorer/heuristics/food_macro_scorer.dart';
import 'package:flutter_application_1/core/services/Meal/scorer/heuristics/variety_scorer.dart';
import 'package:flutter_application_1/core/services/Meal/scorer/scorer.dart';
import 'package:flutter_application_1/core/services/food/openfoodfacts_service.dart';
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
  final Set<String> _expandedCards = {};

  bool _isLoading = true;
  bool _isSearching = false;
  bool _isRefreshing = false;
  String? _error;

  MealContext _mealContext = MealContext.breakfast;
  NutritionMacros _targetMacros = NutritionMacros(
    calories: 0,
    protein: 0,
    carbs: 0,
    fat: 0,
  );
  NutritionMacros _consumedMacros = NutritionMacros(
    calories: 0,
    protein: 0,
    carbs: 0,
    fat: 0,
  );
  List<MealRecommendation> _recommendations = [];
  List<MealItemWithFood> _loggedFoods = [];
  List<Food> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _service = widget.service ??
        MealRecommendationService(
          MealRepository(widget.db),
          UserRepository(widget.db),
          FoodRepository(
            database: widget.db,
            openFoodFactsService: OpenFoodFactsService(),
          ),
          Scorer(
            macroScorer: MacroScorer(),
            calorieScorer: CalorieScorer(),
            varietyScorer: VarietyScorer(),
          ),
        );
    _loadPage();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPage({bool refreshRecommendations = true}) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _isRefreshing = refreshRecommendations;
      _error = null;
    });

    try {
      final mealContext = await _service.determineMealContext();
      final targetMacros = await _service.calculateMealTarget(mealContext);
      final recommendations = refreshRecommendations
          ? await _service.recommendFoods(limit: 5)
          : _recommendations;
      final loggedFoods = await _service.getLoggedFoodsForCurrentMeal(
        mealContext: mealContext,
      );

      if (!mounted) return;

      setState(() {
        _mealContext = mealContext;
        _targetMacros = targetMacros;
        _recommendations = recommendations;
        _loggedFoods = loggedFoods;
        _consumedMacros = _sumMacros(loggedFoods);
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _error = 'Unable to load recommendations.';
      });
    }
  }

  Future<void> _refreshPage() async {
    await _loadPage(refreshRecommendations: true);
  }

  Future<void> _handleAddFood(Food food) async {
    await _service.addFoodToMeal(food, mealContext: _mealContext);
    await _refreshPage();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${food.name} added to ${_mealContext.displayName.toLowerCase()}.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleRemoveFood(String mealItemId) async {
    await _service.removeFoodFromMeal(mealItemId);
    await _refreshPage();
  }

  Future<void> _handleSearch(String value) async {
    if (value.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _service.searchFoods(value);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  NutritionMacros _sumMacros(List<MealItemWithFood> items) {
    double calories = 0;
    double protein = 0;
    double carbs = 0;
    double fat = 0;

    for (final item in items) {
      calories += item.food.calories;
      protein += item.food.protein;
      carbs += item.food.carbs;
      fat += item.food.fat;
    }

    return NutritionMacros(
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_mealContext.displayName),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _refreshPage,
            tooltip: 'Refresh recommendations',
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth > 700 ? 700.0 : constraints.maxWidth;

          return RefreshIndicator(
            onRefresh: _refreshPage,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: _buildContent(theme),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: FilledButton.icon(
            onPressed: _loggedFoods.isEmpty ? null : () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Meal plan updated.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Save meal'),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_isLoading && _recommendations.isEmpty) {
      return _buildLoadingState(theme);
    }

    if (_error != null) {
      return _buildErrorState(theme);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MealSummaryCard(
          mealContext: _mealContext,
          targetMacros: _targetMacros,
          consumedMacros: _consumedMacros,
        ),
        const SizedBox(height: 20),
        Text(
          'Recommended For You',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        if (_recommendations.isEmpty)
          _buildEmptyState(theme)
        else
          ..._recommendations.map((recommendation) {
            final isExpanded = _expandedCards.contains(recommendation.food.id);
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
                onAdd: () => _handleAddFood(recommendation.food),
              ),
            );
          }),
        const SizedBox(height: 24),
        Text(
          'Search Food',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          onChanged: _handleSearch,
          decoration: InputDecoration(
            hintText: 'Search food...',
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
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
          ),
        ),
        const SizedBox(height: 12),
        if (_searchController.text.trim().isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: _searchResults.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No matching foods found.'),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final food = _searchResults[index];
                      return _SearchResultTile(
                        food: food,
                        onAdd: () => _handleAddFood(food),
                      );
                    },
                  ),
          ),
        const SizedBox(height: 24),
        Text(
          'Today\'s ${_mealContext.displayName}',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        if (_loggedFoods.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'No foods added yet. Search for something delicious and add it to your meal.',
              style: theme.textTheme.bodyMedium,
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _loggedFoods.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = _loggedFoods[index];
              return Dismissible(
                key: ValueKey(item.mealItem.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Icon(Icons.delete_outline, color: theme.colorScheme.onErrorContainer),
                ),
                onDismissed: (_) => _handleRemoveFood(item.mealItem.id),
                child: _LoggedFoodCard(
                  item: item,
                  onRemove: () => _handleRemoveFood(item.mealItem.id),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSkeletonCard(theme),
        const SizedBox(height: 12),
        _buildSkeletonCard(theme),
        const SizedBox(height: 12),
        _buildSkeletonCard(theme),
      ],
    );
  }

  Widget _buildSkeletonCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 16, width: 140, color: theme.colorScheme.surfaceVariant),
          const SizedBox(height: 10),
          Container(height: 12, width: double.infinity, color: theme.colorScheme.surfaceVariant),
          const SizedBox(height: 8),
          Container(height: 12, width: 180, color: theme.colorScheme.surfaceVariant),
          const SizedBox(height: 16),
          Container(height: 12, width: double.infinity, color: theme.colorScheme.surfaceVariant),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.wifi_off_outlined, size: 36, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            'Unable to load recommendations.',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text('Please try refreshing again.', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _refreshPage,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.restaurant_menu_outlined, size: 36, color: theme.colorScheme.primary),
          const SizedBox(height: 10),
          Text(
            'No recommendations available.',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text('Try refreshing to generate new ideas.', style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _MealSummaryCard extends StatelessWidget {
  final MealContext mealContext;
  final NutritionMacros targetMacros;
  final NutritionMacros consumedMacros;

  const _MealSummaryCard({
    required this.mealContext,
    required this.targetMacros,
    required this.consumedMacros,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <_MacroItem>[
      _MacroItem('Calories', consumedMacros.calories, targetMacros.calories, theme.colorScheme.primary),
      _MacroItem('Protein', consumedMacros.protein, targetMacros.protein, theme.colorScheme.tertiary),
      _MacroItem('Carbs', consumedMacros.carbs, targetMacros.carbs, theme.colorScheme.secondary),
      _MacroItem('Fat', consumedMacros.fat, targetMacros.fat, theme.colorScheme.error),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.35),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mealContext.displayName,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Target for this meal',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MacroProgressRow(item: item),
                )),
          ],
        ),
      ),
    );
  }
}

class _MacroItem {
  final String label;
  final double consumed;
  final double target;
  final Color color;

  const _MacroItem(this.label, this.consumed, this.target, this.color);
}

class _MacroProgressRow extends StatelessWidget {
  final _MacroItem item;

  const _MacroProgressRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = item.target <= 0 ? 0.0 : (item.consumed / item.target).clamp(0.0, 1.0);
    final consumedText = item.label == 'Calories'
        ? '${item.consumed.round()} / ${item.target.round()}'
        : '${item.consumed.toStringAsFixed(0)} / ${item.target.toStringAsFixed(0)}g';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(item.label, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
            Text(consumedText, style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: progress,
            backgroundColor: theme.colorScheme.surfaceVariant,
            color: item.color,
          ),
        ),
      ],
    );
  }
}

class _RecommendationCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = recommendation.score.score.clamp(0.0, 100.0);
    final food = recommendation.food;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    food.name,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Chip(
                  label: Text(score.toStringAsFixed(0)),
                  backgroundColor: theme.colorScheme.primaryContainer,
                  labelStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _NutritionPill('${food.calories.toStringAsFixed(0)} kcal', theme),
                _NutritionPill('${food.protein.toStringAsFixed(0)}g protein', theme),
                _NutritionPill('${food.fat.toStringAsFixed(0)}g fat', theme),
                _NutritionPill('${food.carbs.toStringAsFixed(0)}g carbs', theme),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Why was this recommended?',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                  ],
                ),
              ),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Overall score', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: score / 100,
                        color: theme.colorScheme.primary,
                        backgroundColor: theme.colorScheme.surfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      recommendation.score.explanation,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Add to Meal'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nutrition details will open here soon.')),
                      );
                    },
                    icon: const Icon(Icons.insights_outlined),
                    label: const Text('View Nutrition'),
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

class _NutritionPill extends StatelessWidget {
  final String label;
  final ThemeData theme;

  const _NutritionPill(this.label, this.theme);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: theme.textTheme.bodySmall),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final Food food;
  final VoidCallback onAdd;

  const _SearchResultTile({required this.food, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(food.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('${food.calories.toStringAsFixed(0)} kcal • ${food.protein.toStringAsFixed(0)}g protein', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            onPressed: onAdd,
            tooltip: 'Add food',
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}

class _LoggedFoodCard extends StatelessWidget {
  final MealItemWithFood item;
  final VoidCallback onRemove;

  const _LoggedFoodCard({required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final food = item.food;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(food.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('${food.calories.toStringAsFixed(0)} kcal', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 6),
                Text('${food.protein.toStringAsFixed(0)} P • ${food.carbs.toStringAsFixed(0)} C • ${food.fat.toStringAsFixed(0)} F', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Remove food',
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}