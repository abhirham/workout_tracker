import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'workout_timer_channel';
  static const String _channelName = 'Workout Timer';
  static const String _channelDescription = 'Notifications for workout rest timer completion';

  // Notification IDs
  static const int _restTimerNotificationId = 1;

  bool _initialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    debugPrint('[NotificationService] Initializing...');

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false, // We'll request manually
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      final initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      if (initialized == true) {
        _initialized = true;
        debugPrint('[NotificationService] Initialized successfully');

        // Create Android notification channel
        await _createAndroidChannel();
      } else {
        debugPrint('[NotificationService] Failed to initialize');
      }
    } catch (e, stackTrace) {
      debugPrint('[NotificationService] Initialization error: $e');
      debugPrint('[NotificationService] Stack trace: $stackTrace');
    }
  }

  /// Create Android notification channel
  Future<void> _createAndroidChannel() async {
    final androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 200, 100, 200]), // Short vibration pattern
      playSound: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    debugPrint('[NotificationService] Android channel created');
  }

  /// Request notification permissions (iOS and Android 13+)
  Future<bool> requestPermissions() async {
    if (!_initialized) {
      await initialize();
    }

    debugPrint('[NotificationService] Requesting permissions...');

    // Request iOS permissions
    final iosPermission = await _notifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: false,
          sound: true,
        );

    // Request Android 13+ permissions
    final androidPermission = await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    final granted = (iosPermission ?? true) && (androidPermission ?? true);

    debugPrint('[NotificationService] Permissions granted: $granted');
    return granted;
  }

  /// Show rest timer complete notification
  Future<void> showRestCompleteNotification() async {
    if (!_initialized) {
      debugPrint('[NotificationService] Not initialized, skipping notification');
      return;
    }

    debugPrint('[NotificationService] Showing rest complete notification');

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      sound: 'default',
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notifications.show(
        _restTimerNotificationId,
        'Rest Complete ✓',
        'Ready for your next set!',
        notificationDetails,
      );
      debugPrint('[NotificationService] Notification shown successfully');
    } catch (e, stackTrace) {
      debugPrint('[NotificationService] Error showing notification: $e');
      debugPrint('[NotificationService] Stack trace: $stackTrace');
    }
  }

  /// Cancel rest timer notification
  Future<void> cancelRestNotification() async {
    if (!_initialized) return;

    await _notifications.cancel(_restTimerNotificationId);
    debugPrint('[NotificationService] Rest notification cancelled');
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    if (!_initialized) return;

    await _notifications.cancelAll();
    debugPrint('[NotificationService] All notifications cancelled');
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('[NotificationService] Notification tapped: ${response.payload}');
    // Could navigate to workout screen here if needed
    // For now, just log the tap
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (!_initialized) {
      await initialize();
    }

    final androidEnabled = await _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.areNotificationsEnabled();

    // iOS doesn't have a direct way to check, assume enabled if initialized
    return androidEnabled ?? _initialized;
  }
}
