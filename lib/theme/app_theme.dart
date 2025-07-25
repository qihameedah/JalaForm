// lib/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  // Primary Colors
  static const Color primaryColor = Color(0xFF3F51B5);
  static const Color secondaryColor = Color(0xFFFF9800);
  static const Color accentColor = Color(0xFF9C27B0);

  // Neutral Colors
  static const Color backgroundColor = Color(0xFFF9FAFC);
  static const Color cardColor = Colors.white;
  static const Color dividerColor = Color(0xFFE0E0E0);

  // Text Colors
  static const Color textPrimaryColor = Color(0xFF2D3748);
  static const Color textSecondaryColor = Color(0xFF718096);

  // Status Colors
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFE53935);
  static const Color warningColor = Color(0xFFFFC107);
  static const Color infoColor = Color(0xFF2196F3);

  // Elevation and Shadow
  static final List<BoxShadow> defaultShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 12,
      offset: const Offset(0, 3),
    ),
  ];

  // Animations
  static const Duration quickAnimation = Duration(milliseconds: 200);
  static const Duration defaultAnimation = Duration(milliseconds: 300);
  static const Duration slowAnimation = Duration(milliseconds: 500);

  // Theme Data
  static final ThemeData lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      secondary: secondaryColor,
      tertiary: accentColor,
    ),
    scaffoldBackgroundColor: backgroundColor,
    cardTheme: CardTheme(
      color: cardColor,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorColor),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: primaryColor),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      shape: const RoundedRectangleBorder(),
    ),
    dialogTheme: DialogTheme(
      elevation: 5,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
    fontFamily: 'NotoSansArabic',
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textPrimaryColor,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textPrimaryColor,
      ),
      displaySmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textPrimaryColor,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: textPrimaryColor,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimaryColor,
      ),
      titleSmall: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimaryColor,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: textPrimaryColor,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: textPrimaryColor,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        color: textSecondaryColor,
      ),
    ),
  );

  // Animation curves
  static const Curve easeInOutCurve = Curves.easeInOutCubic;
  static const Curve easeOutCurve = Curves.easeOutCubic;
  static const Curve easeInCurve = Curves.easeInCubic;

  // Common UI element styles
  static BoxDecoration containerDecoration({Color? color, double radius = 16}) {
    return BoxDecoration(
      color: color ?? cardColor,
      boxShadow: cardShadow,
      border: Border.all(color: dividerColor.withOpacity(0.5), width: 1),
    );
  }

  static BoxDecoration gradientContainerDecoration({double radius = 16}) {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF3F51B5),
          Color(0xFF5C6BC0),
        ],
      ),
      boxShadow: defaultShadow,
    );
  }

  // Stat Item styles
  static BoxDecoration statItemDecoration(Color color) {
    return BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.1),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
      border: Border.all(
        color: color.withOpacity(0.1),
        width: 1,
      ),
    );
  }
}

// Custom animation widget for smooth transitions
class AnimatedVisibility extends StatelessWidget {
  final bool visible;
  final Widget child;
  final Duration duration;
  final Curve curve;

  const AnimatedVisibility({
    Key? key,
    required this.visible,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: duration,
      curve: curve,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 0.1),
        duration: duration,
        curve: curve,
        child: visible ? child : Container(width: 0, height: 0),
      ),
    );
  }
}

// Animation helper class
class FadeSlideTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  final Offset beginOffset;
  final bool fadeIn;

  const FadeSlideTransition({
    Key? key,
    required this.animation,
    required this.child,
    this.beginOffset = const Offset(0, 0.2),
    this.fadeIn = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fadeIn
          ? animation
          : Tween<double>(begin: 1.0, end: 0.0).animate(animation),
      child: SlideTransition(
        position: Tween<Offset>(begin: beginOffset, end: Offset.zero)
            .animate(animation),
        child: child,
      ),
    );
  }
}

// Animation util helper for staggered loading
class AnimationUtils {
  static List<Widget> staggeredList({
    required List<Widget> children,
    double staggerFraction = 0.2,
    Duration duration = const Duration(milliseconds: 600),
    Curve curve = Curves.easeOutQuad,
    required AnimationController controller,
  }) {
    final List<Widget> result = [];

    for (var i = 0; i < children.length; i++) {
      final delay = i * staggerFraction;
      final Animation<double> animation = CurvedAnimation(
        parent: controller,
        curve: Interval(
          delay.clamp(0.0, 0.9),
          (delay + 0.4).clamp(0.0, 1.0),
          curve: curve,
        ),
      );

      result.add(
        FadeSlideTransition(
          animation: animation,
          child: children[i],
        ),
      );
    }

    return result;
  }
}
