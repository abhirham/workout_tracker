import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/initial_sync_service.dart';

/// Loading screen shown during initial Firestore sync
/// Displays after first login to download all workout data
class SyncLoadingScreen extends ConsumerStatefulWidget {
  const SyncLoadingScreen({super.key});

  @override
  ConsumerState<SyncLoadingScreen> createState() => _SyncLoadingScreenState();
}

class _SyncLoadingScreenState extends ConsumerState<SyncLoadingScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _performSync();
  }

  Future<void> _performSync() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final syncService = ref.read(initialSyncServiceProvider);
      await syncService.performInitialSync();

      // Sync completed successfully, navigate to home
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = _getErrorMessage(e.toString());
      });
    }
  }

  String _getErrorMessage(String error) {
    if (error.contains('network') || error.contains('SocketException')) {
      return 'No internet connection. Please check your network and try again.';
    } else if (error.contains('permission')) {
      return 'Permission denied. Please check your account permissions.';
    } else {
      return 'Failed to sync workout data. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo
                Icon(
                  Icons.cloud_download,
                  size: 80,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),

                // Title
                Text(
                  _isLoading ? 'Syncing Your Data' : 'Sync Failed',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _isLoading ? theme.colorScheme.primary : theme.colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Description
                if (_isLoading)
                  Text(
                    'Downloading your workout plans from the cloud...\nThis may take a few moments.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),

                const SizedBox(height: 48),

                // Loading indicator or error message
                if (_isLoading)
                  const CircularProgressIndicator()
                else if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _performSync,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Help text
                if (_isLoading)
                  Text(
                    'Please keep your device connected to the internet',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
