import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:security_system_app/services/local_storage.dart';
import 'package:security_system_app/services/firebase_service.dart';
import 'package:security_system_app/utils/constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _serverUrlController = TextEditingController();
  final TextEditingController _deviceIdController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final storage = LocalStorageService();
    final savedUrl = await storage.getServerUrl();
    final savedDeviceId = await storage.getDeviceId();
    
    setState(() {
      _serverUrlController.text = savedUrl ?? AppConstants.serverUrl;
      _deviceIdController.text = savedDeviceId ?? AppConstants.deviceId;
    });
  }

  Future<void> _login() async {
    if (_serverUrlController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter server URL'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final storage = LocalStorageService();
      final firebaseService = context.read<FirebaseService>();

      // Save credentials if remember me is checked
      if (_rememberMe) {
        await storage.setServerUrl(_serverUrlController.text);
        await storage.setDeviceId(_deviceIdController.text);
      }

      // Initialize Firebase listeners
      await firebaseService.initializeListeners();

      // Set user as logged in
      await storage.setUserLoggedIn(true);

      // Navigate to dashboard
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.dashboard);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6C63FF),
              Color(0xFF4A44C6),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // App Logo/Title
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppConstants.primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.security,
                            size: 60,
                            color: AppConstants.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Security System',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ESP32-CAM Monitoring & Control',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // Server URL Field
                    TextFormField(
                      controller: _serverUrlController,
                      decoration: InputDecoration(
                        labelText: 'Server URL',
                        prefixIcon: const Icon(Icons.dns),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        hintText: 'http://192.168.1.100:5000',
                      ),
                      keyboardType: TextInputType.url,
                    ),

                    const SizedBox(height: 20),

                    // Device ID Field
                    TextFormField(
                      controller: _deviceIdController,
                      decoration: InputDecoration(
                        labelText: 'Device ID',
                        prefixIcon: const Icon(Icons.device_hub),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        hintText: 'ESP32_CAM',
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Remember Me Checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                          },
                        ),
                        const Text('Remember credentials'),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            _serverUrlController.text = AppConstants.serverUrl;
                            _deviceIdController.text = AppConstants.deviceId;
                          },
                          child: const Text('Reset to Default'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // Login Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _login,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Icon(Icons.lock_open),
                        label: Text(
                          _isLoading ? 'Connecting...' : 'Connect to System',
                          style: const TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Quick Connect Info
                    ExpansionTile(
                      title: const Text(
                        'Quick Setup Guide',
                        style: TextStyle(fontSize: 14),
                      ),
                      initiallyExpanded: false,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '1. Make sure your Flask server is running',
                                style: TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '2. Update server URL with your computer IP',
                                style: TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '3. Ensure ESP32 is connected to WiFi',
                                style: TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Default URL: ${AppConstants.serverUrl}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Version Info
                    Text(
                      'Version ${AppConstants.appVersion}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}