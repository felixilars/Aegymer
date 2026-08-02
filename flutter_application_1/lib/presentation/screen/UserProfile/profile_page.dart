import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/databases/app_database.dart';
import 'package:flutter_application_1/core/services/nutrition_service.dart';

class ProfilePage extends StatefulWidget {
  final AppDatabase db;

  const ProfilePage({super.key, required this.db});

  @override
  State<ProfilePage> createState() => Profilepage();
}

class Profilepage extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _ageController = TextEditingController(text: '25');
  final _weightController = TextEditingController(text: '70.0');
  final _heightController = TextEditingController(text: '170.0');

  String _gender = 'Male';
  String _activityLevel = 'Moderately Active';
  String _target = 'Maintenance';
  bool _prefVegetarian = false;
  bool _prefLowSweet = false;
  bool _prefNoSeafood = false;
  bool _prefGlutenFree = false;
  bool _prefPeanutFree = false;

  bool _isLoading = true;
  UserProfile? _existingProfile;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void dispose() {
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);

    try {
      final profiles = await widget.db.select(widget.db.userProfiles).get();
      if (profiles.isNotEmpty) {
        _existingProfile = profiles.first;
        final profile = _existingProfile!;
        _gender = profile.gender;
        _ageController.text = profile.age.toString();
        _weightController.text = profile.weight.toStringAsFixed(1);
        _heightController.text = profile.height.toStringAsFixed(1);

        final activityLevelVal = profile.activityLevel;
        if (activityLevelVal >= 1.9) {
          _activityLevel = 'Extra Active';
        } else if (activityLevelVal >= 1.725) {
          _activityLevel = 'Very Active';
        } else if (activityLevelVal >= 1.55) {
          _activityLevel = 'Moderately Active';
        } else if (activityLevelVal >= 1.375) {
          _activityLevel = 'Lightly Active';
        } else {
          _activityLevel = 'Sedentary';
        }

        var target = profile.target;
        if (!const [
          'Lose Fat',
          'Maintenance',
          'Gain Muscle',
        ].contains(target)) {
          target = 'Maintenance';
        }
        _target = target;

        final preferences = profile.preferences?.toLowerCase() ?? '';
        _prefVegetarian = preferences.contains('vegetarian');
        _prefLowSweet = preferences.contains('sweet');
        _prefNoSeafood = preferences.contains('seafood');
        _prefGlutenFree = preferences.contains('gluten');
        _prefPeanutFree = preferences.contains('peanut');
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final weight = double.tryParse(_weightController.text) ?? 70.0;
    final height = double.tryParse(_heightController.text) ?? 170.0;
    final age = int.tryParse(_ageController.text) ?? 25;

    final preferences = <String>[];
    if (_prefVegetarian) preferences.add('Vegetarian');
    if (_prefLowSweet) preferences.add('Low Sweet');
    if (_prefNoSeafood) preferences.add('No Seafood');
    if (_prefGlutenFree) preferences.add('Gluten Free');
    if (_prefPeanutFree) preferences.add('Peanut Free');

    final profileId = _existingProfile?.id ?? 'local-profile';

    final nutritionService = NutritionService();
    final bmr = nutritionService.calculateBMR(
      weight: weight,
      height: height,
      age: age,
      gender: _gender,
    );
    final tdee = nutritionService.calculateTDEE(
      bmr: bmr,
      activityLevel: _activityLevel,
    );
    final macros = nutritionService.calculateMacroTargets(
      tdee: tdee,
      target: _target,
      weight: weight,
    );

    double activityMultiplier = 1.55;
    switch (_activityLevel.toLowerCase().trim()) {
      case 'sedentary':
        activityMultiplier = 1.2;
        break;
      case 'lightly active':
        activityMultiplier = 1.375;
        break;
      case 'moderately active':
        activityMultiplier = 1.55;
        break;
      case 'very active':
        activityMultiplier = 1.725;
        break;
      case 'extra active':
        activityMultiplier = 1.9;
        break;
    }

    try {
      await widget.db
          .into(widget.db.userProfiles)
          .insertOnConflictUpdate(
            UserProfilesCompanion.insert(
              id: profileId,
              gender: _gender,
              age: age,
              weight: weight,
              height: height,
              activityLevel: activityMultiplier,
              target: _target,
              dailyCalories: macros['calories'] ?? 2000.0,
              dailyProtein: macros['protein'] ?? 150.0,
              dailyCarbs: macros['carbs'] ?? 200.0,
              dailyFat: macros['fat'] ?? 60.0,
              preferences: drift.Value(
                preferences.isEmpty ? null : preferences.join(', '),
              ),
            ),
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save profile: $e')));
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Body Survey & AI Goals'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0.5,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Body Metrics',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _gender,
                                    decoration: const InputDecoration(
                                      labelText: 'Gender',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'Male',
                                        child: Text('Male'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Female',
                                        child: Text('Female'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'Other',
                                        child: Text('Other'),
                                      ),
                                    ],
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setState(() => _gender = value);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _ageController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Age',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                    validator: (value) {
                                      final parsed = int.tryParse(
                                        value?.trim() ?? '',
                                      );
                                      if (parsed == null || parsed < 0) {
                                        return 'Invalid age';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _weightController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      labelText: 'Weight (kg)',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                    validator: (value) {
                                      final parsed = double.tryParse(
                                        value?.trim() ?? '',
                                      );
                                      if (parsed == null || parsed <= 0) {
                                        return 'Invalid weight';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _heightController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: const InputDecoration(
                                      labelText: 'Height (cm)',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                    validator: (value) {
                                      final parsed = double.tryParse(
                                        value?.trim() ?? '',
                                      );
                                      if (parsed == null || parsed <= 0) {
                                        return 'Invalid height';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0.5,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Goal Settings',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: _activityLevel,
                              decoration: const InputDecoration(
                                labelText: 'Activity Level',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Sedentary',
                                  child: Text('Sedentary'),
                                ),
                                DropdownMenuItem(
                                  value: 'Lightly Active',
                                  child: Text('Lightly Active'),
                                ),
                                DropdownMenuItem(
                                  value: 'Moderately Active',
                                  child: Text('Moderately Active'),
                                ),
                                DropdownMenuItem(
                                  value: 'Very Active',
                                  child: Text('Very Active'),
                                ),
                                DropdownMenuItem(
                                  value: 'Extra Active',
                                  child: Text('Extra Active'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _activityLevel = value);
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _target,
                              decoration: const InputDecoration(
                                labelText: 'Target',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Lose Fat',
                                  child: Text('Lose Fat'),
                                ),
                                DropdownMenuItem(
                                  value: 'Maintenance',
                                  child: Text('Maintenance'),
                                ),
                                DropdownMenuItem(
                                  value: 'Gain Muscle',
                                  child: Text('Gain Muscle'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _target = value);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0.5,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dietary Preferences',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            _buildCheckbox(
                              'Vegetarian',
                              _prefVegetarian,
                              (value) => setState(
                                () => _prefVegetarian = value ?? false,
                              ),
                            ),
                            _buildCheckbox(
                              'Low Sweet',
                              _prefLowSweet,
                              (value) => setState(
                                () => _prefLowSweet = value ?? false,
                              ),
                            ),
                            _buildCheckbox(
                              'No Seafood',
                              _prefNoSeafood,
                              (value) => setState(
                                () => _prefNoSeafood = value ?? false,
                              ),
                            ),
                            _buildCheckbox(
                              'Gluten Free',
                              _prefGlutenFree,
                              (value) => setState(
                                () => _prefGlutenFree = value ?? false,
                              ),
                            ),
                            _buildCheckbox(
                              'Peanut Free',
                              _prefPeanutFree,
                              (value) => setState(
                                () => _prefPeanutFree = value ?? false,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _saveProfile,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Profile'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCheckbox(
    String label,
    bool value,
    ValueChanged<bool?> onChanged,
  ) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }
}
