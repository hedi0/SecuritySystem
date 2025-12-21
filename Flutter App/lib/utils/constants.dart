import 'dart:ui';

class AppConstants {
  static const String appName = 'Security System';
  static const String appVersion = '1.0.0';
  static const String deviceId = 'ESP32_CAM';
  
  // Firebase paths
  static const String firebaseLatestPath = 'devices/ESP32_CAM/latest';
  static const String firebaseStatusPath = 'devices/ESP32_CAM/status';
  static const String firebaseSensorDataPath = 'sensor_data';
  static const String firebaseCommandsPath = 'commands/ESP32_CAM';
  static const String firebaseFacesPath = 'faces';
  
  // Server URL (Update with your server IP)
  static const String serverUrl = 'http://YOUR-LAPTOP-IP:5000';
  
  // Event types
  static const List<String> eventTypes = [
    'motion',
    'face',
    'vibration',
    'door',
    'status',
    'alert',
    'system_reboot',
    'firebase_test',
  ];
  
  // Notification channels
  static const String notificationChannelId = 'security_alerts';
  static const String notificationChannelName = 'Security Alerts';
  static const String notificationChannelDescription = 'Security system alerts and notifications';
  
  // Shared Preferences keys
  static const String prefUserLoggedIn = 'user_logged_in';
  static const String prefServerUrl = 'server_url';
  static const String prefNotificationEnabled = 'notifications_enabled';
  static const String prefAlertSoundEnabled = 'alert_sound_enabled';
  static const String prefThemeMode = 'theme_mode';
  static const String prefLastConnected = 'last_connected';
  
  // Colors
  static const primaryColor = Color(0xFF6C63FF);
  static const secondaryColor = Color(0xFF4A44C6);
  static const accentColor = Color(0xFFFF6584);
  static const successColor = Color(0xFF4CAF50);
  static const warningColor = Color(0xFFFF9800);
  static const dangerColor = Color(0xFFF44336);
  static const infoColor = Color(0xFF2196F3);
  
  // API endpoints
  static const String endpointRecognize = '/recognize';
  static const String endpointAddFace = '/add_face';
  static const String endpointStatus = '/status';
  static const String endpointReload = '/reload_faces';
  static const String endpointTest = '/test';
}

class AppRoutes {
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String camera = '/camera';
  static const String faces = '/faces';
  static const String logs = '/logs';
  static const String settings = '/settings';
  static const String about = '/about';
}