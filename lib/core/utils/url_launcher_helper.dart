import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlLauncherHelper {
  /// Launches a Google search query to find instructions/form guide for a given exercise.
  static Future<void> openExerciseFormGuide(
    BuildContext context,
    String exerciseName,
  ) async {
    final query = Uri.encodeComponent('$exerciseName exercise how to form');
    final url = Uri.parse('https://www.google.com/search?q=$query');

    try {
      // First attempt: Open in external browser app
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        // Fallback: Open with platform default launcher
        final fallbackSuccess = await launchUrl(
          url,
          mode: LaunchMode.platformDefault,
        );
        if (!fallbackSuccess && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open browser for exercise guide.'),
            ),
          );
        }
      }
    } catch (_) {
      try {
        final fallbackSuccess = await launchUrl(
          url,
          mode: LaunchMode.platformDefault,
        );
        if (!fallbackSuccess && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open browser for exercise guide.'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to open search: $e'),
            ),
          );
        }
      }
    }
  }
}
