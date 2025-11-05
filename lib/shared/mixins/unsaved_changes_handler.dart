// lib/shared/mixins/unsaved_changes_handler.dart

import 'package:flutter/material.dart';

/// Mixin that provides unsaved changes dialog handling
///
/// Eliminates duplicate unsaved changes dialog code
/// Usage: Add `with UnsavedChangesHandler` to your State class
///
/// Example:
/// ```dart
/// class _FormBuilderState extends State<FormBuilder>
///     with UnsavedChangesHandler {
///   @override
///   bool get hasUnsavedChanges => _formModified;
///
///   @override
///   Widget build(BuildContext context) {
///     return PopScope(
///       canPop: !hasUnsavedChanges,
///       onPopInvoked: handlePopInvoked,
///       child: Scaffold(...),
///     );
///   }
/// }
/// ```
mixin UnsavedChangesHandler<T extends StatefulWidget> on State<T> {
  /// Override this to provide unsaved changes state
  ///
  /// Return true if there are unsaved changes
  bool get hasUnsavedChanges;

  /// Shows the unsaved changes dialog
  ///
  /// Returns true if user wants to leave, false if they want to stay
  Future<bool> showUnsavedChangesDialog() async {
    if (!hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildUnsavedDialog(),
    );

    return result ?? false;
  }

  /// Builds the unsaved changes dialog
  Widget _buildUnsavedDialog() {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 8),
          Text('Unsaved Changes'),
        ],
      ),
      content: const Text(
        'You have unsaved changes. Do you want to leave without saving?',
        style: TextStyle(fontSize: 16),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Stay'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Leave'),
        ),
      ],
    );
  }

  /// Handle PopScope onPopInvoked callback
  ///
  /// Use this with PopScope widget for Flutter 3.12+
  ///
  /// Example:
  /// ```dart
  /// PopScope(
  ///   canPop: !hasUnsavedChanges,
  ///   onPopInvoked: handlePopInvoked,
  ///   child: child,
  /// )
  /// ```
  Future<void> handlePopInvoked(bool didPop) async {
    if (didPop) return;

    final shouldPop = await showUnsavedChangesDialog();

    if (mounted && shouldPop) {
      Navigator.of(context).pop();
    }
  }

  /// Wraps a widget with PopScope for unsaved changes handling
  ///
  /// Convenience method to avoid boilerplate
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Widget build(BuildContext context) {
  ///   return wrapWithUnsavedChangesHandler(
  ///     child: Scaffold(...),
  ///   );
  /// }
  /// ```
  Widget wrapWithUnsavedChangesHandler({required Widget child}) {
    return PopScope(
      canPop: !hasUnsavedChanges,
      onPopInvoked: handlePopInvoked,
      child: child,
    );
  }

  /// Shows a custom unsaved changes dialog with customizable messages
  Future<bool> showCustomUnsavedDialog({
    String? title,
    String? message,
    String? stayButtonText,
    String? leaveButtonText,
  }) async {
    if (!hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 8),
            Text(title ?? 'Unsaved Changes'),
          ],
        ),
        content: Text(
          message ??
              'You have unsaved changes. Do you want to leave without saving?',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(stayButtonText ?? 'Stay'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(leaveButtonText ?? 'Leave'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Shows a save changes dialog with three options: Save, Don't Save, Cancel
  ///
  /// Returns:
  /// - 'save': User wants to save and leave
  /// - 'discard': User wants to leave without saving
  /// - 'cancel': User wants to stay
  Future<String> showSaveChangesDialog() async {
    if (!hasUnsavedChanges) return 'discard';

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.save_outlined, color: Colors.blue),
            SizedBox(width: 8),
            Text('Save Changes?'),
          ],
        ),
        content: const Text(
          'Do you want to save your changes before leaving?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('discard'),
            child: const Text(
              'Don\'t Save',
              style: TextStyle(color: Colors.red),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop('save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    return result ?? 'cancel';
  }

  /// Prompt user to save before leaving
  ///
  /// Returns true if navigation should proceed, false otherwise
  ///
  /// [onSave] callback is called when user chooses to save
  Future<bool> promptSaveBeforeLeaving({
    required Future<bool> Function() onSave,
  }) async {
    if (!hasUnsavedChanges) return true;

    final action = await showSaveChangesDialog();

    switch (action) {
      case 'save':
        // User wants to save
        final saved = await onSave();
        return saved; // Only leave if save succeeded
      case 'discard':
        // User wants to discard changes
        return true;
      case 'cancel':
      default:
        // User wants to cancel
        return false;
    }
  }
}
