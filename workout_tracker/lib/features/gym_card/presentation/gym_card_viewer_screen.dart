import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:workout_tracker/features/gym_card/providers/gym_card_provider.dart';
import 'package:workout_tracker/features/gym_card/widgets/image_source_bottom_sheet.dart';

class GymCardViewerScreen extends ConsumerStatefulWidget {
  const GymCardViewerScreen({super.key});

  @override
  ConsumerState<GymCardViewerScreen> createState() =>
      _GymCardViewerScreenState();
}

class _GymCardViewerScreenState extends ConsumerState<GymCardViewerScreen> {
  double? _originalBrightness;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _boostBrightness();
  }

  @override
  void dispose() {
    _restoreBrightness();
    super.dispose();
  }

  Future<void> _boostBrightness() async {
    try {
      // Save the original brightness
      _originalBrightness = await ScreenBrightness().current;
      // Set brightness to max
      await ScreenBrightness().setScreenBrightness(1.0);
    } catch (e) {
      // Brightness control not available on this device - fail silently
      debugPrint('Failed to set brightness: $e');
    }
  }

  Future<void> _restoreBrightness() async {
    try {
      if (_originalBrightness != null) {
        await ScreenBrightness().setScreenBrightness(_originalBrightness!);
      } else {
        await ScreenBrightness().resetScreenBrightness();
      }
    } catch (e) {
      debugPrint('Failed to restore brightness: $e');
    }
  }

  Future<void> _uploadImage() async {
    // Show image source picker
    final imageFile = await ImageSourceBottomSheet.show(context);
    if (imageFile == null) return;

    setState(() => _isLoading = true);

    try {
      // Upload the image using the provider
      await ref.read(gymCardProvider.notifier).uploadImage(imageFile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gym card saved!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving gym card: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteCard() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Gym Card'),
        content: const Text(
          'Are you sure you want to delete your gym membership card? You can add it again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(gymCardProvider.notifier).deleteCard();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gym card deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting gym card: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gymCardAsync = ref.watch(gymCardProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Gym Membership Card'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: gymCardAsync.value != null
            ? [
                if (!_isLoading)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Replace Image',
                    onPressed: _uploadImage,
                  ),
                if (!_isLoading)
                  IconButton(
                    icon: const Icon(Icons.delete),
                    tooltip: 'Delete Card',
                    onPressed: _deleteCard,
                  ),
              ]
            : null,
      ),
      body: gymCardAsync.when(
        data: (file) {
          if (file == null || _isLoading) {
            return _buildEmptyState();
          }
          return _buildImageViewer(file);
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.white70,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading gym card',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  error.toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _uploadImage,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isLoading)
            const CircularProgressIndicator(color: Colors.white)
          else ...[
            Icon(
              Icons.qr_code_2,
              size: 120,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No Gym Card Added',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                'Add a photo of your gym membership card for quick access at the gym',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _uploadImage,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Upload Your Gym Card'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageViewer(File imageFile) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.file(
          imageFile,
          fit: BoxFit.contain,
          semanticLabel: 'Your gym membership barcode',
          errorBuilder: (context, error, stackTrace) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.broken_image,
                  size: 64,
                  color: Colors.white70,
                ),
                const SizedBox(height: 16),
                Text(
                  'Unable to load image',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The image file may be corrupted',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _uploadImage,
                  child: const Text('Upload New Image'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
