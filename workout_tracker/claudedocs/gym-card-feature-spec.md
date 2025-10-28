# Gym Membership Card Feature Specification

## Overview
Add the ability to store and quickly access a gym membership barcode/QR code image within the workout tracker app. The feature provides offline access to the membership card without needing to open separate apps or photos.

## User Story
As a gym member, I want to store my gym membership barcode in the workout app so that I can quickly show it at the gym entrance without switching apps or searching through photos.

## Requirements

### Functional Requirements

#### FR1: Image Upload
- Users can upload a gym card image from two sources:
  - **Camera**: Take a new photo of physical gym card
  - **Gallery**: Select existing screenshot/photo from device
- No image cropping/editing after selection (save as-is)
- Supported formats: PNG, JPG, JPEG, HEIC (standard image formats)
- Maximum file size: 10MB (reasonable for photos)
- Single gym card per user (replace workflow for updates)

#### FR2: Local Storage
- Images stored locally on device using `path_provider`
- Storage path: `{app_documents_dir}/gym_cards/{userId}.{ext}`
- Persist across app restarts
- No cloud sync (local-only implementation)
- Clean up old images when replaced

#### FR3: Quick Access UI
- **Floating Action Button (FAB)** on WorkoutPlanListScreen (home screen)
  - Icon: QR code icon (Material Icons: `qr_code` or `qr_code_scanner`)
  - Position: Bottom-right corner
  - Color: Primary theme color for visibility
  - Tooltip: "Gym Card"
- Tapping FAB opens gym card viewer screen
- If no card uploaded yet, show upload prompt

#### FR4: Gym Card Viewer Screen
- Full-screen image display (maximize scanability)
- **Auto-brightness boost**: Temporarily increase screen brightness to max when screen opens, restore on close
- **Pinch-to-zoom**: Users can zoom in/out for better visibility
- **Action Buttons** (bottom sheet or app bar):
  - "Replace Image" → Opens camera/gallery picker
  - "Delete Card" → Confirmation dialog → Remove image
  - "Close" → Return to home screen
- Empty state (no card uploaded):
  - Large QR code icon placeholder
  - "No Gym Card Added" message
  - "Upload Your Gym Card" button → Camera/gallery picker

#### FR5: Image Selection Flow
- Bottom sheet modal with two options:
  1. "Take Photo" → Launch camera
  2. "Choose from Gallery" → File picker
  3. "Cancel" → Close modal
- Loading indicator while saving image
- Success toast: "Gym card saved!"
- Error handling:
  - Camera permission denied → Request permission with explanation
  - File picker error → Show error toast
  - Save failure → Retry option

### Non-Functional Requirements

#### NFR1: Performance
- Image loading time: < 100ms (local file access)
- No network calls required for viewing
- Image cached in memory after first load
- Smooth zoom interactions (60 FPS)

#### NFR2: Offline Compatibility
- Feature works 100% offline (no internet required)
- Images persist after app uninstall only if device backup is enabled

#### NFR3: Platform Support
- Android: Minimum SDK 21 (matches app minimum)
- iOS: Minimum iOS 12.0 (matches app minimum)
- Camera and gallery permissions properly requested

#### NFR4: User Experience
- Consistent Material 3 design with app theme
- Clear feedback for all actions (loading, success, errors)
- Accessibility: Screen reader support, sufficient contrast

## Technical Implementation

### Database Schema (Drift)
Add field to existing `user_profiles` table:
```dart
class UserProfiles extends Table {
  // ... existing fields
  TextColumn get gymCardPath => text().nullable()(); // Local file path
  DateTimeColumn get gymCardUpdatedAt => dateTime().nullable()();
}
```

**Alternative**: Create new `gym_card_images` table if planning to support multiple cards in future.

### Flutter Packages Required
```yaml
dependencies:
  image_picker: ^1.0.4  # Camera/gallery access
  path_provider: ^2.1.1 # Already in use
  # photo_view: ^0.14.0 # Optional: Better zoom functionality
```

