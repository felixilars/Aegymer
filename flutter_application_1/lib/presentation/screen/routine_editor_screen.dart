// Routine creation and editing screen. Allows users to name, describe, search, and compile 
// a list of exercises into a reusable routine template. Supports reordering exercises via drag-and-drop.

import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter_application_1/core/databases/app_database.dart';
import 'package:flutter_application_1/core/utils/workout_cal.dart';
import 'package:url_launcher/url_launcher.dart';

class RoutineEditorScreen extends StatefulWidget {
  final AppDatabase db;
  final RoutineWithExercises? routineToEdit;

  const RoutineEditorScreen({super.key, required this.db, this.routineToEdit});

  @override
  State<RoutineEditorScreen> createState() => _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends State<RoutineEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  List<Exercise> _selectedExercises = [];
  List<Exercise> _availableExercises = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.routineToEdit != null) {
      _nameController.text = widget.routineToEdit!.routine.name;
      _descController.text = widget.routineToEdit!.routine.description ?? '';
      _selectedExercises = List.from(widget.routineToEdit!.exercises);
    }
    _loadAvailableExercises();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableExercises() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final list = await widget.db.select(widget.db.exercises).get();
      setState(() {
        _availableExercises = list;
      });
    } catch (e) {
      debugPrint('Error loading exercises: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showCreateCustomExerciseDialog(VoidCallback onCreatedCallback) {
    final nameCtrl = TextEditingController();
    String targetMuscle = 'Chest';
    String equipment = 'Dumbbell';
    final formKey = GlobalKey<FormState>();

    final muscles = ['Chest', 'Back', 'Quads', 'Hamstrings', 'Shoulders', 'Biceps', 'Triceps', 'Abs', 'Calves', 'Cardio', 'Glutes'];
    final equipments = ['Barbell', 'Dumbbell', 'Machine', 'Cables', 'Bodyweight', 'Kettlebell', 'Bands', 'EZ-Bar'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create Custom Exercise'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Exercise Name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter an exercise name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16.0),
                      DropdownButtonFormField<String>(
                        value: targetMuscle,
                        decoration: const InputDecoration(
                          labelText: 'Target Muscle',
                          border: OutlineInputBorder(),
                        ),
                        items: muscles.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
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
                        items: equipments.map((eq) => DropdownMenuItem(value: eq, child: Text(eq))).toList(),
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
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final newId = 'custom-${DateTime.now().millisecondsSinceEpoch}';
                      final calculatedType = WorkoutCalculator.normalizeTrackingType(
                        null,
                        name: nameCtrl.text.trim(),
                        targetMuscle: targetMuscle,
                        equipment: equipment,
                      );
                      final newEx = Exercise(
                        id: newId,
                        name: nameCtrl.text.trim(),
                        targetMuscle: targetMuscle,
                        equipment: equipment,
                        isCustom: true,
                        trackingType: calculatedType,
                      );

                      await widget.db.into(widget.db.exercises).insert(
                        ExercisesCompanion.insert(
                          id: newId,
                          name: newEx.name,
                          targetMuscle: newEx.targetMuscle,
                          equipment: newEx.equipment,
                          isCustom: const Value(true),
                          trackingType: Value(calculatedType),
                        ),
                      );

                      setState(() {
                        _availableExercises.add(newEx);
                        _selectedExercises.add(newEx);
                      });
                      Navigator.of(context).pop();
                      onCreatedCallback();
                    }
                  },
                  child: const Text('Create New'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      nameCtrl.dispose();
    });
  }

  void _showAddExerciseBottomSheet() {
    String searchPattern = '';
    String selectedMuscleFilter = 'All';

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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;

            final filtered = _availableExercises.where((ex) {
              final matchesMuscle = selectedMuscleFilter == 'All' ||
                  ex.targetMuscle.toLowerCase().contains(selectedMuscleFilter.toLowerCase());
              final matchesSearch = WorkoutCalculator.matchesSearch(
                exerciseName: ex.name,
                targetMuscle: ex.targetMuscle,
                query: searchPattern,
              );
              return matchesMuscle && matchesSearch;
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Add Exercises',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Create New'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showCreateCustomExerciseDialog(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12.0),
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search exercises...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        searchPattern = val;
                      });
                    },
                  ),
                  const SizedBox(height: 10.0),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: muscleGroups.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final m = muscleGroups[i];
                        final isSelected = selectedMuscleFilter == m;
                        return ChoiceChip(
                          label: Text(m),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) {
                              setModalState(() {
                                selectedMuscleFilter = m;
                              });
                            }
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text('No exercises found'),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, idx) {
                              final ex = filtered[idx];
                              final isAlreadySelected = _selectedExercises.any((e) => e.id == ex.id);

                              return Card(
                                elevation: 0.5,
                                margin: const EdgeInsets.symmetric(vertical: 4.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  title: Text(
                                    ex.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text('${ex.targetMuscle} • ${ex.equipment}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.info_outline,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        tooltip: 'View Instructions',
                                        onPressed: () => _launchGoogleSearch(ex.name),
                                      ),
                                      isAlreadySelected
                                          ? Icon(
                                              Icons.check_circle,
                                              color: Theme.of(context).colorScheme.primary,
                                            )
                                          : const Icon(Icons.add_circle_outline),
                                    ],
                                  ),
                                  onTap: () {
                                    setState(() {
                                      if (isAlreadySelected) {
                                        _selectedExercises.removeWhere((e) => e.id == ex.id);
                                      } else {
                                        _selectedExercises.add(ex);
                                      }
                                    });
                                    setModalState(() {});
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12.0),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _launchGoogleSearch(String exerciseName) async {
    final query = Uri.encodeComponent('$exerciseName exercise how to form');
    final url = Uri.parse('https://www.google.com/search?q=$query');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot open search link')),
        );
      }
    }
  }

  Future<void> _saveRoutine() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedExercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 1 exercise for the routine!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final routineId = widget.routineToEdit?.routine.id ??
        'routine-${DateTime.now().millisecondsSinceEpoch}';

    try {
      await widget.db.saveRoutine(
        routineId: routineId,
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        exerciseIds: _selectedExercises.map((e) => e.id).toList(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Routine saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error saving routine: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot save routine: $e'),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.routineToEdit != null ? 'Edit Routine' : 'Create New Routine',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveRoutine,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Routine Name *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a routine name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16.0),
                    TextFormField(
                      controller: _descController,
                      decoration: InputDecoration(
                        labelText: 'Routine Description (Optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Exercises in routine (${_selectedExercises.length})',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _showAddExerciseBottomSheet,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Exercise'),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12.0),
                    Expanded(
                      child: _selectedExercises.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.fitness_center_outlined,
                                    size: 48,
                                    color: isDark ? Colors.white24 : Colors.black26,
                                  ),
                                  const SizedBox(height: 12.0),
                                  const Text(
                                    'No exercises selected',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ReorderableListView.builder(
                              itemCount: _selectedExercises.length,
                              onReorder: (oldIdx, newIdx) {
                                setState(() {
                                  if (newIdx > oldIdx) {
                                    newIdx -= 1;
                                  }
                                  final item = _selectedExercises.removeAt(oldIdx);
                                  _selectedExercises.insert(newIdx, item);
                                });
                              },
                              itemBuilder: (context, idx) {
                                final ex = _selectedExercises[idx];
                                return Card(
                                  key: ValueKey('reorder-$idx-${ex.id}'),
                                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: ListTile(
                                    leading: const Icon(Icons.drag_handle),
                                    title: Text(
                                      ex.name,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text('${ex.targetMuscle} • ${ex.equipment}'),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          _selectedExercises.removeAt(idx);
                                        });
                                      },
                                    ),
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
}
