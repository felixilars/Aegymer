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
                  'Cloud Connection & Offline Status',
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
                  icon: Icons.error_outline_rounded,
                  color: Colors.orange,
                  title: 'Connection Status',
                  description: state.message ??
                      'The Supabase server is unreachable or your device is offline. The app is running in Local Database mode.',
                ),
                const SizedBox(height: 12),
                _buildInfoBlock(
                  icon: Icons.shield_outlined,
                  color: Colors.green,
                  title: 'Local Storage',
                  description:
                      'Workout logs, custom routines, exercise history, body weight entries, and nutrition records are saved in local SQLite on your device.',
                ),
                const SizedBox(height: 12),
                _buildInfoBlock(
                  icon: Icons.check_circle_outline_rounded,
                  color: Colors.blue,
                  title: 'Offline Features',
                  description:
                      '• Active workout tracking, set/reps logging, and rest timer.\n• Access to core exercises and routine templates.\n• Weight progression and meal scoring.',
                ),
                const SizedBox(height: 12),
                _buildInfoBlock(
                  icon: Icons.tips_and_updates_outlined,
                  color: Colors.teal,
                  title: 'Next Steps',
                  description:
                      '1. Continue using the app.\n2. Check your Wi-Fi or cellular network.\n3. Tap "Retry Sync" once connection is restored.',
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
              label: const Text('Retry Sync'),
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
                      'Offline Mode',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                      ),
                    ),
                    Text(
                      'Cloud server unreachable. Your data is stored safely on this device.',
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
