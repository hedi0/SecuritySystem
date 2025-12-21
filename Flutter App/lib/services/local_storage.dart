import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocalStorageService extends ChangeNotifier {
  static SharedPreferences? _prefs;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Getters
  static SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception('SharedPreferences not initialized');
    }
    return _prefs!;
  }

  // User authentication
  Future<bool> isUserLoggedIn() async {
    return prefs.getBool('user_logged_in') ?? false;
  }

  Future<void> setUserLoggedIn(bool value) async {
    await prefs.setBool('user_logged_in', value);
    notifyListeners();
  }

  // Server configuration
  Future<String?> getServerUrl() async {
    return prefs.getString('server_url');
  }

  Future<void> setServerUrl(String url) async {
    await prefs.setString('server_url', url);
    notifyListeners();
  }

  Future<String?> getDeviceId() async {
    return prefs.getString('device_id');
  }

  Future<void> setDeviceId(String id) async {
    await prefs.setString('device_id', id);
    notifyListeners();
  }

  // Notification preferences
  Future<bool> getNotificationsEnabled() async {
    return prefs.getBool('notifications_enabled') ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    await prefs.setBool('notifications_enabled', enabled);
    notifyListeners();
  }

  Future<bool> getAlertSoundEnabled() async {
    return prefs.getBool('alert_sound_enabled') ?? true;
  }

  Future<void> setAlertSoundEnabled(bool enabled) async {
    await prefs.setBool('alert_sound_enabled', enabled);
    notifyListeners();
  }

  // Theme preferences
  Future<String?> getThemeMode() async {
    return prefs.getString('theme_mode');
  }

  Future<void> setThemeMode(String mode) async {
    await prefs.setString('theme_mode', mode);
    notifyListeners();
  }

  // Last connection
  Future<String?> getLastConnected() async {
    return prefs.getString('last_connected');
  }

  Future<void> setLastConnected(String timestamp) async {
    await prefs.setString('last_connected', timestamp);
    notifyListeners();
  }

  // Secure storage for sensitive data
  Future<void> saveAuthToken(String token) async {
    await _secureStorage.write(key: 'auth_token', value: token);
  }

  Future<String?> getAuthToken() async {
    return await _secureStorage.read(key: 'auth_token');
  }

  Future<void> deleteAuthToken() async {
    await _secureStorage.delete(key: 'auth_token');
  }

  // Clear all data
  Future<void> clearAll() async {
    await prefs.clear();
    await _secureStorage.deleteAll();
    notifyListeners();
  }

  // Logout
  Future<void> logout() async {
    await setUserLoggedIn(false);
    await deleteAuthToken();
    notifyListeners();
  }
}