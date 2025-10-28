import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:workout_tracker/core/database/app_database.dart';
import 'package:workout_tracker/core/database/database_provider.dart';

final gymCardRepositoryProvider = Provider<GymCardRepository>((ref) {
  return GymCardRepository(ref.read(databaseProvider));
});

class GymCardRepository {
  final AppDatabase _db;

  GymCardRepository(this._db);

  /// Get the file path for the gym card image for a specific user
  Future<String?> getGymCardPath(String userId) async {
    final profile = await (_db.select(_db.userProfiles)
          ..where((tbl) => tbl.userId.equals(userId)))
        .getSingleOrNull();
    return profile?.gymCardPath;
  }

  /// Get the gym card File object if it exists
  Future<File?> getGymCardFile(String userId) async {
    final path = await getGymCardPath(userId);
    print('DEBUG: getGymCardFile - path from DB: $path');
    if (path == null) {
      print('DEBUG: getGymCardFile - path is null, returning null');
      return null;
    }

    final file = File(path);
    final exists = await file.exists();
    print('DEBUG: getGymCardFile - file exists: $exists');
    if (exists) {
      print('DEBUG: getGymCardFile - returning file');
      return file;
    }
    // File doesn't exist but path is in DB - clean up stale data
    print('DEBUG: getGymCardFile - file does not exist, cleaning up');
    await deleteGymCard(userId);
    return null;
  }

  /// Save a gym card image for a user
  /// Returns the file path where the image was saved
  Future<String> saveGymCard(String userId, File imageFile) async {
    print('DEBUG: saveGymCard - userId: $userId, imageFile: ${imageFile.path}');

    // Get the application documents directory
    final appDocDir = await getApplicationDocumentsDirectory();
    final gymCardsDir = Directory(p.join(appDocDir.path, 'gym_cards'));
    print('DEBUG: saveGymCard - gymCardsDir: ${gymCardsDir.path}');

    // Create the gym_cards directory if it doesn't exist
    if (!await gymCardsDir.exists()) {
      await gymCardsDir.create(recursive: true);
      print('DEBUG: saveGymCard - created gymCardsDir');
    }

    // Delete old gym card if it exists
    final oldPath = await getGymCardPath(userId);
    if (oldPath != null) {
      final oldFile = File(oldPath);
      if (await oldFile.exists()) {
        await oldFile.delete();
        print('DEBUG: saveGymCard - deleted old file: $oldPath');
      }
    }

    // Get the file extension
    final extension = p.extension(imageFile.path);
    final fileName = '$userId$extension';
    final newPath = p.join(gymCardsDir.path, fileName);
    print('DEBUG: saveGymCard - newPath: $newPath');

    // Copy the image to the new location
    final savedFile = await imageFile.copy(newPath);
    print('DEBUG: saveGymCard - file copied, savedFile.path: ${savedFile.path}');
    print('DEBUG: saveGymCard - file exists after copy: ${await savedFile.exists()}');

    // Update the database (upsert: insert if not exists, update if exists)
    final existingProfile = await (_db.select(_db.userProfiles)
          ..where((tbl) => tbl.userId.equals(userId)))
        .getSingleOrNull();

    if (existingProfile == null) {
      // Insert new profile - this shouldn't happen in normal flow,
      // but handle it gracefully
      await _db.into(_db.userProfiles).insert(
            UserProfilesCompanion.insert(
              userId: userId,
              displayName: '', // Will be populated by sync service
              email: Value(''),
              gymCardPath: Value(savedFile.path),
              gymCardUpdatedAt: Value(DateTime.now()),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
      print('DEBUG: saveGymCard - new user profile created with gym card');
    } else {
      // Update existing profile
      await (_db.update(_db.userProfiles)
            ..where((tbl) => tbl.userId.equals(userId)))
          .write(
        UserProfilesCompanion(
          gymCardPath: Value(savedFile.path),
          gymCardUpdatedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );
      print('DEBUG: saveGymCard - existing user profile updated');
    }

    return savedFile.path;
  }

  /// Delete the gym card for a user
  Future<void> deleteGymCard(String userId) async {
    // Get the current path
    final path = await getGymCardPath(userId);

    // Delete the file if it exists
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }

    // Update the database to remove the path
    await (_db.update(_db.userProfiles)
          ..where((tbl) => tbl.userId.equals(userId)))
        .write(
      const UserProfilesCompanion(
        gymCardPath: Value(null),
        gymCardUpdatedAt: Value(null),
      ),
    );
  }

  /// Check if a user has a gym card saved
  Future<bool> hasGymCard(String userId) async {
    final file = await getGymCardFile(userId);
    return file != null;
  }
}
