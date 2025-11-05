import 'package:flutter/material.dart';
import 'package:jala_form/core/theme/app_theme.dart';

/// Empty state for when no groups exist
/// Displays an animated message with a create button
class EmptyGroupsState extends StatefulWidget {
  final VoidCallback onCreateGroup;

  const EmptyGroupsState({
    super.key,
    required this.onCreateGroup,
  });

  @override
  State<EmptyGroupsState> createState() => _EmptyGroupsStateState();
}

class _EmptyGroupsStateState extends State<EmptyGroupsState> {
  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for better responsiveness
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Determine responsive sizing
    final isVerySmallScreen = screenWidth < 400;
    final isSmallScreen = screenWidth < 600;
    final isMediumScreen = screenWidth >= 600 && screenWidth < 900;

    // Card width - responsive to screen size
    final double cardWidth = isVerySmallScreen
        ? screenWidth * 0.9
        : (isSmallScreen
            ? screenWidth * 0.85
            : (isMediumScreen ? 500.0 : 600.0));

    // Adjust paddings and sizes based on screen
    final contentPadding =
        isVerySmallScreen ? 20.0 : (isSmallScreen ? 24.0 : 32.0);
    final iconSize = isVerySmallScreen ? 40.0 : (isSmallScreen ? 50.0 : 64.0);
    final titleSize = isVerySmallScreen ? 18.0 : (isSmallScreen ? 20.0 : 24.0);
    final descriptionSize =
        isVerySmallScreen ? 13.0 : (isSmallScreen ? 14.0 : 16.0);
    final buttonPadding = isVerySmallScreen
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
        : (isSmallScreen
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
            : const EdgeInsets.symmetric(horizontal: 24, vertical: 16));

    return Center(
      child: SingleChildScrollView(
        // Add scrolling to prevent overflow
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.scale(
                scale: 0.8 + (0.2 * value),
                child: Container(
                  width: cardWidth,
                  padding: EdgeInsets.all(contentPadding),
                  constraints: BoxConstraints(
                    maxHeight: screenHeight *
                        0.7, // Limit max height to prevent overflow
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(isSmallScreen ? 16 : 24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 15,
                        spreadRadius: 0,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min, // Use min size to prevent expansion
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated icon with responsive sizing
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.95, end: 1.05),
                        duration: const Duration(milliseconds: 2000),
                        curve: Curves.easeInOut,
                        builder: (context, scale, child) {
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              padding: EdgeInsets.all(isVerySmallScreen
                                  ? 16
                                  : (isSmallScreen ? 24 : 32)),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AppTheme.primaryColor.withOpacity(0.2),
                                    blurRadius: 15,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.groups_outlined,
                                size: iconSize,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          );
                        },
                        onEnd: () => setState(() {}), // Restart animation
                      ),

                      SizedBox(
                          height: isVerySmallScreen
                              ? 16
                              : (isSmallScreen ? 20 : 30)),

                      // Title with reveal animation - responsive text size
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutQuad,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: Text(
                                'No Groups Created Yet',
                                style: TextStyle(
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimaryColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        },
                      ),

                      SizedBox(height: isVerySmallScreen ? 12 : 16),

                      // Description with delayed reveal animation
                      FutureBuilder(
                          future:
                              Future.delayed(const Duration(milliseconds: 200)),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
                              return SizedBox(
                                  height: isVerySmallScreen ? 12 : 16);
                            }

                            return TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeOutQuad,
                              builder: (context, value, child) {
                                return Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(0, 20 * (1 - value)),
                                    child: SizedBox(
                                      width: isVerySmallScreen
                                          ? screenWidth * 0.7
                                          : (isSmallScreen
                                              ? screenWidth * 0.6
                                              : 320.0),
                                      child: Text(
                                        'Groups help you organize users for easy form sharing and collaboration',
                                        style: TextStyle(
                                          fontSize: descriptionSize,
                                          color: AppTheme.textSecondaryColor,
                                          height: 1.5,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.visible,
                                        softWrap: true,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          }),

                      SizedBox(
                          height: isVerySmallScreen
                              ? 20
                              : (isSmallScreen ? 30 : 40)),

                      // Button with bounce animation
                      FutureBuilder(
                          future:
                              Future.delayed(const Duration(milliseconds: 400)),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
                              return SizedBox(
                                  height: isVerySmallScreen ? 36 : 46);
                            }

                            return TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 1000),
                              curve: Curves.elasticOut,
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: SizedBox(
                                    width: isVerySmallScreen || isSmallScreen
                                        ? double.infinity
                                        : null,
                                    child: ElevatedButton.icon(
                                      icon: Icon(Icons.add_circle_outline,
                                          color: Colors.white,
                                          size: isVerySmallScreen ? 16 : 18),
                                      label: Text(
                                        isVerySmallScreen
                                            ? 'Create'
                                            : (isSmallScreen
                                                ? 'Create Group'
                                                : 'Create Your First Group'),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isVerySmallScreen
                                              ? 13
                                              : (isSmallScreen ? 14 : 16),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: buttonPadding,
                                        elevation: 4,
                                        shadowColor: AppTheme.primaryColor
                                            .withOpacity(0.4),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                              isSmallScreen ? 8 : 12),
                                        ),
                                      ),
                                      onPressed: widget.onCreateGroup,
                                    ),
                                  ),
                                );
                              },
                            );
                          }),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
