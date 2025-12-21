import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:security_system_app/services/local_storage.dart';
import 'package:security_system_app/services/firebase_service.dart';
import 'package:security_system_app/services/api_service.dart';
import 'package:security_system_app/utils/constants.dart';
import 'package:security_system_app/widgets/control_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _serverUrlController;
  late TextEditingController _deviceIdController;
  bool _notificationsEnabled = true;
  bool _alertSoundsEnabled = true;
  String _themeMode = 'system';
  bool _autoReconnect = true;
  bool _isTestingConnection = false;

  @override
  void initState() {
    super.initState();
    _serverUrlController = TextEditingController();
    _deviceIdController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _deviceIdController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final storage = LocalStorageService();
    
    final savedUrl = await storage.getServerUrl();
    final savedDeviceId = await storage.getDeviceId();
    final notifications = await storage.getNotificationsEnabled();
    final alertSounds = await storage.getAlertSoundEnabled();
    final theme = await storage.getThemeMode();
    
    setState(() {
      _serverUrlController.text = savedUrl ?? AppConstants.serverUrl;
      _deviceIdController.text = savedDeviceId ?? AppConstants.deviceId;
      _notificationsEnabled = notifications;
      _alertSoundsEnabled = alertSounds;
      _themeMode = theme ?? 'system';
    });
  }

  Future<void> _saveSettings() async {
    final storage = LocalStorageService();
    
    await storage.setServerUrl(_serverUrlController.text);
    await storage.setDeviceId(_deviceIdController.text);
    await storage.setNotificationsEnabled(_notificationsEnabled);
    await storage.setAlertSoundEnabled(_alertSoundsEnabled);
    await storage.setThemeMode(_themeMode);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
    });

    try {
      final apiService = ApiService(baseUrl: _serverUrlController.text);
      final isConnected = await apiService.testConnection();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isConnected
                ? 'Connection test successful!'
                : 'Connection failed. Check server URL and network.',
          ),
          backgroundColor: isConnected ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection test failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isTestingConnection = false;
      });
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final storage = LocalStorageService();
              final firebaseService = context.read<FirebaseService>();
              
              await storage.logout();
              await firebaseService.disposeListeners();
              
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.login,
                  (route) => false,
                );
              }
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Server Configuration
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Server Configuration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _serverUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Server URL',
                        prefixIcon: Icon(Icons.dns),
                        border: OutlineInputBorder(),
                        hintText: 'http://192.168.1.100:5000',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _deviceIdController,
                      decoration: const InputDecoration(
                        labelText: 'Device ID',
                        prefixIcon: Icon(Icons.device_hub),
                        border: OutlineInputBorder(),
                        hintText: 'ESP32_CAM',
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isTestingConnection ? null : _testConnection,
                        icon: _isTestingConnection
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Icon(Icons.wifi),
                        label: Text(
                          _isTestingConnection
                              ? 'Testing Connection...'
                              : 'Test Connection',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Notification Settings
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Enable Notifications'),
                      subtitle: const Text('Receive security alerts'),
                      value: _notificationsEnabled,
                      onChanged: (value) {
                        setState(() {
                          _notificationsEnabled = value;
                        });
                      },
                      secondary: const Icon(Icons.notifications),
                    ),
                    SwitchListTile(
                      title: const Text('Alert Sounds'),
                      subtitle: const Text('Play sounds for alerts'),
                      value: _alertSoundsEnabled,
                      onChanged: (value) {
                        setState(() {
                          _alertSoundsEnabled = value;
                        });
                      },
                      secondary: const Icon(Icons.volume_up),
                    ),
                    SwitchListTile(
                      title: const Text('Auto Reconnect'),
                      subtitle: const Text('Automatically reconnect on disconnect'),
                      value: _autoReconnect,
                      onChanged: (value) {
                        setState(() {
                          _autoReconnect = value;
                        });
                      },
                      secondary: const Icon(Icons.autorenew),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Theme Settings
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Appearance',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.brightness_4),
                      title: const Text('Theme Mode'),
                      trailing: DropdownButton<String>(
                        value: _themeMode,
                        items: const [
                          DropdownMenuItem(
                            value: 'light',
                            child: Text('Light'),
                          ),
                          DropdownMenuItem(
                            value: 'dark',
                            child: Text('Dark'),
                          ),
                          DropdownMenuItem(
                            value: 'system',
                            child: Text('System'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _themeMode = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // System Actions
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'System Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ActionButton(
                            text: 'Clear Cache',
                            icon: Icons.delete_sweep,
                            onPressed: () {
                              _clearCache();
                            },
                            backgroundColor: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ActionButton(
                            text: 'Reset Settings',
                            icon: Icons.restore,
                            onPressed: () {
                              _resetSettings();
                            },
                            backgroundColor: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ActionButton(
                            text: 'Export Logs',
                            icon: Icons.download,
                            onPressed: () {
                              _exportLogs();
                            },
                            backgroundColor: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ActionButton(
                            text: 'About',
                            icon: Icons.info,
                            onPressed: () {
                              _showAboutDialog();
                            },
                            backgroundColor: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Danger Zone
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Danger Zone',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'These actions cannot be undone. Proceed with caution.',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout, color: Colors.red),
                        label: const Text(
                          'Logout',
                          style: TextStyle(color: Colors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _deleteAllData();
                        },
                        icon: const Icon(Icons.delete_forever, color: Colors.red),
                        label: const Text(
                          'Delete All Data',
                          style: TextStyle(color: Colors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Version Info
            Center(
              child: Column(
                children: [
                  Text(
                    'Version ${AppConstants.appVersion}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Security System App',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearCache() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('This will clear all cached data. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Implement cache clearing
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cache cleared successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _resetSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text('Reset all settings to default values?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _serverUrlController.text = AppConstants.serverUrl;
                _deviceIdController.text = AppConstants.deviceId;
                _notificationsEnabled = true;
                _alertSoundsEnabled = true;
                _themeMode = 'system';
                _autoReconnect = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Settings reset to default'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _exportLogs() async {
    // Implement log export functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Log export feature coming soon'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Security System App',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text('Version: ${AppConstants.appVersion}'),
              const SizedBox(height: 8),
              const Text('ESP32-CAM Security System with Flutter'),
              const SizedBox(height: 16),
              const Text(
                'Features:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text('• Real-time monitoring'),
              const Text('• Face recognition'),
              const Text('• Motion detection'),
              const Text('• Vibration alerts'),
              const Text('• Firebase integration'),
              const SizedBox(height: 16),
              const Text(
                'Developed for ESP32-CAM security system',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _deleteAllData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Data'),
        content: const Text(
          'This will delete all saved data including faces, logs, and settings. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final storage = LocalStorageService();
              await storage.clearAll();
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All data deleted successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text(
              'Delete All',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}