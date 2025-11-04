import 'package:flutter/material.dart';

/// Centralized app color constants
///
/// Contains all hardcoded color values used throughout the app
/// to ensure consistency and easy theming.
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // Likert scale colors
  static const Color likertPrimary = Color(0xFF9C27B0);
  static const Color likertBorder = Color(0xFF9C27B0);

  // Field type colors
  static const Color fieldText = Colors.blue;
  static const Color fieldNumber = Colors.deepPurple;
  static const Color fieldEmail = Colors.teal;
  static const Color fieldMultiline = Colors.indigo;
  static const Color fieldTextarea = Colors.blue;
  static const Color fieldDropdown = Colors.amber;
  static const Color fieldCheckbox = Colors.green;
  static const Color fieldRadio = Colors.deepOrange;
  static const Color fieldDate = Colors.red;
  static const Color fieldTime = Colors.purple;
  static const Color fieldImage = Colors.pink;
  static const Color fieldLikert = likertPrimary;

  // Status colors
  static const Color success = Colors.green;
  static const Color error = Colors.red;
  static const Color warning = Colors.orange;
  static const Color info = Colors.blue;

  // Shadow colors
  static Color shadow = Colors.black.withOpacity(0.05);
  static Color shadowMedium = Colors.black.withOpacity(0.1);
  static Color shadowDark = Colors.black.withOpacity(0.2);
}
