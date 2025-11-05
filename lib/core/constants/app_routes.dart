// lib/core/constants/app_routes.dart

/// Centralized route constants for the application
///
/// This eliminates hardcoded route strings throughout the app
/// and provides a single source of truth for all navigation paths.
///
/// Usage:
/// ```dart
/// Navigator.pushNamed(context, AppRoutes.formBuilder);
/// ```
///
/// For future GoRouter migration, these constants can be used as path definitions:
/// ```dart
/// GoRoute(
///   path: AppRoutes.formBuilder,
///   builder: (context, state) => FormBuilderScreen(),
/// )
/// ```
class AppRoutes {
  // Private constructor to prevent instantiation
  AppRoutes._();

  // ==================== Authentication Routes ====================

  /// Login/Sign in screen
  static const String login = '/login';

  /// Registration/Sign up screen
  static const String register = '/register';

  /// Forgot password screen
  static const String forgotPassword = '/forgot-password';

  // ==================== Main Navigation Routes ====================

  /// Home screen (adaptive: shows mobile or web version)
  static const String home = '/home';

  /// Dashboard (primarily for web)
  static const String dashboard = '/dashboard';

  /// Profile screen
  static const String profile = '/profile';

  // ==================== Form Routes ====================

  /// My forms list screen
  static const String myForms = '/forms';

  /// Available forms list screen
  static const String availableForms = '/forms/available';

  /// Form detail/view screen
  /// Use with parameter: formId
  static const String formDetail = '/forms/:formId';

  /// Form builder/create screen
  static const String formBuilder = '/forms/create';

  /// Form edit screen
  /// Use with parameter: formId
  static const String formEdit = '/forms/:formId/edit';

  /// Form responses list screen
  /// Use with parameter: formId
  static const String formResponses = '/forms/:formId/responses';

  /// Form response detail screen
  /// Use with parameters: formId, responseId
  static const String formResponseDetail = '/forms/:formId/responses/:responseId';

  /// Form submission screen (for filling out a form)
  /// Use with parameter: formId
  static const String formSubmit = '/forms/:formId/submit';

  /// Checklist form screen
  /// Use with parameter: formId
  static const String checklistForm = '/forms/:formId/checklist';

  // ==================== Group Routes ====================

  /// Groups list screen
  static const String groups = '/groups';

  /// Group detail screen
  /// Use with parameter: groupId
  static const String groupDetail = '/groups/:groupId';

  /// Group create screen
  static const String groupCreate = '/groups/create';

  /// Group edit screen
  /// Use with parameter: groupId
  static const String groupEdit = '/groups/:groupId/edit';

  /// Group management screen (web)
  static const String groupManagement = '/groups/manage';

  /// Group members screen
  /// Use with parameter: groupId
  static const String groupMembers = '/groups/:groupId/members';

  // ==================== Settings Routes ====================

  /// Settings/preferences screen
  static const String settings = '/settings';

  /// Account settings
  static const String accountSettings = '/settings/account';

  /// Notification settings
  static const String notificationSettings = '/settings/notifications';

  /// Privacy settings
  static const String privacySettings = '/settings/privacy';

  /// About screen
  static const String about = '/settings/about';

  // ==================== Utility Routes ====================

  /// Search screen
  static const String search = '/search';

  /// Notifications list
  static const String notifications = '/notifications';

  // ==================== Error Routes ====================

  /// 404 Not Found screen
  static const String notFound = '/404';

  /// Error screen
  static const String error = '/error';

  // ==================== Route Parameter Keys ====================

  /// Common parameter keys for use with routes
  static const String paramFormId = 'formId';
  static const String paramResponseId = 'responseId';
  static const String paramGroupId = 'groupId';
  static const String paramUserId = 'userId';

  // ==================== Helper Methods ====================

  /// Build a form detail route with the given formId
  static String buildFormDetailRoute(String formId) {
    return formDetail.replaceAll(':formId', formId);
  }

  /// Build a form edit route with the given formId
  static String buildFormEditRoute(String formId) {
    return formEdit.replaceAll(':formId', formId);
  }

  /// Build a form responses route with the given formId
  static String buildFormResponsesRoute(String formId) {
    return formResponses.replaceAll(':formId', formId);
  }

  /// Build a form response detail route with the given formId and responseId
  static String buildFormResponseDetailRoute(String formId, String responseId) {
    return formResponseDetail
        .replaceAll(':formId', formId)
        .replaceAll(':responseId', responseId);
  }

  /// Build a form submit route with the given formId
  static String buildFormSubmitRoute(String formId) {
    return formSubmit.replaceAll(':formId', formId);
  }

  /// Build a group detail route with the given groupId
  static String buildGroupDetailRoute(String groupId) {
    return groupDetail.replaceAll(':groupId', groupId);
  }

  /// Build a group edit route with the given groupId
  static String buildGroupEditRoute(String groupId) {
    return groupEdit.replaceAll(':groupId', groupId);
  }

  /// Build a group members route with the given groupId
  static String buildGroupMembersRoute(String groupId) {
    return groupMembers.replaceAll(':groupId', groupId);
  }

  /// Build a checklist form route with the given formId
  static String buildChecklistFormRoute(String formId) {
    return checklistForm.replaceAll(':formId', formId);
  }

  // ==================== Route Validation ====================

  /// Check if a route requires authentication
  static bool requiresAuth(String route) {
    const publicRoutes = [
      login,
      register,
      forgotPassword,
      error,
      notFound,
    ];

    return !publicRoutes.contains(route);
  }

  /// Get route name without parameters
  static String getRouteTemplate(String route) {
    // Remove leading slash if present
    final cleanRoute = route.startsWith('/') ? route : '/$route';

    // Extract route template (before parameters)
    final parts = cleanRoute.split('?');
    return parts.first;
  }

  /// Get all public routes (no authentication required)
  static List<String> get publicRoutes => [
        login,
        register,
        forgotPassword,
        error,
        notFound,
      ];

  /// Get all protected routes (authentication required)
  static List<String> get protectedRoutes => [
        home,
        dashboard,
        profile,
        myForms,
        availableForms,
        formBuilder,
        groups,
        groupCreate,
        settings,
      ];
}
