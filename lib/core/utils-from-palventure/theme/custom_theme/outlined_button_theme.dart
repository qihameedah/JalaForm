import 'package:flutter/material.dart';

class AppOutlinedButtonTheme{
  AppOutlinedButtonTheme._();

  /// Customize Light Outlined Button Theme


  static final lightOutlinedButtonTheme = OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      elevation: 8,
      foregroundColor: Colors.black,
      side: const BorderSide(color: Colors.green),
      textStyle: const TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),

    ),

  );

  
  /// Customize Dark Outlined Button Theme

  static final darkOutlinedButtonTheme = OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      elevation: 8,
      foregroundColor: Colors.white,
      side: const BorderSide(color: Colors.green),
      textStyle: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),

    ),

  );

}