import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Bottom sheet for selecting image source (camera or gallery)
class ImageSourceBottomSheet extends StatelessWidget {
  const ImageSourceBottomSheet({super.key});

  /// Show the bottom sheet and return the selected image file
  static Future<File?> show(BuildContext context) async {
    return await showModalBottomSheet<File?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => const ImageSourceBottomSheet(),
    );
  }

  Future<File?> _pickImage(BuildContext context, ImageSource source) async {
    try {
      print('DEBUG: ImageSourceBottomSheet - Starting image picker with source: $source');
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 2000, // Limit image size to 2000px width
        maxHeight: 2000,
        imageQuality: 85, // Compress to 85% quality
      );

      if (pickedFile == null) {
        print('DEBUG: ImageSourceBottomSheet - User cancelled image selection');
        return null;
      }

      print('DEBUG: ImageSourceBottomSheet - Image selected: ${pickedFile.path}');
      return File(pickedFile.path);
    } catch (e, stackTrace) {
      print('DEBUG: ImageSourceBottomSheet - Error picking image: $e');
      print('DEBUG: ImageSourceBottomSheet - Stack trace: $stackTrace');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Select Image Source',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(),
            // Camera option
            ListTile(
              leading: Icon(
                Icons.camera_alt,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Take Photo'),
              subtitle: const Text('Use camera to capture gym card'),
              onTap: () async {
                final file = await _pickImage(context, ImageSource.camera);
                if (context.mounted) {
                  Navigator.of(context).pop(file);
                }
              },
            ),
            // Gallery option
            ListTile(
              leading: Icon(
                Icons.photo_library,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Choose from Gallery'),
              subtitle: const Text('Select existing photo or screenshot'),
              onTap: () async {
                final file = await _pickImage(context, ImageSource.gallery);
                if (context.mounted) {
                  Navigator.of(context).pop(file);
                }
              },
            ),
            const SizedBox(height: 8),
            // Cancel button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
