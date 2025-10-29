import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../sync/services/progress_sync_service.dart';
import '../../sync/services/auth_service.dart';
import '../../../core/services/user_service.dart';
import '../data/user_preferences_repository.dart';
import 'widgets/rest_timer_settings_bottom_sheet.dart';

/// Settings screen for app configuration and data management
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Account Section
            _buildSectionHeader(theme, 'Account'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Sign Out'),
                    subtitle: const Text('Sign out of your account'),
                    onTap: () => _handleSignOut(context, ref),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Workout Preferences Section
            _buildSectionHeader(theme, 'Workout Preferences'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  _buildRestTimerTile(context, ref),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Data Management Section
            _buildSectionHeader(theme, 'Data Management'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.delete_sweep,
                      color: theme.colorScheme.error,
                    ),
                    title: Text(
                      'Reset All Progress',
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Delete all completed sets and start fresh',
                    ),
                    onTap: () => _showResetConfirmationDialog(context, ref),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // About Section
            _buildSectionHeader(theme, 'About'),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Version'),
                    subtitle: const Text('1.0.0'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildRestTimerTile(BuildContext context, WidgetRef ref) {
    final userService = ref.watch(userServiceProvider);
    final userId = userService.getCurrentUserIdOrThrow();
    final restTimerPreference = ref.watch(restTimerPreferenceProvider(userId));

    return restTimerPreference.when(
      data: (duration) {
        // Format duration for display
        String durationText;
        if (duration < 60) {
          durationText = '${duration}s';
        } else if (duration == 60) {
          durationText = '1 min';
        } else if (duration == 90) {
          durationText = '1.5 min';
        } else if (duration == 120) {
          durationText = '2 min';
        } else {
          durationText = '${duration}s';
        }

        return ListTile(
          leading: const Icon(Icons.timer),
          title: const Text('Rest Timer Duration'),
          subtitle: Text('Time to rest between sets: $durationText'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            showRestTimerSettings(context);
          },
        );
      },
      loading: () => const ListTile(
        leading: Icon(Icons.timer),
        title: Text('Rest Timer Duration'),
        subtitle: Text('Loading...'),
      ),
      error: (error, stack) => ListTile(
        leading: const Icon(Icons.timer),
        title: const Text('Rest Timer Duration'),
        subtitle: Text('Error loading: ${error.toString()}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          showRestTimerSettings(context);
        },
      ),
    );
  }

  Future<void> _handleSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        // Sign out via auth service
        final authService = ref.read(authServiceProvider);
        await authService.signOut();

        if (context.mounted) {
          context.go('/login');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to sign out: ${e.toString()}'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _showResetConfirmationDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final theme = Theme.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          size: 48,
          color: theme.colorScheme.error,
        ),
        title: const Text('Reset All Progress?'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently delete:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('• All completed sets'),
            Text('• Your workout history'),
            Text('• Your current plan progress'),
            SizedBox(height: 16),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            child: const Text('Reset Progress'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _performReset(context, ref);
    }
  }

  Future<void> _performReset(BuildContext context, WidgetRef ref) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Resetting progress...'),
          ],
        ),
      ),
    );

    try {
      final progressService = ref.read(progressSyncServiceProvider);
      await progressService.resetAllProgress();

      if (context.mounted) {
        // Close loading dialog
        Navigator.of(context).pop();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Progress reset successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to home
        context.go('/');
      }
    } catch (e) {
      if (context.mounted) {
        // Close loading dialog
        Navigator.of(context).pop();

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reset progress: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
