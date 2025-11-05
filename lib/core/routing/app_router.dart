// lib/core/routing/app_router.dart

import 'package:flutter/material.dart';
import 'package:jala_form/core/constants/app_routes.dart';
import 'package:jala_form/features/auth/sign_in/screens/auth_screen.dart';
import 'package:jala_form/features/home/screens/home_screen.dart';
import 'package:jala_form/services/supabase_service.dart';

/// Centralized router configuration for the application
///
/// Provides route generation with authentication guards and error handling
class AppRouter {
  AppRouter._(); // Private constructor to prevent instantiation

  /// Generate routes for the application
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    debugPrint('[AppRouter] Navigating to: ${settings.name}');

    // Check authentication status
    final supabaseService = SupabaseService();
    final user = supabaseService.getCurrentUser();
    final isAuthenticated = user != null;

    // Get route name
    final routeName = settings.name ?? AppRoutes.login;

    // Handle authentication redirect
    if (!isAuthenticated && AppRoutes.requiresAuth(routeName)) {
      debugPrint('[AppRouter] Route requires auth, redirecting to login');
      return MaterialPageRoute(
        builder: (_) => const AuthScreen(),
        settings: RouteSettings(name: AppRoutes.login),
      );
    }

    // Redirect authenticated users away from login
    if (isAuthenticated && routeName == AppRoutes.login) {
      debugPrint('[AppRouter] User already authenticated, redirecting to home');
      return MaterialPageRoute(
        builder: (_) => const HomeScreen(),
        settings: RouteSettings(name: AppRoutes.home),
      );
    }

    // Build the route
    return _buildRoute(routeName, settings);
  }

  /// Build route based on route name
  static Route<dynamic>? _buildRoute(String routeName, RouteSettings settings) {
    Widget? screen;

    switch (routeName) {
      case AppRoutes.login:
        screen = const AuthScreen();
        break;

      case AppRoutes.home:
        screen = const HomeScreen();
        break;

      case AppRoutes.dashboard:
        screen = const HomeScreen(); // Currently using HomeScreen for dashboard
        break;

      // Add more routes here as needed
      // case AppRoutes.profile:
      //   screen = const ProfileScreen();
      //   break;

      default:
        // Route not found
        return _buildErrorRoute(routeName);
    }

    return MaterialPageRoute(
      builder: (_) => screen!,
      settings: settings,
    );
  }

  /// Build error route for unknown routes
  static Route<dynamic> _buildErrorRoute(String routeName) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Route not found',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'The route "$routeName" does not exist',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(_).pushReplacementNamed(AppRoutes.home);
                },
                child: const Text('Go to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Get initial route based on authentication status
  static String getInitialRoute() {
    final supabaseService = SupabaseService();
    final user = supabaseService.getCurrentUser();

    if (user != null) {
      return AppRoutes.home;
    } else {
      return AppRoutes.login;
    }
  }

  /// Navigate to a route with type safety
  static Future<T?> navigateTo<T>(
    BuildContext context,
    String routeName, {
    Object? arguments,
    bool replace = false,
  }) {
    if (replace) {
      return Navigator.of(context).pushReplacementNamed<T, Object?>(
        routeName,
        arguments: arguments,
      );
    } else {
      return Navigator.of(context).pushNamed<T>(
        routeName,
        arguments: arguments,
      );
    }
  }

  /// Navigate to home
  static Future<void> navigateToHome(BuildContext context, {bool replace = true}) {
    return navigateTo(context, AppRoutes.home, replace: replace);
  }

  /// Navigate to login
  static Future<void> navigateToLogin(BuildContext context, {bool replace = true}) {
    return navigateTo(context, AppRoutes.login, replace: replace);
  }

  /// Pop until home
  static void popUntilHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.settings.name == AppRoutes.home);
  }

  /// Pop all and navigate to home
  static void resetToHome(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.home,
      (route) => false,
    );
  }

  /// Pop all and navigate to login
  static void resetToLogin(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }
}
