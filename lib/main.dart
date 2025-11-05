import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:jala_form/core/routing/app_router.dart';
import 'package:jala_form/features/auth/sign_in/screens/auth_screen.dart';
import 'package:jala_form/features/home/screens/home_screen.dart';
import 'package:jala_form/services/supabase_service.dart';
import 'package:jala_form/core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  runApp(const InitializationWrapper());
}

class InitializationWrapper extends StatefulWidget {
  const InitializationWrapper({super.key});

  @override
  State<InitializationWrapper> createState() => _InitializationWrapperState();
}

class _InitializationWrapperState extends State<InitializationWrapper> {
  bool _initialized = false;
  String _errorMessage = '';
  bool _retrying = false;
  int _retryCount = 0;
  static const int maxRetries = 3;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      await SupabaseService.initialize();
      await _restoreSession();

      if (mounted) {
        setState(() {
          _initialized = true;
          _errorMessage = '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (_retryCount < maxRetries) {
        if (mounted) {
          setState(() {
            _retrying = true;
            _retryCount++;
          });
        }

        await Future.delayed(Duration(seconds: 2 * _retryCount));

        if (mounted) {
          setState(() {
            _retrying = false;
          });
          _initializeApp();
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage =
                'Could not connect to the server. Please check your internet connection and try again.';
            _retrying = false;
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');

      if (accessToken != null) {
        final supabaseClient = Supabase.instance.client;
        await supabaseClient.auth.setSession(accessToken);
      }
    } catch (e) {
      debugPrint('Error restoring session: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initialized) {
      return const MyApp();
    } else {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.assignment,
                        size: 80,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Jala Form',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'NotoSansArabic',
                        ),
                      ),
                      const SizedBox(height: 40),
                      if (_isLoading)
                        Column(
                          children: [
                            CircularProgressIndicator(
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Initializing app...',
                              style: TextStyle(
                                fontSize: 16,
                              ),
                            ),
                          ],
                        )
                      else if (_retrying)
                        Column(
                          children: [
                            CircularProgressIndicator(
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Retrying connection... ($_retryCount/$maxRetries)',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        )
                      else if (_errorMessage.isNotEmpty)
                        Column(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.refresh),
                              label: const Text('Try Again'),
                              onPressed: () {
                                setState(() {
                                  _retryCount = 0;
                                  _errorMessage = '';
                                  _isLoading = true;
                                });
                                _initializeApp();
                              },
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: AppTheme.primaryColor,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Container(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}

// ADD THIS NEW APP LIFECYCLE MANAGER CLASS
class AppLifecycleManager extends StatefulWidget {
  final Widget child;

  const AppLifecycleManager({super.key, required this.child});

  @override
  _AppLifecycleManagerState createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<AppLifecycleManager>
    with WidgetsBindingObserver {
  final _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _supabaseService.disposeRealTime();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Re-initialize real-time when app comes to foreground
        _supabaseService.initializeRealTimeSubscriptions();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // Clean up when app goes to background
        _supabaseService.disposeRealTime();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// UPDATE THE MyApp CLASS TO WRAP WITH LIFECYCLE MANAGER
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppLifecycleManager(
      child: MaterialApp(
        title: 'Jala Form',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AuthWrapper(),
        // Use centralized router with authentication guards
        onGenerateRoute: AppRouter.onGenerateRoute,
        // Fallback for named routes that don't have parameters
        routes: {
          '/home': (context) => const HomeScreen(),
          '/login': (context) => const AuthScreen(),
        },
      ),
    );
  }
}

// UPDATE THE AuthWrapper CLASS TO INITIALIZE REAL-TIME ON LOGIN
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _checkUserAndInitializeRealTime();
  }

  Future<void> _checkUserAndInitializeRealTime() async {
    final supabaseService = SupabaseService();
    final user = supabaseService.getCurrentUser();

    if (user != null) {
      // User is logged in, initialize real-time subscriptions
      try {
        await supabaseService.initializeRealTimeSubscriptions();
        debugPrint('Real-time subscriptions initialized on app start');
      } catch (e) {
        debugPrint('Error initializing real-time on app start: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final supabaseService = SupabaseService();
    final user = supabaseService.getCurrentUser();

    if (user != null) {
      return const HomeScreen();
    } else {
      return const AuthScreen();
    }
  }
}
