import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aegymer/helper/check_firsttime.dart';
import 'package:aegymer/core/databases/app_database.dart';
import 'package:aegymer/presentation/screen/Home_and_Main/MainPage.dart';
import 'package:aegymer/core/services/food/nutrition_service.dart';
import 'package:drift/drift.dart' as drift;

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedGender;
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _activityController = TextEditingController();
  String _selectedTarget = 'Gain Muscle';
  final _preferencesController = TextEditingController();

  final _db = AppDatabase();
  bool _isSaving = false;

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final nutritionService = NutritionService();
      final weightVal = double.parse(_weightController.text.trim());
      final heightVal = double.parse(_heightController.text.trim());
      final ageVal = int.parse(_ageController.text.trim());
      final activityMultiplier = double.parse(_activityController.text.trim());

      final bmr = nutritionService.calculateBMR(
        gender: _selectedGender ?? 'Other',
        weight: weightVal,
        height: heightVal,
        age: ageVal,
      );

      final tdee = nutritionService.calculateTDEE(
        bmr: bmr,
        activityMultiplier: activityMultiplier,
      );

      final targetCal = nutritionService.calculateTargetCalories(
        tdee: tdee,
        goal: _selectedTarget,
      );

      final macros = nutritionService.calculateMacros(
        calories: targetCal,
        weight: weightVal,
      );

      final profile = UserProfilesCompanion.insert(
        id: 'local-profile',
        email: const drift.Value(null),
        gender: _selectedGender ?? 'Other',
        age: ageVal,
        weight: weightVal,
        height: heightVal,
        activityLevel: activityMultiplier,
        target: _selectedTarget,
        dailyCalories: macros.calories,
        dailyProtein: macros.protein,
        dailyCarbs: macros.carbs,
        dailyFat: macros.fat,
        preferences: drift.Value(
          _preferencesController.text.trim().isEmpty
              ? null
              : _preferencesController.text.trim(),
        ),
      );

      await _db.into(_db.userProfiles).insertOnConflictUpdate(profile);
      await CheckFirstTime.setFirstTime(false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully!')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainPage()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save profile: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _activityController.dispose();
    _preferencesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Personalize Your Profile',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined, color: primaryColor, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '100% Private & Local. No email or cloud account required.',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                _buildSectionCard(
                  cardBg: cardBg,
                  borderColor: borderColor,
                  icon: Icons.person_outline_rounded,
                  title: 'Physical Metrics',
                  subtitle: 'Used for BMR, TDEE, and weight calculations',
                  primaryColor: primaryColor,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _selectedGender,
                      decoration: InputDecoration(
                        labelText: 'Gender',
                        prefixIcon: const Icon(Icons.wc_rounded, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(value: 'Female', child: Text('Female')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedGender = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select your gender';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    _buildTextField(
                      controller: _ageController,
                      label: 'Age',
                      hintText: 'e.g. 25',
                      prefixIcon: Icons.cake_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your age';
                        }
                        final parsed = int.tryParse(value.trim());
                        if (parsed == null || parsed <= 0 || parsed > 120) {
                          return 'Please enter a valid age (1-120)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _weightController,
                            label: 'Weight (kg)',
                            hintText: 'e.g. 70.0',
                            prefixIcon: Icons.monitor_weight_outlined,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                            ],
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter weight';
                              }
                              final parsed = double.tryParse(value.trim());
                              if (parsed == null || parsed <= 20 || parsed > 300) {
                                return 'Valid weight (20-300)';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _heightController,
                            label: 'Height (cm)',
                            hintText: 'e.g. 175',
                            prefixIcon: Icons.height_rounded,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                            ],
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter height';
                              }
                              final parsed = double.tryParse(value.trim());
                              if (parsed == null || parsed <= 80 || parsed > 250) {
                                return 'Valid height (80-250)';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                _buildSectionCard(
                  cardBg: cardBg,
                  borderColor: borderColor,
                  icon: Icons.flag_outlined,
                  title: 'Activity & Goal',
                  subtitle: 'Determines daily calorie surplus/deficit and macros',
                  primaryColor: primaryColor,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _activityController.text.isEmpty
                          ? null
                          : _activityController.text,
                      decoration: InputDecoration(
                        labelText: 'Activity Level',
                        prefixIcon: const Icon(Icons.directions_run_rounded, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: '1.2',
                          child: Text('Sedentary (Office / Little exercise)'),
                        ),
                        DropdownMenuItem(
                          value: '1.375',
                          child: Text('Light (Exercise 1-3 days/week)'),
                        ),
                        DropdownMenuItem(
                          value: '1.55',
                          child: Text('Moderate (Exercise 3-5 days/week)'),
                        ),
                        DropdownMenuItem(
                          value: '1.725',
                          child: Text('Very Active (Exercise 6-7 days/week)'),
                        ),
                        DropdownMenuItem(
                          value: '1.9',
                          child: Text('Extra Active (Athlete / Heavy labor)'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _activityController.text = value ?? '';
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select your activity level';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Primary Goal',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'Lose Fat',
                            label: Text('Lose Fat', style: TextStyle(fontSize: 12)),
                            icon: Icon(Icons.trending_down_rounded, size: 16),
                          ),
                          ButtonSegment(
                            value: 'Maintenance',
                            label: Text('Maintain', style: TextStyle(fontSize: 12)),
                            icon: Icon(Icons.balance_rounded, size: 16),
                          ),
                          ButtonSegment(
                            value: 'Gain Muscle',
                            label: Text('Gain Muscle', style: TextStyle(fontSize: 12)),
                            icon: Icon(Icons.trending_up_rounded, size: 16),
                          ),
                        ],
                        selected: {_selectedTarget},
                        onSelectionChanged: (newSelection) {
                          setState(() => _selectedTarget = newSelection.first);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                _buildSectionCard(
                  cardBg: cardBg,
                  borderColor: borderColor,
                  icon: Icons.restaurant_outlined,
                  title: 'Dietary Preferences (Optional)',
                  subtitle: 'Help filter recipes and meal recommendations',
                  primaryColor: primaryColor,
                  children: [
                    _buildTextField(
                      controller: _preferencesController,
                      label: 'Preferences / Allergies',
                      hintText: 'e.g. vegetarian, high protein, no seafood',
                      prefixIcon: Icons.menu_book_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Complete Setup & Start',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.check_circle_outline_rounded, size: 20),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required Color cardBg,
    required Color borderColor,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color primaryColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: primaryColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    IconData? prefixIcon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      validator: validator,
    );
  }
}