### New Files Structure
```
lib/features/gym_card/
├── data/
│   └── gym_card_repository.dart        # CRUD operations
├── presentation/
│   └── gym_card_viewer_screen.dart     # Full-screen viewer
├── providers/
│   └── gym_card_provider.dart          # Riverpod state management
└── widgets/
    └── image_source_bottom_sheet.dart  # Camera/gallery picker
```

### Core Components

#### 1. GymCardRepository
```dart
class GymCardRepository {
  Future<String?> getGymCardPath(String userId);
  Future<void> saveGymCard(String userId, File imageFile);
  Future<void> deleteGymCard(String userId);
  Future<File?> getGymCardFile(String userId);
}
```

#### 2. GymCardProvider (Riverpod)
```dart
@riverpod
class GymCard extends _$GymCard {
  @override
  Future<File?> build(String userId) async {
    // Load gym card file for user
  }

  Future<void> uploadImage(File imageFile) async {
    // Save image locally
  }

  Future<void> deleteCard() async {
    // Remove image
  }
}
```

#### 3. GymCardViewerScreen
- Full-screen widget with `InteractiveViewer` for zoom
- AppBar with "Replace" and "Delete" actions
- Brightness controller lifecycle management
- Empty state handling

#### 4. WorkoutPlanListScreen (Modified)
- Add FloatingActionButton with QR code icon
- Navigate to GymCardViewerScreen on tap
- Position: `floatingActionButtonLocation: FloatingActionButtonLocation.endFloat`

### Permissions Configuration

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
    android:maxSdkVersion="28" />
```

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to capture your gym membership card</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need photo library access to select your gym membership card</string>
```

### Brightness Management
```dart
class BrightnessController {
  static Future<void> setMaxBrightness() async {
    await ScreenBrightness().setScreenBrightness(1.0);
  }

  static Future<void> restoreBrightness() async {
    await ScreenBrightness().resetScreenBrightness();
  }
}
```
Note: Requires `screen_brightness` package or similar.

## User Flow Diagram

```
WorkoutPlanListScreen
    ↓ (Tap FAB - QR code icon)
    ↓
[Has gym card?]
    ├─ Yes → GymCardViewerScreen (full-screen image)
    │         ├─ Pinch to zoom
    │         ├─ Brightness auto-boosted
    │         ├─ Replace → ImageSourceBottomSheet → Save
    │         └─ Delete → Confirmation → Remove
    │
    └─ No → GymCardViewerScreen (empty state)
              ↓ (Tap "Upload" button)
              ↓
         ImageSourceBottomSheet
              ├─ Take Photo → Camera → Save
              ├─ Choose from Gallery → FilePicker → Save
              └─ Cancel
```

## Testing Requirements

### Unit Tests
- [ ] GymCardRepository.saveGymCard() saves file to correct path
- [ ] GymCardRepository.deleteGymCard() removes file
- [ ] GymCardProvider state updates correctly
- [ ] File path generation is correct per userId

### Integration Tests
- [ ] Upload image flow (camera mock)
- [ ] Upload image flow (gallery mock)
- [ ] Delete image flow with confirmation
- [ ] Replace image workflow
- [ ] Empty state → upload → view flow

### Manual Testing
- [ ] Test on Android device (camera + gallery)
- [ ] Test on iOS device (camera + gallery)
- [ ] Test brightness auto-boost (real device only)
- [ ] Test pinch-to-zoom smoothness
- [ ] Test with large images (5-10MB)
- [ ] Test permission denied scenarios
- [ ] Test app restart persistence
- [ ] Test with different image formats (PNG, JPG, HEIC)

## Edge Cases & Error Handling

