import 'package:flutter/material.dart';
import 'package:aegymer/core/services/autoregulation_service.dart';

class KnnDemoScreen extends StatefulWidget {
  const KnnDemoScreen({super.key});

  @override
  State<KnnDemoScreen> createState() => _KnnDemoScreenState();
}

class _SessionDraft {
  DateTime date;
  final TextEditingController weightController;
  final TextEditingController repsController;

  _SessionDraft({
    required this.date,
    required double weight,
    required String reps,
  })  : weightController = TextEditingController(text: weight.toStringAsFixed(1)),
        repsController = TextEditingController(text: reps);

  void dispose() {
    weightController.dispose();
    repsController.dispose();
  }
}

class _KnnDemoScreenState extends State<KnnDemoScreen> {
  late final List<_SessionDraft> _sessions;

  @override
  void initState() {
    super.initState();
    _sessions = _buildInitialSessions();
  }

  @override
  void dispose() {
    for (final session in _sessions) {
      session.dispose();
    }
    super.dispose();
  }

  List<_SessionDraft> _buildInitialSessions() {
    final baseDate = DateTime.now().subtract(const Duration(days: 36));

    return List.generate(12, (index) {
      final sessionIndex = index + 1;
      return _SessionDraft(
        date: baseDate.add(Duration(days: index * 3)),
        weight: 100.0 + sessionIndex * 2.5,
        reps: '10, ${9 + (sessionIndex % 3)}, ${8 + (sessionIndex % 2)}',
      );
    });
  }

  List<int> _parseReps(String value) {
    return value
        .split(',')
        .map((part) => int.tryParse(part.trim()))
        .whereType<int>()
        .toList();
  }

  List<ExerciseSessionHistory> _buildHistory() {
    return _sessions.map((session) {
      final weight = double.tryParse(session.weightController.text.trim()) ?? 0.0;
      final reps = _parseReps(session.repsController.text);
      return ExerciseSessionHistory(
        date: session.date,
        weights: [weight],
        reps: reps.isEmpty ? [0] : reps,
      );
    }).toList();
  }

  void _addSession() {
    setState(() {
      final lastDate = _sessions.isEmpty ? DateTime.now() : _sessions.last.date;
      _sessions.add(
        _SessionDraft(
          date: lastDate.add(const Duration(days: 3)),
          weight: 100.0,
          reps: '10, 9, 8',
        ),
      );
    });
  }

  void _removeSession(int index) {
    if (_sessions.length <= 1) return;
    setState(() {
      final session = _sessions.removeAt(index);
      session.dispose();
    });
  }

  Future<void> _pickDate(int index) async {
    final current = _sessions[index].date;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _sessions[index].date = picked;
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = _buildHistory();
    final suggestion = history.isEmpty
        ? {'method': 'Initial', 'weight': 0.0}
        : AutoregulationService().suggestNextWorkout(
            history: history,
            nextSessionDate: DateTime.now(),
            targetReps: 10,
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('KNN Mock Demo'),
        centerTitle: true,
        actions: [
          TextButton.icon(
            onPressed: _addSession,
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Edit sessions directly',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Change weight, reps, or the date for each session. The suggested next workout updates immediately.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          ..._sessions.asMap().entries.map((entry) {
            final index = entry.key;
            final session = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(child: Text('${index + 1}')),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Session ${index + 1}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _removeSession(index),
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Remove session',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickDate(index),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(session.date.toIso8601String().split('T').first),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: session.weightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Weight (kg)',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: session.repsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Reps per set (comma separated)',
                        hintText: '10, 9, 8',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Suggested next workout',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text('Sessions used: ${history.length}'),
                  Text('Method: ${suggestion['method']}'),
                  Text('Weight: ${(suggestion['weight'] as double).toStringAsFixed(1)} kg'),
                  const Text('Target reps: 10'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Invalid numbers are treated as 0.0, so keep the session values numeric when testing.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
