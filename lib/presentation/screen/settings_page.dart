import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aegymer/core/databases/app_database.dart';
import 'package:aegymer/core/services/settings_service.dart';
import 'package:aegymer/core/services/workout_draft_service.dart';
import 'package:aegymer/core/services/streak_service.dart';
import 'package:aegymer/core/services/backup_service.dart';
import 'package:aegymer/core/services/backup_file_gateway.dart';

class SettingsPage extends StatefulWidget {
  final AppDatabase db;

  final BackupFileGateway backupFiles;

  const SettingsPage({
    super.key,
    required this.db,
    this.backupFiles = const BackupFileGateway(),
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Map<String, dynamic>? _activeDraft;
  bool _isLoadingDraft = true;
  bool _isBackupBusy = false;

  @override
  void initState() {
    super.initState();
    _checkActiveDraft();
  }

  Future<void> _checkActiveDraft() async {
    setState(() => _isLoadingDraft = true);
    final draft = await WorkoutDraftService.getDraft();
    if (mounted) {
      setState(() {
        _activeDraft = draft;
        _isLoadingDraft = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          _buildSectionHeader('Appearance & Theme', Icons.palette_outlined, Colors.purpleAccent),
          const SizedBox(height: 8),
          _buildThemeCard(context, isDark),

          const SizedBox(height: 24),
          _buildSectionHeader('Workout & Weight Logging', Icons.fitness_center_rounded, theme.colorScheme.primary),
          const SizedBox(height: 8),
          _buildWeightLoggingCard(context, isDark),

          const SizedBox(height: 24),
          _buildSectionHeader('App Capabilities & Guide', Icons.auto_awesome_rounded, Colors.amber.shade700),
          const SizedBox(height: 8),
          _buildAppFeaturesCard(context, isDark),

          const SizedBox(height: 24),
          _buildSectionHeader('Data & Storage', Icons.storage_rounded, Colors.teal),
          const SizedBox(height: 8),
          _buildDataStorageCard(context, isDark),

          const SizedBox(height: 24),
          _buildSectionHeader('About Aegymer', Icons.info_outline_rounded, Colors.blueAccent),
          const SizedBox(height: 8),
          _buildAboutCard(context, isDark),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildThemeCard(BuildContext context, bool isDark) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: SettingsService.themeModeNotifier,
      builder: (context, currentMode, _) {
        return Card(
          elevation: 0,
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Interface Theme',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Choose between Light, Dark, or System mode',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        currentMode == ThemeMode.light
                            ? 'Light'
                            : (currentMode == ThemeMode.dark ? 'Dark' : 'System Auto'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      visualDensity: VisualDensity.comfortable,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    segments: const [
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_rounded, size: 16),
                        label: Text('Light (Sáng)', style: TextStyle(fontSize: 12)),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_rounded, size: 16),
                        label: Text('Dark (Tối)', style: TextStyle(fontSize: 12)),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_rounded, size: 16),
                        label: Text('System', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                    selected: {currentMode},
                    onSelectionChanged: (newSelection) {
                      SettingsService.setThemeMode(newSelection.first);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  currentMode == ThemeMode.system
                      ? '• System mode dynamically syncs with your device settings.'
                      : (currentMode == ThemeMode.dark
                          ? '• Dark mode is active, optimizing battery and reducing eye strain.'
                          : '• Light mode is active with clean high-contrast elements.'),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWeightLoggingCard(BuildContext context, bool isDark) {
    return ValueListenableBuilder<String>(
      valueListenable: SettingsService.weightAutofillNotifier,
      builder: (context, autofillMode, _) {
        return Card(
          elevation: 0,
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Weight Autofill Mode (Chế độ điền mức tạ)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Determines the starting weight when adding an exercise to your workout',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 14),

                // Option 1: Previous session history
                _buildAutofillOptionTile(
                  context: context,
                  isDark: isDark,
                  isSelected: autofillMode == 'historical',
                  title: 'Previous Session History (Lịch sử cũ)',
                  subtitle: 'Auto-fills sets with the exact weights & reps you completed in your latest workout for this exercise.',
                  badgeText: 'Recommended',
                  icon: Icons.history_rounded,
                  iconColor: Colors.blueAccent,
                  onTap: () => SettingsService.setWeightAutofillMode('historical'),
                ),

                const SizedBox(height: 10),

                // Option 2: Default weight
                _buildAutofillOptionTile(
                  context: context,
                  isDark: isDark,
                  isSelected: autofillMode == 'default',
                  title: 'Default Weight (Mức tạ mặc định)',
                  subtitle: 'Always starts fresh with standard default weight (e.g. 40 kg for barbell/dumbbell exercises, 0 kg for bodyweight).',
                  badgeText: 'Fresh Start',
                  icon: Icons.restart_alt_rounded,
                  iconColor: Colors.orangeAccent,
                  onTap: () => SettingsService.setWeightAutofillMode('default'),
                ),

                const SizedBox(height: 18),
                const Divider(height: 1),
                const SizedBox(height: 14),

                // Default Barbell Weight
                ValueListenableBuilder<double>(
                  valueListenable: SettingsService.defaultBarbellWeightNotifier,
                  builder: (context, defaultBar, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Default Barbell Bar Weight',
                                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Standard empty bar weight in Barbell mode',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${defaultBar.toStringAsFixed(1)} kg',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<double>(
                            showSelectedIcon: false,
                            style: ButtonStyle(
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            segments: const [
                              ButtonSegment<double>(
                                value: 20.0,
                                label: Text('20 kg (Olympic)', style: TextStyle(fontSize: 12)),
                              ),
                              ButtonSegment<double>(
                                value: 15.0,
                                label: Text('15 kg (Olympic W)', style: TextStyle(fontSize: 12)),
                              ),
                              ButtonSegment<double>(
                                value: 10.0,
                                label: Text('10 kg (EZ Bar)', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                            selected: {defaultBar},
                            onSelectionChanged: (val) {
                              SettingsService.setDefaultBarbellWeight(val.first);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 6),

                // Auto Rest Timer
                ValueListenableBuilder<bool>(
                  valueListenable: SettingsService.autoRestTimerNotifier,
                  builder: (context, autoTimer, _) {
                    return SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Auto Rest Stopwatch',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: const Text(
                        'Keep stopwatch active during workouts to track rest periods between sets',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      value: autoTimer,
                      onChanged: (val) {
                        SettingsService.setAutoRestTimer(val);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAutofillOptionTile({
    required BuildContext context,
    required bool isDark,
    required bool isSelected,
    required String title,
    required String subtitle,
    required String badgeText,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withOpacity(isDark ? 0.15 : 0.08)
              : (isDark ? Colors.white.withOpacity(0.02) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDark ? Colors.white10 : Colors.black.withOpacity(0.08)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isSelected ? primaryColor : null,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (isSelected ? primaryColor : Colors.grey).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? primaryColor : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppFeaturesCard(BuildContext context, bool isDark) {
    final features = [
      (
        icon: Icons.fitness_center_rounded,
        color: Colors.blueAccent,
        title: 'Real-Time Workout Logging',
        desc: 'Log sets, reps, distance, and duration with automated e1RM calculation and calorie burn estimations.',
      ),
      (
        icon: Icons.straighten_rounded,
        color: Colors.purpleAccent,
        title: 'Barbell & Dumbbell Calculation Modes',
        desc: 'Easily log per-side barbell weight + bar (default 20kg), or 1-hand dumbbell weight with instant 2× total volume multiplier and 0kg bar.',
      ),
      (
        icon: Icons.bookmark_added_rounded,
        color: Colors.teal,
        title: 'Smart Workout Draft & Recovery',
        desc: 'Never lose workout progress. Auto-saves every 10s and on app backgrounding; resume or complete anytime without data loss.',
      ),
      (
        icon: Icons.insights_rounded,
        color: Colors.orangeAccent,
        title: 'Progression Charts & Muscle Balance',
        desc: 'Inspect estimated 1RM growth over time and check muscle balance across 7 major muscle groups with radar charts.',
      ),
      (
        icon: Icons.restaurant_menu_rounded,
        color: Colors.green,
        title: 'Meal Prep & AI Nutrition Tracking',
        desc: 'Automated Mifflin-St Jeor TDEE calculation, daily macro goals (Protein, Carbs, Fat), and personalized meal recommendations.',
      ),
      (
        icon: Icons.cloud_sync_rounded,
        color: Colors.indigoAccent,
        title: 'Offline-First Local Storage & Cloud Sync',
        desc: 'Powered by Drift SQLite for instantaneous, reliable local access, backed by Supabase cloud sync when online.',
      ),
    ];

    return Card(
      elevation: 0,
      color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          children: features.map((f) {
            final isLast = features.last == f;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: f.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(f.icon, size: 18, color: f.color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              f.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              f.desc,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white70 : Colors.grey.shade700,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast) const Divider(height: 8, thickness: 0.5),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDataStorageCard(BuildContext context, bool isDark) {
    return Card(
      elevation: 0,
      color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBackupRow(),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Active Draft Status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (_activeDraft != null ? Colors.amber : Colors.grey).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _activeDraft != null ? Icons.bolt_rounded : Icons.check_circle_outline_rounded,
                    size: 18,
                    color: _activeDraft != null ? Colors.amber : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Active Workout Draft',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Text(
                        _isLoadingDraft
                            ? 'Checking draft status...'
                            : (_activeDraft != null
                                ? 'Active draft: ${_activeDraft!['routineName'] ?? 'Free Workout'}'
                                : 'No unfinished draft in storage'),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (_activeDraft != null)
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _confirmClearDraft,
                    child: const Text('Clear', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Reset Exercise Mode Preferences
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.tune_rounded, size: 18, color: Colors.blueAccent),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Exercise Mode Preferences',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Text(
                        'Remembered barbell / dumbbell modes per exercise',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _confirmResetPreferences,
                  child: const Text('Reset', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context, bool isDark) {
    return Card(
      elevation: 0,
      color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.fitness_center_rounded,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Aegymer',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Version 1.0.1 • Fitness & Nutrition Tracker',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Lift smart • Eat right • Track everything',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Built with passion for gym enthusiasts and lifters. All workout data is stored locally on your device with high-performance Drift SQLite.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.backup_outlined, size: 18, color: Colors.teal),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Backup & Restore',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(
                    'Your data lives only on this phone. Save a backup file to keep it safe or move it to a new device.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _isBackupBusy ? null : _exportBackup,
                icon: const Icon(Icons.file_upload_outlined, size: 18),
                label: const Text('Export'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isBackupBusy ? null : _restoreBackup,
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: const Text('Restore'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showMessage(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.redAccent : null,
      ),
    );
  }

  Future<void> _exportBackup() async {
    setState(() => _isBackupBusy = true);
    try {
      final json = await BackupService(widget.db).exportBackup();
      final now = DateTime.now();
      final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final saved = await widget.backupFiles.save(
        'aegymer-backup-$date.json',
        utf8.encode(json),
      );
      if (saved) _showMessage('Backup saved.');
    } catch (e) {
      _showMessage('Could not create backup: $e', error: true);
    } finally {
      if (mounted) setState(() => _isBackupBusy = false);
    }
  }

  Future<void> _restoreBackup() async {
    setState(() => _isBackupBusy = true);
    try {
      final bytes = await widget.backupFiles.pick();
      if (bytes == null || !mounted) return;

      final String json;
      final BackupSummary summary;
      try {
        json = utf8.decode(bytes);
        summary = BackupService.inspect(json);
      } on FormatException catch (e) {
        _showMessage(e.message, error: true);
        return;
      }
      if (!mounted) return;

      final confirmed = await _confirmRestore(summary);
      if (confirmed != true) return;

      await BackupService(widget.db).restoreBackup(json);
      StreakService.notifyWorkoutUpdated();
      _showMessage('Restored ${summary.sessions} workouts and ${summary.meals} meals.');
    } catch (e) {
      _showMessage('Could not restore backup: $e', error: true);
    } finally {
      if (mounted) setState(() => _isBackupBusy = false);
    }
  }

  Future<bool?> _confirmRestore(BackupSummary summary) {
    final created = summary.createdAt?.toLocal();
    final createdText = created == null
        ? 'unknown date'
        : '${created.day.toString().padLeft(2, '0')}/${created.month.toString().padLeft(2, '0')}/${created.year} '
            '${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';
    final lines = <String>[
      '${summary.sessions} workouts (${summary.sets} sets)',
      '${summary.meals} meals',
      '${summary.routines} routines',
      '${summary.customExercises} custom exercises, ${summary.customFoods} custom foods',
      if (summary.hasProfile) 'Your profile (replaces the current one)',
    ];

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore this backup?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Created $createdText. It contains:'),
            const SizedBox(height: 8),
            for (final line in lines) Text('• $line'),
            const SizedBox(height: 12),
            const Text(
              'It is merged into your current data: matching entries are replaced, nothing else is deleted.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearDraft() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Active Workout Draft?'),
        content: const Text('This will delete all unsaved sets from your unfinished draft session.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear Draft'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await WorkoutDraftService.clearDraft();
      StreakService.notifyWorkoutUpdated();
      await _checkActiveDraft();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Active workout draft cleared.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _confirmResetPreferences() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Exercise Preferences?'),
        content: const Text('This will reset remembered barbell / dumbbell modes and set counts for all exercises back to default.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) =>
          k.startsWith('pref_weight_mode_') ||
          k.startsWith('pref_ex_mode_') ||
          k.startsWith('pref_ex_sets_') ||
          k.startsWith('pref_ex_wtype_'));
      for (final k in keys) {
        await prefs.remove(k);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All exercise preferences have been reset.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
