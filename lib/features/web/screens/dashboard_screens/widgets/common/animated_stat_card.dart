import 'package:flutter/material.dart';

/// Animated stat card widget with responsive design
class AnimatedStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String title;
  final String valueText;
  final int delay;

  const AnimatedStatCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.title,
    required this.valueText,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    // Get screen width to determine responsive sizes
    final screenWidth = MediaQuery.of(context).size.width;

    // Adjust sizes based on screen width
    final isVerySmallScreen = screenWidth < 360;
    final isSmallScreen = screenWidth < 600;
    final isMobileView = screenWidth < 450;

    // Significantly reduced values for mobile
    final containerPadding = isVerySmallScreen
        ? 8.0
        : (isMobileView ? 10.0 : (isSmallScreen ? 12.0 : 16.0));

    // Use smaller vertical padding specifically on mobile to reduce height
    final containerVerticalPadding = isVerySmallScreen
        ? 6.0
        : (isMobileView ? 8.0 : (isSmallScreen ? 10.0 : 16.0));

    // Smaller icon container for mobile
    final iconPadding = isVerySmallScreen
        ? 5.0
        : (isMobileView ? 6.0 : (isSmallScreen ? 8.0 : 12.0));

    // Smaller icon size for mobile
    final iconSize = isVerySmallScreen
        ? 14.0
        : (isMobileView ? 16.0 : (isSmallScreen ? 18.0 : 22.0));

    // Smaller text sizes for mobile
    final valueFontSize = isVerySmallScreen
        ? 14.0
        : (isMobileView ? 15.0 : (isSmallScreen ? 16.0 : 18.0));

    final titleFontSize = isVerySmallScreen
        ? 9.0
        : (isMobileView ? 10.0 : (isSmallScreen ? 11.0 : 13.0));

    // Reduced spacing
    final horizontalSpacing = isVerySmallScreen
        ? 6.0
        : (isMobileView ? 8.0 : (isSmallScreen ? 10.0 : 16.0));

    final verticalSpacing = isVerySmallScreen
        ? 1.0
        : (isMobileView ? 2.0 : (isSmallScreen ? 3.0 : 4.0));

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, animValue, child) {
        return Opacity(
          opacity: animValue,
          child: Transform.translate(
            offset: Offset(
                0, 20 * (1 - animValue)), // Reduced offset animation on mobile
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: containerPadding,
                vertical:
                    containerVerticalPadding, // Different value for vertical to reduce height
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(iconPadding),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: iconSize,
                    ),
                  ),
                  SizedBox(width: horizontalSpacing),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize:
                          MainAxisSize.min, // Important to minimize height
                      children: [
                        Text(
                          valueText,
                          style: TextStyle(
                            fontSize: valueFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                            height: isMobileView
                                ? 1.0
                                : 1.2, // Tighter line height on mobile
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: verticalSpacing),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: titleFontSize,
                            color: Colors.grey.shade600,
                            height: isMobileView
                                ? 1.0
                                : 1.2, // Tighter line height on mobile
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
