# Phase 3: Routing & Navigation - Complete Guide

## 📋 Overview

Phase 3 implements a centralized routing system with authentication guards, preparing the app for future migration to GoRouter while providing immediate improvements.

## ✅ What Was Implemented

### 1. Centralized Router (`lib/core/routing/app_router.dart`)

**Purpose**: Single source of truth for all routing logic

**Features**:
- ✅ Centralized route generation with `onGenerateRoute`
- ✅ Authentication guards (auto-redirect to login if not authenticated)
- ✅ Automatic redirect from login if already authenticated
- ✅ Error handling for unknown routes
- ✅ Type-safe navigation helpers
- ✅ Integration with AppRoutes constants from Phase 2

**Benefits**:
- **Security**: Routes requiring authentication are protected
- **Consistency**: All navigation goes through one system
- **Maintainability**: Easy to add/modify routes in one place
- **Debugging**: All route changes logged with `debugPrint`

### 2. AppRoutes Integration

Uses the `AppRoutes` constants created in Phase 2:
```dart
AppRoutes.login       // '/login'
AppRoutes.home        // '/home'
AppRoutes.dashboard   // '/dashboard'
// ... 30+ more routes
```

### 3. Authentication Guards

**Automatic Protection**:
```dart
// User tries to access protected route without login
Navigator.pushNamed(context, AppRoutes.dashboard);
// → Automatically redirected to login screen
```

**Protected Routes**:
- All routes except: login, register, forgotPassword
- Uses `AppRoutes.requiresAuth()` to check

## 🔧 Usage Guide

### Basic Navigation

**Using Route Constants**:
```dart
// ✅ Good - Type-safe with constants
Navigator.pushNamed(context, AppRoutes.home);

// ❌ Bad - Magic strings
Navigator.pushNamed(context, '/home');
```

### Using AppRouter Helpers

**Navigate to Home**:
```dart
// Replace current route
AppRouter.navigateToHome(context);

// Push new route
AppRouter.navigateToHome(context, replace: false);
```

**Navigate to Login**:
```dart
AppRouter.navigateToLogin(context);
```

**Generic Navigation**:
```dart
// Push route
AppRouter.navigateTo(context, AppRoutes.profile);

// Replace route
AppRouter.navigateTo(context, AppRoutes.dashboard, replace: true);

// With arguments
AppRouter.navigateTo(
  context,
  AppRoutes.formDetail,
  arguments: {'formId': '123'},
);
```

### Stack Management

**Reset to Home** (clear all navigation history):
```dart
AppRouter.resetToHome(context);
// Useful after: Logout confirmation, completing a flow
```

**Reset to Login** (clear all history):
```dart
AppRouter.resetToLogin(context);
// Useful after: Logout
```

**Pop Until Home**:
```dart
AppRouter.popUntilHome(context);
// Useful when: Deep in navigation stack, want to return to home
```

## 📊 How It Works

### Route Flow

```
User navigates to route
        ↓
AppRouter.onGenerateRoute()
        ↓
Check authentication status
        ↓
    [Authenticated?]
        ↙         ↘
      Yes          No
       ↓            ↓
  Allow access   Redirect to login
       ↓
  Build route
       ↓
  Show screen
```

### Code Flow

1. **User Navigation**:
   ```dart
   Navigator.pushNamed(context, AppRoutes.dashboard);
   ```

2. **Router Intercepts**:
   ```dart
   AppRouter.onGenerateRoute(RouteSettings(name: '/dashboard'))
   ```

3. **Authentication Check**:
   ```dart
   final user = supabaseService.getCurrentUser();
   final isAuthenticated = user != null;

   if (!isAuthenticated && AppRoutes.requiresAuth('/dashboard')) {
     // Redirect to login
   }
   ```

4. **Route Building**:
   ```dart
   return MaterialPageRoute(
     builder: (_) => DashboardScreen(),
     settings: settings,
   );
   ```

## 🛡️ Security Features

### 1. Authentication Guards

**Automatic Protection**:
- Any route marked as requiring auth in `AppRoutes.requiresAuth()`
- Automatically redirects unauthenticated users to login

**Example**:
```dart
// User not logged in
Navigator.pushNamed(context, AppRoutes.myForms);
// → Auto-redirected to AppRoutes.login
```

### 2. Login Redirect Prevention

**Prevents Authenticated Users from Seeing Login**:
```dart
// User already logged in
Navigator.pushNamed(context, AppRoutes.login);
// → Auto-redirected to AppRoutes.home
```

### 3. Debug Logging

All navigation is logged:
```
[AppRouter] Navigating to: /dashboard
[AppRouter] Route requires auth, redirecting to login
```

## 📝 Adding New Routes

### Step 1: Add Route to AppRoutes (Already Done in Phase 2)

```dart
// lib/core/constants/app_routes.dart
class AppRoutes {
  static const String myNewRoute = '/my-new-route';

  // Add to protected routes if needed
  static List<String> get protectedRoutes => [
    home, dashboard, myNewRoute, // Add here
  ];
}
```

### Step 2: Add Route to AppRouter

```dart
// lib/core/routing/app_router.dart

static Route<dynamic>? _buildRoute(String routeName, RouteSettings settings) {
  Widget? screen;

  switch (routeName) {
    case AppRoutes.login:
      screen = const AuthScreen();
      break;

    case AppRoutes.home:
      screen = const HomeScreen();
      break;

    // Add your new route here
    case AppRoutes.myNewRoute:
      screen = const MyNewScreen();
      break;

    // ... rest of routes
  }

  return MaterialPageRoute(
    builder: (_) => screen!,
    settings: settings,
  );
}
```

