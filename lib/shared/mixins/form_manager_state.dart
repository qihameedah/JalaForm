// lib/shared/mixins/form_manager_state.dart

import 'package:flutter/material.dart';
import 'package:jala_form/features/forms/models/form_field.dart';

/// Mixin that provides form field management functionality
///
/// Eliminates duplicate field management code across form builders/editors
/// Usage: Add `with BaseFormManagerState` to your State class
///
/// Example:
/// ```dart
/// class _FormBuilderState extends State<FormBuilder>
///     with BaseFormManagerState {
///   @override
///   void initState() {
///     super.initState();
///     initializeFields([]); // Start with empty fields
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return Column(
///       children: [
///         ...buildFieldsList(),
///         ElevatedButton(
///           onPressed: () => addField(FormFieldModel(...)),
///           child: Text('Add Field'),
///         ),
///       ],
///     );
///   }
/// }
/// ```
mixin BaseFormManagerState<T extends StatefulWidget> on State<T> {
  /// List of form fields
  List<FormFieldModel> _fields = [];

  /// Whether the form has unsaved changes
  bool _hasUnsavedChanges = false;

  /// Public getter for fields
  List<FormFieldModel> get fields => List.unmodifiable(_fields);

  /// Public getter for unsaved changes flag
  bool get hasUnsavedChanges => _hasUnsavedChanges;

  /// Initialize fields with an initial list
  void initializeFields(List<FormFieldModel> initialFields) {
    if (mounted) {
      setState(() {
        _fields = List.from(initialFields);
        _hasUnsavedChanges = false;
      });
    }
  }

  /// Add a new field to the form
  void addField(FormFieldModel field) {
    if (mounted) {
      setState(() {
        _fields.add(field);
        _hasUnsavedChanges = true;
      });
    }
  }

  /// Remove a field at the specified index
  void removeField(int index) {
    if (index < 0 || index >= _fields.length) {
      debugPrint('Invalid index $index for removeField');
      return;
    }

    if (mounted) {
      setState(() {
        _fields.removeAt(index);
        _hasUnsavedChanges = true;
      });
    }
  }

  /// Update a field at the specified index
  void updateField(int index, FormFieldModel updatedField) {
    if (index < 0 || index >= _fields.length) {
      debugPrint('Invalid index $index for updateField');
      return;
    }

    if (mounted) {
      setState(() {
        _fields[index] = updatedField;
        _hasUnsavedChanges = true;
      });
    }
  }

  /// Reorder fields (drag and drop support)
  void reorderFields(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _fields.length) {
      debugPrint('Invalid oldIndex $oldIndex for reorderFields');
      return;
    }

    if (mounted) {
      setState(() {
        // Adjust newIndex if needed
        if (oldIndex < newIndex) {
          newIndex -= 1;
        }

        // Perform reorder
        final item = _fields.removeAt(oldIndex);
        _fields.insert(newIndex, item);
        _hasUnsavedChanges = true;
      });
    }
  }

  /// Clear all fields
  void clearAllFields() {
    if (mounted) {
      setState(() {
        _fields.clear();
        _hasUnsavedChanges = true;
      });
    }
  }

  /// Mark form as having unsaved changes
  void markAsModified() {
    if (mounted) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    }
  }

  /// Mark form as saved (clear unsaved changes flag)
  void markAsSaved() {
    if (mounted) {
      setState(() {
        _hasUnsavedChanges = false;
      });
    }
  }

  /// Get field count
  int get fieldCount => _fields.length;

  /// Check if form is empty
  bool get isEmpty => _fields.isEmpty;

  /// Check if form is not empty
  bool get isNotEmpty => _fields.isNotEmpty;

  /// Find field by ID
  FormFieldModel? findFieldById(String id) {
    try {
      return _fields.firstWhere((field) => field.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Find field index by ID
  int findFieldIndexById(String id) {
    return _fields.indexWhere((field) => field.id == id);
  }

  /// Duplicate a field at the specified index
  void duplicateField(int index) {
    if (index < 0 || index >= _fields.length) {
      debugPrint('Invalid index $index for duplicateField');
      return;
    }

    final fieldToDuplicate = _fields[index];
    final duplicatedField = FormFieldModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: '${fieldToDuplicate.label} (Copy)',
      type: fieldToDuplicate.type,
      isRequired: fieldToDuplicate.isRequired,
      options: fieldToDuplicate.options != null
          ? List.from(fieldToDuplicate.options!)
          : null,
      placeholder: fieldToDuplicate.placeholder,
      validation: fieldToDuplicate.validation,
      // Copy Likert scale properties if present
      likertScale: fieldToDuplicate.likertScale,
      likertStartLabel: fieldToDuplicate.likertStartLabel,
      likertEndLabel: fieldToDuplicate.likertEndLabel,
      likertMiddleLabel: fieldToDuplicate.likertMiddleLabel,
      likertQuestions: fieldToDuplicate.likertQuestions != null
          ? List.from(fieldToDuplicate.likertQuestions!)
          : null,
    );

    if (mounted) {
      setState(() {
        _fields.insert(index + 1, duplicatedField);
        _hasUnsavedChanges = true;
      });
    }
  }

  /// Move field up (decrease index)
  void moveFieldUp(int index) {
    if (index <= 0 || index >= _fields.length) return;

    reorderFields(index, index - 1);
  }

  /// Move field down (increase index)
  void moveFieldDown(int index) {
    if (index < 0 || index >= _fields.length - 1) return;

    reorderFields(index, index + 2);
  }

  /// Get fields by type
  List<FormFieldModel> getFieldsByType(FieldType type) {
    return _fields.where((field) => field.type == type).toList();
  }

  /// Get required fields
  List<FormFieldModel> getRequiredFields() {
    return _fields.where((field) => field.isRequired).toList();
  }

  /// Get optional fields
  List<FormFieldModel> getOptionalFields() {
    return _fields.where((field) => !field.isRequired).toList();
  }

  /// Validate all fields
  ///
  /// Returns true if all required fields have labels
  bool validateFields() {
    for (final field in _fields) {
      if (field.label.trim().isEmpty) {
        return false;
      }
    }
    return true;
  }

  /// Build a list of field widgets
  ///
  /// Override this method in your State class to customize rendering
  List<Widget> buildFieldsList() {
    return _fields.asMap().entries.map((entry) {
      final index = entry.key;
      final field = entry.value;

      return ListTile(
        key: ValueKey(field.id),
        title: Text(field.label),
        subtitle: Text(field.type.toString()),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () => removeField(index),
        ),
      );
    }).toList();
  }

  /// Reset unsaved changes flag
  ///
  /// Call this after successfully saving the form
  void resetUnsavedChanges() {
    if (mounted) {
      setState(() {
        _hasUnsavedChanges = false;
      });
    }
  }
}
