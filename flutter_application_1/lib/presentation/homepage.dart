import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_application_1/core/databases/app_database.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  final PageController _controller = PageController();
  final AppDatabase _db = AppDatabase();
  List<WorkoutSession> _recentSessions = [];
  bool _loadingSessions = true;

  @override
  void initState() {
    super.initState();
    _loadRecentSessions();
  }

  Future<void> _loadRecentSessions() async {
    final query = _db.select(_db.workoutSessions)
      ..orderBy([
        (t) => drift.OrderingTerm(expression: t.date, mode: drift.OrderingMode.desc),
      ])
      ..limit(3);

    final sessions = await query.get();
    if (!mounted) return;

    setState(() {
      _recentSessions = sessions;
      _loadingSessions = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Homepage'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 250,
            child: PageView(
              controller: _controller,
              children: const [
                SizedBox(
                  child: Center(
                    child: Text(
                      'Welcome to Aegyme!',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Placeholder(),
                Placeholder(),
                Placeholder(),
              ],
            ),
          ),

          const SizedBox(height: 16),

          SmoothPageIndicator(
            controller: _controller,
            count: 4,
            effect: ScrollingDotsEffect(
              activeDotColor: const Color.fromARGB(255, 10, 21, 31),
              dotColor: Colors.grey,
              dotHeight: 10,
              dotWidth: 10,
              spacing: 8,
            ),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Sessions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _loadingSessions
                        ? const Center(child: CircularProgressIndicator())
                        : _recentSessions.isEmpty
                            ? const Center(
                                child: Text(
                                  'No sessions saved yet.',
                                  style: TextStyle(fontSize: 16, color: Colors.grey),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _recentSessions.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final session = _recentSessions[index];
                                  return Card(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Session ${index + 1}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Date: ${session.date.toLocal().toString().split('.').first}',
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            session.notes ?? 'No notes',
                                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                                          ),
                                        ],
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
        ],
      ),
    );
  }
}