| Scenario | Handling |
|----------|----------|
| Camera permission denied | Show dialog: "Camera access required. Enable in Settings?" → Open app settings |
| Gallery permission denied | Show dialog: "Photo access required. Enable in Settings?" → Open app settings |
| User cancels image picker | Silently dismiss, no action |
| Image save fails (disk full) | Error toast: "Failed to save image. Check storage space." |
| Image file deleted externally | Show empty state, allow re-upload |
| Very large image (>10MB) | Accept but may be slow to load, consider compression |
| Corrupted image file | Error toast: "Unable to load image. Please upload again." |
| No user ID available | Should not happen (auth required), fallback to error |

## Success Criteria
- [ ] User can upload gym card from camera in < 5 seconds
- [ ] User can upload gym card from gallery in < 3 seconds
- [ ] Image displays full-screen in < 100ms
- [ ] Brightness auto-boosts when viewing card
- [ ] Pinch-to-zoom works smoothly (no lag)
- [ ] Replace/delete actions work reliably
- [ ] Image persists across app restarts
- [ ] Feature works 100% offline
- [ ] No crashes on permission denial
- [ ] Empty state is clear and actionable

## Future Enhancements (Out of Scope for MVP)
- [ ] Multi-card support (multiple gym memberships)
- [ ] Cloud sync to Firebase Storage (cross-device access)
- [ ] Image compression/optimization for storage efficiency
- [ ] Manual brightness slider in viewer
- [ ] Share gym card via messaging apps
- [ ] Crop/rotate image after selection
- [ ] Support for PDF/document formats (membership cards as PDFs)
- [ ] Automatic barcode extraction and display (barcode-only view)

## Implementation Checklist
- [ ] Add `image_picker` and `screen_brightness` dependencies to pubspec.yaml
- [ ] Update Android and iOS permissions in manifest files
- [ ] Add `gymCardPath` field to `user_profiles` table (schema v10)
- [ ] Create `GymCardRepository` with CRUD methods
- [ ] Create `GymCardProvider` (Riverpod)
- [ ] Create `ImageSourceBottomSheet` widget
- [ ] Create `GymCardViewerScreen` with zoom, brightness, actions
- [ ] Add FAB to `WorkoutPlanListScreen`
- [ ] Implement brightness auto-boost lifecycle
- [ ] Add error handling and permission requests
- [ ] Write unit tests for repository
- [ ] Manual testing on Android and iOS devices
- [ ] Update project documentation (CLAUDE.md, todo.md)

## Estimated Timeline
- **Repository + Database**: 1-2 hours
- **Viewer Screen + UI**: 2-3 hours
- **Image Upload Flow**: 1-2 hours
- **Brightness Management**: 1 hour
- **Testing + Bug Fixes**: 2-3 hours
- **Total**: 7-11 hours (1-1.5 days)

## Dependencies on Existing Features
- User authentication (required for user-specific storage)
- Local database (Drift) for storing file paths
- Material 3 theme (consistent styling)
- WorkoutPlanListScreen (FAB integration point)

## Risks & Mitigation
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Image file too large (slow loading) | Medium | Low | Accept as-is, consider compression in future |
| Permission denial on first launch | High | Medium | Clear permission rationale, handle gracefully |
| Brightness API not working on all devices | Low | Low | Fallback to manual brightness, non-critical |
| Users upload non-barcode images | Low | None | No validation needed, user responsibility |
| File storage path changes (OS updates) | Low | Medium | Use `path_provider` best practices |

## Design Mockup Notes
- FAB: Material 3 primary color, QR code icon, bottom-right
- Viewer: Black background, centered image, white action buttons
- Empty state: Centered icon + text + button (Material 3 spacing)
- Bottom sheet: Two large tap targets (camera/gallery), cancel button

## Accessibility Considerations
- FAB has semantic label: "Open gym membership card"
- Viewer screen title: "Gym Membership Card"
- Action buttons have clear labels (not just icons)
- Image has alt text: "Your gym membership barcode"
- Empty state button is keyboard accessible
- High contrast for text on image viewer
