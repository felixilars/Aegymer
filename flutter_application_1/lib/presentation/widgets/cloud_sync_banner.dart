import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/services/sync_service.dart';

class CloudSyncBanner extends StatefulWidget {
  final SyncService? syncService;

  const CloudSyncBanner({super.key, this.syncService});

  @override
  State<CloudSyncBanner> createState() => _CloudSyncBannerState();
}

class _CloudSyncBannerState extends State<CloudSyncBanner> {
  bool _isDismissed = false;

  void _showSolutionDialog(BuildContext context, CloudSyncState state) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.cloud_off_rounded, color: Colors.amber, size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Exercise Catalog Offline',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoBlock(
                  icon: Icons.cloud_off_rounded,
                  color: Colors.orange,
                  title: 'Online Catalog Status',
                  description:
                      'Cannot connect to the online exercise and food database. The app is running smoothly with built-in exercises.',
                ),
                const SizedBox(height: 12),
                _buildInfoBlock(
                  icon: Icons.shield_outlined,
                  color: Colors.green,
                  title: '100% Private & Local',
                  description:
                      'Aegymer never collects, uploads, or syncs your personal data. Your workouts, routines, body measurements, and profile stay strictly on your device.',
                ),
                const SizedBox(height: 12),
                _buildInfoBlock(
                  icon: Icons.check_circle_outline_rounded,
                  color: Colors.blue,
                  title: 'Full Offline Access',
                  description:
                      '• Active workout tracking, sets, reps, and timer.\n• Built-in exercise library and custom routines.\n• Streak tracking, nutrition logging, and charts.',
                ),
                const SizedBox(height: 12),
                _buildInfoBlock(
                  icon: Icons.refresh_rounded,
                  color: Colors.teal,
                  title: 'Catalog Updates',
                  description:
                      'Check your internet connection and tap "Retry Library Sync" if you want to check for new exercises or foods from the shared catalog.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Continue Offline'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry Library Sync'),
              onPressed: () {
                Navigator.of(ctx).pop();
                widget.syncService?.initializeAndSync();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoBlock({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

    return ValueListenableBuilder<CloudSyncState>(
      valueListenable: SyncService.syncState,
      builder: (context, state, _) {
        if (state.status != CloudConnectionStatus.offline &&
            state.status != CloudConnectionStatus.serverError) {
          return const SizedBox.shrink();
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF332A15) : const Color(0xFFFFF7E6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.amber.shade700.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.cloud_off_rounded, color: Colors.amber.shade800, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Exercise Catalog Offline',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                      ),
                    ),
                    Text(
                      'Cannot reach online exercise library. Personal data is 100% private and stored locally.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => _showSolutionDialog(context, state),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    'Details',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade800,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _isDismissed = true),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 16, color: Colors.grey),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
