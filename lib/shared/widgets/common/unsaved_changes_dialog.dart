import 'package:flutter/material.dart';
import '../../constants/app_dimensions.dart';
import '../../constants/messages.dart';

/// Reusable dialog for confirming navigation away from unsaved changes
///
/// Shows a warning dialog when the user attempts to leave a screen
/// with unsaved changes. Returns true if user confirms leaving, false otherwise.
class UnsavedChangesDialog extends StatelessWidget {
  const UnsavedChangesDialog({super.key});

  /// Shows the unsaved changes dialog
  ///
  /// Returns a Future<bool?> where:
  /// - true = user wants to leave
  /// - false = user wants to stay
  /// - null = dialog dismissed
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => const UnsavedChangesDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLarge),
      ),
      title: Row(
        children: [
          Icon(
            Icons.warning_amber_outlined,
            color: Colors.orange,
            size: AppDimensions.iconMedium,
          ),
          const SizedBox(width: AppDimensions.spacingMedium),
          const Text(AppMessages.unsavedChangesTitle),
        ],
      ),
      content: const Text(AppMessages.unsavedChangesMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(AppMessages.buttonStay),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
          ),
          child: const Text(AppMessages.buttonLeave),
        ),
      ],
    );
  }
}
