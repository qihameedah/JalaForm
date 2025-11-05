import 'package:flutter/material.dart';
import 'package:jala_form/features/forms/models/form_field.dart';
import 'package:jala_form/core/theme/app_theme.dart';
import '../constants/app_colors.dart';

/// Helper utility for field type operations
///
/// Provides consistent colors and icons for different field types
/// throughout the application.
class FieldTypeHelper {
  FieldTypeHelper._(); // Private constructor to prevent instantiation

  /// Returns the appropriate color for a given field type
  static Color getColorForFieldType(FieldType type) {
    switch (type) {
      case FieldType.text:
        return AppTheme.primaryColor;
      case FieldType.number:
        return AppColors.fieldNumber;
      case FieldType.email:
        return AppColors.fieldEmail;
      case FieldType.multiline:
        return AppColors.fieldMultiline;
      case FieldType.textarea:
        return AppColors.fieldTextarea;
      case FieldType.dropdown:
        return AppColors.fieldDropdown;
      case FieldType.checkbox:
        return AppColors.fieldCheckbox;
      case FieldType.radio:
        return AppColors.fieldRadio;
      case FieldType.date:
        return AppColors.fieldDate;
      case FieldType.time:
        return AppColors.fieldTime;
      case FieldType.image:
        return AppColors.fieldImage;
      case FieldType.likert:
        return AppColors.fieldLikert;
      default:
        return AppTheme.primaryColor;
    }
  }

  /// Returns the appropriate icon for a given field type
  static IconData getIconForFieldType(FieldType type) {
    switch (type) {
      case FieldType.text:
        return Icons.text_fields;
      case FieldType.number:
        return Icons.numbers;
      case FieldType.email:
        return Icons.email;
      case FieldType.multiline:
        return Icons.short_text;
      case FieldType.textarea:
        return Icons.text_snippet;
      case FieldType.dropdown:
        return Icons.arrow_drop_down_circle;
      case FieldType.checkbox:
        return Icons.check_box;
      case FieldType.radio:
        return Icons.radio_button_checked;
      case FieldType.date:
        return Icons.calendar_today;
      case FieldType.time:
        return Icons.access_time;
      case FieldType.image:
        return Icons.image;
      case FieldType.likert:
        return Icons.poll_outlined;
      default:
        return Icons.input;
    }
  }

  /// Returns a human-readable label for a given field type
  static String getFieldTypeLabel(FieldType type) {
    switch (type) {
      case FieldType.text:
        return 'Text';
      case FieldType.number:
        return 'Number';
      case FieldType.email:
        return 'Email';
      case FieldType.multiline:
        return 'Multiline Text';
      case FieldType.textarea:
        return 'Text Area';
      case FieldType.dropdown:
        return 'Dropdown';
      case FieldType.checkbox:
        return 'Checkbox';
      case FieldType.radio:
        return 'Radio Button';
      case FieldType.date:
        return 'Date';
      case FieldType.time:
        return 'Time';
      case FieldType.image:
        return 'Image';
      case FieldType.likert:
        return 'Likert Scale';
      default:
        return 'Unknown';
    }
  }
}
