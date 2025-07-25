import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/supabase_service.dart';
import 'web_auth_screen.dart';
import 'web_dashboard.dart';
import '../theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WebInitializationWrapper());
}

class WebInitializationWrapper extends StatefulWidget {
  const WebInitializationWrapper({super.key});

  @override
  State<WebInitializationWrapper> createState() =>
      _WebInitializationWrapperState();
}

class _WebInitializationWrapperState extends State<WebInitializationWrapper> {
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

    // Configure animations globally
    Animate.restartOnHotReload = true;
  }

  Future<void> _initializeApp() async {
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      await SupabaseService.initialize();

      // Improved session restoration logic
      final supabaseService = SupabaseService();
      final sessionRestored = await supabaseService.restoreSession();

      debugPrint('Session restoration result: $sessionRestored');

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
      return const WebApp();
    } else {
      return MaterialApp(
        title: 'Jala Form Web',
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(36),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
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
                      )
                          .animate()
                          .scale(duration: 600.ms)
                          .then()
                          .shimmer(duration: 1200.ms),
                      const SizedBox(height: 24),
                      const Text(
                        'Jala Form',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'NotoSansArabic',
                        ),
                      )
                          .animate()
                          .fade(duration: 500.ms)
                          .slide(begin: const Offset(0, 0.2), end: Offset.zero),
                      const SizedBox(height: 8),
                      const Text(
                        'Web Dashboard',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                          fontFamily: 'NotoSansArabic',
                        ),
                      )
                          .animate()
                          .fade(duration: 500.ms, delay: 200.ms)
                          .slide(begin: const Offset(0, 0.2), end: Offset.zero),
                      const SizedBox(height: 40),
                      if (_isLoading)
                        Column(
                          children: [
                            CircularProgressIndicator(
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Initializing dashboard...',
                              style: TextStyle(
                                fontSize: 16,
                                fontFamily: 'NotoSansArabic',
                              ),
                            ),
                          ],
                        ).animate().fade(duration: 400.ms, delay: 200.ms)
                      else if (_retrying)
                        Column(
                          children: [
                            CircularProgressIndicator(
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Retrying connection... (${_retryCount}/$maxRetries)',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ).animate().fade(duration: 400.ms)
                      else if (_errorMessage.isNotEmpty)
                        Column(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 48,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              _errorMessage,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),
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
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ).animate().fade(duration: 400.ms)
                      else
                        Container(),
                    ],
                  ),
                ).animate().fade(duration: 600.ms).scale(
                    begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
              ],
            ),
          ),
        ),
      );
    }
  }
}

class WebApp extends StatelessWidget {
  const WebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jala Form Web',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3F51B5),
          primary: const Color(0xFF3F51B5),
          secondary: const Color(0xFFFF9800),
          tertiary: const Color(0xFF9C27B0),
        ),
        useMaterial3: true,
        fontFamily: 'NotoSansArabic',
        cardTheme: CardTheme(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: const Color(0xFF3F51B5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
          titleMedium: TextStyle(
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: TextStyle(
            height: 1.5,
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AnimatedAuthWrapper(),
        '/auth': (context) => const WebAuthScreen(),
        '/dashboard': (context) => const WebDashboard(),
      },
    );
  }
}

class AnimatedAuthWrapper extends StatelessWidget {
  const AnimatedAuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final supabaseService = SupabaseService();

    // Verify session is valid
    final user = supabaseService.getCurrentUser();

    // Add debugging to help troubleshoot
    debugPrint(
        'Current user state: ${user != null ? 'Logged in' : 'Not logged in'}');

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      child: user != null ? const WebDashboard() : const WebAuthScreen(),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: Tween<double>(begin: 0.0, end: 1.0).animate(animation),
          child: child,
        );
      },
    );
  }
}