### Step 3: Navigate

```dart
AppRouter.navigateTo(context, AppRoutes.myNewRoute);
```

## 🔀 Routes with Parameters

### Passing Arguments

```dart
Navigator.pushNamed(
  context,
  AppRoutes.formDetail,
  arguments: {'formId': '123'},
);
```

### Receiving Arguments

```dart
class FormDetailScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final formId = args['formId'] as String;

    // Use formId...
  }
}
```

### Using Route Builders (Better)

For routes with parameters, use the builders in AppRoutes:
```dart
// Instead of:
Navigator.pushNamed(context, '/forms/123/edit');

// Use:
Navigator.pushNamed(
  context,
  AppRoutes.buildFormEditRoute('123'),
); // Returns '/forms/123/edit'
```

## 🎯 Migration Strategy

### Current State (Phase 3)

- ✅ Centralized routing with AppRouter
- ✅ Authentication guards
- ✅ Named routes with MaterialApp
- ✅ Type-safe constants

### Future: GoRouter Migration (Phase 4+)

**Why GoRouter?**
- Deep linking support
- URL-based navigation (web)
- Nested navigation
- Route guards built-in
- Better type safety

**Migration Path**:
1. Add `go_router` dependency
2. Convert AppRouter routes to GoRouter format
3. Update navigation calls
4. Test thoroughly
5. Remove old routing code

**Example GoRouter Setup** (Future):
```dart
final router = GoRouter(
  initialLocation: AppRoutes.login,
  redirect: (context, state) {
    final user = supabaseService.getCurrentUser();
    final isAuthenticated = user != null;

    if (!isAuthenticated && AppRoutes.requiresAuth(state.location)) {
      return AppRoutes.login;
    }

    return null; // No redirect
  },
  routes: [
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomeScreen(),
    ),
    // Parametrized routes
    GoRoute(
      path: '/forms/:formId/edit',
      builder: (context, state) {
        final formId = state.params['formId']!;
        return FormEditScreen(formId: formId);
      },
    ),
  ],
);

// Usage
MaterialApp.router(
  routerConfig: router,
);
```

## 🐛 Debugging

### Enable Route Logging

Already enabled in AppRouter:
```dart
debugPrint('[AppRouter] Navigating to: ${settings.name}');
debugPrint('[AppRouter] Route requires auth, redirecting to login');
```

### Common Issues

**Issue**: Route not found
**Solution**: Check route is added to `_buildRoute()` switch statement

**Issue**: Infinite redirect loop
**Solution**: Check authentication logic, ensure login doesn't require auth

**Issue**: Navigation doesn't work
**Solution**: Ensure you're using `Navigator.of(context)` with correct context

## 📚 Best Practices

### 1. Always Use Constants
```dart
// ✅ Good
Navigator.pushNamed(context, AppRoutes.home);

// ❌ Bad
Navigator.pushNamed(context, '/home');
```

### 2. Use Helper Methods
```dart
// ✅ Good - Clear intent
AppRouter.navigateToHome(context);

// ✅ Also good - Generic
AppRouter.navigateTo(context, AppRoutes.home);

// ❌ Verbose
Navigator.of(context).pushReplacementNamed(AppRoutes.home);
```

### 3. Handle Route Arguments
```dart
// ✅ Good - Type-safe
final formId = AppRoutes.getFormIdFromRoute(settings.name);

// ❌ Bad - Error-prone
final formId = settings.name!.split('/')[2];
```

### 4. Clear Navigation Stack When Needed
```dart
// After logout
AppRouter.resetToLogin(context);

// After major flow completion
AppRouter.resetToHome(context);
```

## ✅ Testing

### Manual Testing Checklist

- [ ] Navigate to home while authenticated
- [ ] Try to access protected route while not authenticated (should redirect to login)
- [ ] Try to access login while authenticated (should redirect to home)
- [ ] Navigate to non-existent route (should show error screen)
- [ ] Use back button after navigation
- [ ] Use navigation helpers (navigateToHome, navigateToLogin)
- [ ] Clear navigation stack (resetToHome, resetToLogin)

### Automated Testing (Future)

```dart
testWidgets('Protected route redirects to login when not authenticated', (tester) async {
  // Setup: User not authenticated

  // Navigate to protected route
  Navigator.pushNamed(context, AppRoutes.dashboard);
  await tester.pumpAndSettle();

  // Verify redirected to login
  expect(find.byType(AuthScreen), findsOneWidget);
});
```

## 🎉 Summary

### What Phase 3 Achieved

1. ✅ **Centralized routing** - All routes in one place
2. ✅ **Authentication guards** - Automatic protection
3. ✅ **Type safety** - Using AppRoutes constants
4. ✅ **Error handling** - Unknown routes handled gracefully
5. ✅ **Helper methods** - Easy navigation
6. ✅ **Debug logging** - All navigation logged
7. ✅ **GoRouter ready** - Easy to migrate later

### Benefits

- **Security**: Protected routes require authentication
- **Maintainability**: Single source of truth for routing
- **Developer Experience**: Type-safe constants, helper methods
- **Debugging**: All navigation logged
- **Future-proof**: Ready for GoRouter migration

### Impact

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Route definition | Scattered | Centralized | 100% |
| Authentication guards | Manual | Automatic | 100% |
| Type safety | Magic strings | Constants | 100% |
| Error handling | None | Comprehensive | ∞% |
| Navigation helpers | 0 | 7 methods | ∞% |

---

**Phase 3 Complete!** 🚀 The app now has a robust routing system with authentication guards, preparing for future GoRouter migration while providing immediate benefits.
