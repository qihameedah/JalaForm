// lib/shared/mixins/responsive_values.dart

import 'package:flutter/widgets.dart';

/// Mixin that provides responsive values based on screen size
///
/// Eliminates duplicate responsive logic across multiple screens
/// Usage: Add `with ResponsiveValues` to your State class
///
/// Example:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with ResponsiveValues {
///   @override
///   Widget build(BuildContext context) {
///     return Padding(
///       padding: EdgeInsets.all(responsivePadding),
///       child: Text('Hello', style: TextStyle(fontSize: responsiveFontSize)),
///     );
///   }
/// }
/// ```
mixin ResponsiveValues<T extends StatefulWidget> on State<T> {
  // Screen size breakpoints
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 1024;

  // Cached values to avoid recalculating on every access
  late double _screenWidth;
  late double _screenHeight;
  late bool _isMobile;
  late bool _isTablet;
  late bool _isDesktop;
  late bool _isInitialized = false;

  /// Current screen width
  double get screenWidth => _screenWidth;

  /// Current screen height
  double get screenHeight => _screenHeight;

  /// True if screen width < 600px
  bool get isMobile => _isMobile;

  /// True if screen width >= 600px and < 1024px
  bool get isTablet => _isTablet;

  /// True if screen width >= 1024px
  bool get isDesktop => _isDesktop;

  /// Responsive spacing (6.0 mobile, 8.0 tablet, 10.0 desktop)
  double get responsiveSpacing => _isMobile ? 6.0 : _isTablet ? 8.0 : 10.0;

  /// Responsive padding (10.0 mobile, 12.0 tablet, 14.0 desktop)
  double get responsivePadding => _isMobile ? 10.0 : _isTablet ? 12.0 : 14.0;

  /// Responsive border radius (8.0 mobile, 10.0 desktop)
  double get responsiveBorderRadius => _isMobile ? 8.0 : 10.0;

  /// Responsive font size (14.0 mobile, 15.0 tablet, 16.0 desktop)
  double get responsiveFontSize => _isMobile ? 14.0 : _isTablet ? 15.0 : 16.0;

  /// Responsive icon size (20.0 mobile, 22.0 tablet, 24.0 desktop)
  double get responsiveIconSize => _isMobile ? 20.0 : _isTablet ? 22.0 : 24.0;

  /// Responsive card padding (20.0 mobile, 24.0 tablet, 32.0 desktop)
  double get responsiveCardPadding => _isMobile ? 20.0 : _isTablet ? 24.0 : 32.0;

  /// Responsive horizontal padding (16.0 mobile, 24.0 tablet, 32.0 desktop)
  double get responsiveHorizontalPadding => _isMobile ? 16.0 : _isTablet ? 24.0 : 32.0;

  /// Responsive vertical spacing (12.0 mobile, 16.0 tablet, 20.0 desktop)
  double get responsiveVerticalSpacing => _isMobile ? 12.0 : _isTablet ? 16.0 : 20.0;

  /// Updates responsive values when screen size changes
  void _updateResponsiveValues() {
    final size = MediaQuery.of(context).size;
    _screenWidth = size.width;
    _screenHeight = size.height;
    _isMobile = _screenWidth < mobileBreakpoint;
    _isTablet = _screenWidth >= mobileBreakpoint && _screenWidth < tabletBreakpoint;
    _isDesktop = _screenWidth >= tabletBreakpoint;
    _isInitialized = true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateResponsiveValues();
  }

  /// Helper method to get custom responsive value
  ///
  /// Example:
  /// ```dart
  /// final customPadding = getResponsiveValue(
  ///   mobile: 8.0,
  ///   tablet: 12.0,
  ///   desktop: 16.0,
  /// );
  /// ```
  T getResponsiveValue<T>({
    required T mobile,
    required T tablet,
    required T desktop,
  }) {
    if (!_isInitialized) _updateResponsiveValues();
    if (_isMobile) return mobile;
    if (_isTablet) return tablet;
    return desktop;
  }

  /// Helper method for two-value responsive (mobile/desktop)
  T getResponsiveValueSimple<T>({
    required T mobile,
    required T desktop,
  }) {
    if (!_isInitialized) _updateResponsiveValues();
    return _isMobile ? mobile : desktop;
  }
}
