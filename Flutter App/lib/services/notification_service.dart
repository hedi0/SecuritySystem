import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // Initialize settings for Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Initialize settings for iOS
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
        _onNotificationTap(details);
      },
    );

    // Request permissions
    await _requestPermissions();

    // Setup Firebase messaging
    await _setupFirebaseMessaging();
  }

  static Future<void> _requestPermissions() async {
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestPermission();

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  static Future<void> _setupFirebaseMessaging() async {
    final messaging = FirebaseMessaging.instance;

    // Request permission
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get FCM token
    final token = await messaging.getToken();
    debugPrint('FCM Token: $token');

    // Listen to messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showNotification(
        title: message.notification?.title ?? 'Security Alert',
        body: message.notification?.body ?? 'New security event detected',
        payload: message.data.toString(),
      );
    });

    // Handle background messages
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // Handle notification when app is opened from terminated state
    });
  }

  static Future<void> _showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'security_alerts',
      'Security Alerts',
      channelDescription: 'Security system alerts and notifications',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      styleInformation: BigTextStyleInformation(''),
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  static void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap based on payload
    debugPrint('Notification tapped: ${response.payload}');
  }

  // Custom notification methods
  static Future<void> showMotionAlert(double distance) async {
    await _showNotification(
      title: '🚨 Motion Detected',
      body: 'Movement detected at ${distance.toStringAsFixed(1)} cm',
      payload: 'motion_alert',
    );
  }

  static Future<void> showIntruderAlert() async {
    await _showNotification(
      title: '🚨 INTRUDER ALERT',
      body: 'Unauthorized person detected!',
      payload: 'intruder_alert',
    );
  }

  static Future<void> showVibrationAlert() async {
    await _showNotification(
      title: '🔔 Vibration Detected',
      body: 'Possible tampering detected',
      payload: 'vibration_alert',
    );
  }

  static Future<void> showFaceRecognized(String name) async {
    await _showNotification(
      title: '✅ Access Granted',
      body: 'Welcome $name',
      payload: 'face_recognized',
    );
  }

  static Future<void> showSystemStatus(bool online) async {
    await _showNotification(
      title: online ? '✅ System Online' : '⚠️ System Offline',
      body: online ? 'Security system is now online' : 'Security system is offline',
      payload: 'system_status',
    );
  }
}