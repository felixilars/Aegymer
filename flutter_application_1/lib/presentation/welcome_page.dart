import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/helper/check_firsttime.dart';
import 'package:flutter_application_1/core/databases/app_database.dart';
import 'package:flutter_application_1/presentation/screen/Home_and_Main/MainPage.dart';
import 'package:flutter_application_1/core/services/food/nutrition_service.dart';
import 'package:flutter_application_1/models/nutrition_macros.dart';
import 'package:drift/drift.dart' as drift;

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  String? _selectedGender;
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _activityController = TextEditingController();
  final _targetController = TextEditingController();
  final _preferencesController = TextEditingController();

  final _db = AppDatabase();

  Future<void> _saveProfile() async {
    
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      NutritionService nutritionService = NutritionService();
      double bmr = nutritionService.calculateBMR(
        gender : _selectedGender ?? 'Other',
        weight: double.parse(_weightController.text.trim()),
        height: double.parse(_heightController.text.trim()),
        age: int.parse(_ageController.text.trim()),
      );

      double tdee = nutritionService.calculateTDEE(
        bmr : bmr,
        activityMultiplier: double.parse(_activityController.text.trim()),
      );

      double targetCal = nutritionService.calculateTargetCalories(
        tdee : tdee,
        goal: _targetController.text.trim(),
      );

      NutritionMacros macros = nutritionService.calculateMacros(
        calories : targetCal,
        weight: double.parse(_weightController.text.trim()),
      );



      final profile = UserProfilesCompanion.insert(
        id: 'local-profile',
        email: drift.Value(
          _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
        ),
        gender: _selectedGender ?? 'Other',
        age: int.parse(_ageController.text.trim()),
        weight: double.parse(_weightController.text.trim()),
        height: double.parse(_heightController.text.trim()),
        activityLevel: double.parse(_activityController.text.trim()),
        target: _targetController.text.trim(),
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
        const SnackBar(content: Text('Profile saved successfully')),
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
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _activityController.dispose();
    _targetController.dispose();
    _preferencesController.dispose();
    _db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Your Profile'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tell us about yourself',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This information will be stored locally on your device.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),

                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    border: OutlineInputBorder(),
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
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _ageController,
                  label: 'Age',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your age';
                    }
                    if (int.tryParse(value.trim()) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _weightController,
                  label: 'Weight (kg)',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your weight';
                    }
                    if (double.tryParse(value.trim()) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _heightController,
                  label: 'Height (cm)',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your height';
                    }
                    if (double.tryParse(value.trim()) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  value: _activityController.text,
                  decoration: const InputDecoration(
                    labelText: 'Activity Level',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: '1.2', child: Text('Sedentary (Office Job)')),
                    DropdownMenuItem(value: '1.375', child: Text('Light Exercise (1-3 days/week)')),
                    DropdownMenuItem(value: '1.55', child: Text('Moderate Exercise (3-5 days/week)')),
                    DropdownMenuItem(value: '1.725', child: Text('Active (6-7 days/week)')),
                    DropdownMenuItem(value: '1.9', child: Text('Athlete (2x/day)')),

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

                _buildTextField(
                  controller: _targetController,
                  label: 'Target',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your target';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _preferencesController,
                  label: 'Preferences',
                  hintText: 'e.g. vegetarian, no seafood',
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveProfile,
                    child: const Text('Okay'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
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
        border: const OutlineInputBorder(),
      ),
      validator: validator,
    );
  }
}



