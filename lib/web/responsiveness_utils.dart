import 'package:flutter/material.dart';

class ResponsiveUtils {
  // Screen size breakpoints
  static const double mobileBreakpoint = 480.0;
  static const double tabletBreakpoint = 768.0;
  static const double desktopBreakpoint = 1200.0;

  // Determine device type based on width
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= mobileBreakpoint &&
      MediaQuery.of(context).size.width < tabletBreakpoint;

  static bool isSmallDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint &&
      MediaQuery.of(context).size.width < desktopBreakpoint;

  static bool isLargeDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktopBreakpoint;

  // Get appropriate padding based on screen size
  static EdgeInsets getScreenPadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(12.0);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(16.0);
    } else {
      return const EdgeInsets.all(24.0);
    }
  }

  // Get appropriate font size based on screen size
  static double getResponsiveFontSize(BuildContext context,
      {required double defaultSize, double minSize = 12.0}) {
    double scaleFactor = isMobile(context)
        ? 0.8
        : isTablet(context)
            ? 0.9
            : 1.0;
    double responsiveSize = defaultSize * scaleFactor;
    return responsiveSize < minSize ? minSize : responsiveSize;
  }

  // Get responsive width based on percentage of screen width
  static double getResponsiveWidth(BuildContext context, double percentage) {
    return MediaQuery.of(context).size.width * percentage;
  }

  // Get responsive height based on percentage of screen height
  static double getResponsiveHeight(BuildContext context, double percentage) {
    return MediaQuery.of(context).size.height * percentage;
  }

  // Get appropriate item count for grid based on screen size
  static int getResponsiveGridCount(BuildContext context) {
    if (isMobile(context)) {
      return 1;
    } else if (isTablet(context)) {
      return 2;
    } else if (isSmallDesktop(context)) {
      return 3;
    } else {
      return 4;
    }
  }

  // Build responsive widget based on screen size
  static Widget buildResponsiveWidget({
    required BuildContext context,
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
    Widget? largeDesktop,
  }) {
    if (isMobile(context)) {
      return mobile;
    } else if (isTablet(context)) {
      return tablet ?? mobile;
    } else if (isSmallDesktop(context)) {
      return desktop ?? tablet ?? mobile;
    } else {
      return largeDesktop ?? desktop ?? tablet ?? mobile;
    }
  }

  // Get responsive constraint width
  static double getResponsiveConstraintWidth(BuildContext context) {
    if (isMobile(context)) {
      return double.infinity;
    } else if (isTablet(context)) {
      return 680;
    } else if (isSmallDesktop(context)) {
      return 900;
    } else {
      return 1200;
    }
  }

  // Generate a responsive data table with fixed properties
  static Widget responsiveDataTable({
    required BuildContext context,
    required List<DataColumn> columns,
    required List<DataRow> rows,
    double? columnSpacing,
    bool showCheckboxColumn = false,
    Function(bool?)? onSelectAll,
    double? dataRowHeight,
    double? headingRowHeight,
    double? horizontalMargin,
    double? dividerThickness,
  }) {
    // For very small screens, return a scrollable table with only essentials
    if (isMobile(context)) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columnSpacing: columnSpacing ?? 8.0,
            showCheckboxColumn: showCheckboxColumn,
            onSelectAll: onSelectAll,
            dataRowMinHeight: 32.0,
            dataRowMaxHeight: dataRowHeight ?? 48.0, // Fix the constraint issue
            headingRowHeight: headingRowHeight ?? 48.0,
            horizontalMargin: horizontalMargin ?? 16.0,
            dividerThickness: dividerThickness ?? 1.0,
            columns: columns,
            rows: rows,
          ),
        ),
      );
    } else {
      // For larger screens, return a normal table with better spacing
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columnSpacing: columnSpacing ?? 16.0,
            showCheckboxColumn: showCheckboxColumn,
            onSelectAll: onSelectAll,
            dataRowMinHeight: 40.0,
            dataRowMaxHeight: dataRowHeight ?? 56.0, // Fix the constraint issue
            headingRowHeight: headingRowHeight ?? 56.0,
            horizontalMargin: horizontalMargin ?? 24.0,
            dividerThickness: dividerThickness ?? 1.0,
            columns: columns,
            rows: rows,
          ),
        ),
      );
    }
  }
}
