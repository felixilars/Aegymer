import 'package:flutter/material.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_application_1/core/databases/app_database.dart';

class RecentSessionPopup extends StatefulWidget {
  final WorkoutSession session;

  const RecentSessionPopup({
    super.key,
    required this.session,
  });

  @override
  State<RecentSessionPopup> createState() => _RecentSessionPopupState();
}

class _RecentSessionPopupState extends State<RecentSessionPopup> {
  final AppDatabase _db = AppDatabase();
  List<(WorkoutSet, Exercise)> _workoutSetsWithExercises = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkoutSets();
  }

  Future<void> _loadWorkoutSets() async {
    final sets = await (_db.select(_db.workoutSets).join([
  drift.innerJoin(
    _db.exercises,
    _db.exercises.id.equalsExp(_db.workoutSets.exerciseId),
  ),
])
  ..where(
    _db.workoutSets.sessionId.equals(widget.session.id),
  ))
.get();

    if (!mounted) return;

    setState(() {
      _workoutSetsWithExercises = sets
          .map((row) => (row.readTable(_db.workoutSets), row.readTable(_db.exercises)))
          .toList();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Workout Details',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.session.date.toLocal().toString().split('.').first,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xff6B7280),
              ),
            ),
            const SizedBox(height: 24),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_workoutSetsWithExercises.isEmpty)
              const Center(
                child: Text('No exercises recorded'),
              )
            else
              Column(
                children: _workoutSetsWithExercises.map((item) {
                  final (set, exercise) = item;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xffF5F7FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xffE5E7EB),
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exercise.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff1F2937),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Reps',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xff6B7280),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${set.reps}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xff1F2937),
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Weight (kg)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xff6B7280),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${set.weight}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xff1F2937),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            if (_workoutSetsWithExercises.isNotEmpty && widget.session.notes != null && widget.session.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xffF5F7FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xffE5E7EB),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notes',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff1F2937),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.session.notes ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xff6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
