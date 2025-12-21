import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:security_system_app/screens/login_screen.dart';
import 'package:security_system_app/screens/dashboard_screen.dart';
import 'package:security_system_app/services/firebase_service.dart';
import 'package:security_system_app/services/local_storage.dart';
import 'package:security_system_app/services/notification_service.dart';
import 'package:security_system_app/utils/themes.dart';
import 'package:workmanager/workmanager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Initialize services
  await LocalStorageService.init();
  await NotificationService.init();
  
  // Initialize background worker for notifications
  Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: false,
  );
  
  runApp(const SecuritySystemApp());
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) {
    // Handle background tasks
    return Future.value(true);
  });
}

class SecuritySystemApp extends StatelessWidget {
  const SecuritySystemApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FirebaseService()),
        ChangeNotifierProvider(create: (_) => LocalStorageService()),
      ],
      child: MaterialApp(
        title: 'Security System',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const AppWrapper(),
      ),
    );
  }
}

class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final storage = LocalStorageService();
    _isLoggedIn = await storage.isUserLoggedIn();
    
    // Start listening to Firebase if logged in
    if (_isLoggedIn) {
      final firebaseService = FirebaseService();
      await firebaseService.initializeListeners();
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return _isLoggedIn ? const DashboardScreen() : const LoginScreen();
  }
}