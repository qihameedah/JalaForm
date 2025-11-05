// lib/shared/mixins/data_loading.dart

import 'package:flutter/material.dart';

/// Mixin that provides safe data loading with error handling
///
/// Eliminates duplicate try-catch-finally loading patterns
/// Usage: Add `with DataLoadingMixin` to your State class
///
/// Example:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with DataLoadingMixin {
///   List<CustomForm> _forms = [];
///
///   @override
///   void initState() {
///     super.initState();
///     _loadForms();
///   }
///
///   Future<void> _loadForms() async {
///     final forms = await loadDataSafely(
///       () => _supabaseService.getForms(),
///       errorMessage: 'Failed to load forms',
///     );
///     setState(() => _forms = forms);
///   }
/// }
/// ```
mixin DataLoadingMixin<T extends StatefulWidget> on State<T> {
  /// Whether data is currently being loaded
  bool _isLoadingData = false;

  /// Public getter for loading state
  bool get isLoadingData => _isLoadingData;

  /// Loads data safely with automatic error handling
  ///
  /// [operation] - The async operation to execute
  /// [errorMessage] - Custom error message to display
  /// [showSnackBar] - Whether to show a SnackBar on error
  /// [onError] - Optional custom error handler
  ///
  /// Returns the result of the operation or throws
  Future<R> loadDataSafely<R>(
    Future<R> Function() operation, {
    String errorMessage = 'Error loading data',
    bool showSnackBar = true,
    void Function(dynamic error)? onError,
  }) async {
    if (!mounted) {
      throw Exception('Widget not mounted - cannot load data');
    }

    setState(() => _isLoadingData = true);

    try {
      final result = await operation();
      return result;
    } catch (e) {
      debugPrint('$errorMessage: $e');

      // Call custom error handler if provided
      if (onError != null) {
        onError(e);
      }

      // Show snackbar if requested and widget is still mounted
      if (showSnackBar && mounted) {
        _showErrorSnackBar(errorMessage);
      }

      rethrow;
    } finally {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  /// Loads data safely without rethrowing errors
  ///
  /// Useful when you want to handle errors gracefully without stopping execution
  /// Returns null if an error occurs
  Future<R?> loadDataSafelyOrNull<R>(
    Future<R> Function() operation, {
    String errorMessage = 'Error loading data',
    bool showSnackBar = true,
    void Function(dynamic error)? onError,
  }) async {
    try {
      return await loadDataSafely(
        operation,
        errorMessage: errorMessage,
        showSnackBar: showSnackBar,
        onError: onError,
      );
    } catch (e) {
      return null;
    }
  }

  /// Loads data safely with a default value on error
  ///
  /// Returns [defaultValue] if an error occurs
  Future<R> loadDataSafelyOrDefault<R>(
    Future<R> Function() operation, {
    required R defaultValue,
    String errorMessage = 'Error loading data',
    bool showSnackBar = true,
    void Function(dynamic error)? onError,
  }) async {
    try {
      return await loadDataSafely(
        operation,
        errorMessage: errorMessage,
        showSnackBar: showSnackBar,
        onError: onError,
      );
    } catch (e) {
      return defaultValue;
    }
  }

  /// Loads multiple operations in parallel safely
  ///
  /// Example:
  /// ```dart
  /// final results = await loadMultipleSafely([
  ///   () => service.getForms(),
  ///   () => service.getGroups(),
  ///   () => service.getUsers(),
  /// ]);
  /// ```
  Future<List<dynamic>> loadMultipleSafely(
    List<Future<dynamic> Function()> operations, {
    String errorMessage = 'Error loading data',
    bool showSnackBar = true,
  }) async {
    if (!mounted) {
      throw Exception('Widget not mounted - cannot load data');
    }

    setState(() => _isLoadingData = true);

    try {
      final futures = operations.map((op) => op()).toList();
      final results = await Future.wait(futures);
      return results;
    } catch (e) {
      debugPrint('$errorMessage: $e');

      if (showSnackBar && mounted) {
        _showErrorSnackBar(errorMessage);
      }

      rethrow;
    } finally {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  /// Sets loading state manually
  ///
  /// Useful for custom loading scenarios
  void setLoadingState(bool isLoading) {
    if (mounted) {
      setState(() => _isLoadingData = isLoading);
    }
  }

  /// Shows an error snackbar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Shows a success snackbar
  ///
  /// Helper method for showing success messages
  void showSuccessMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Shows an info snackbar
  void showInfoMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
