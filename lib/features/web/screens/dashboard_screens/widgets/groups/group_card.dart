import 'package:flutter/material.dart';
import 'package:jala_form/core/theme/app_theme.dart';
import 'package:jala_form/features/forms/models/user_group.dart';

/// Individual group card with hover effects and animations
/// Displays group information with member count
class GroupCard extends StatefulWidget {
  final UserGroup group;
  final VoidCallback onTap;
  final Function(UserGroup) onDelete;
  final String Function(DateTime) formatDate;

  const GroupCard({
    super.key,
    required this.group,
    required this.onTap,
    required this.onDelete,
    required this.formatDate,
  });

  @override
  State<GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<GroupCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive adjustments
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final isVerySmallScreen = screenWidth < 400;

    // Adjust text sizes based on screen width
    final titleSize = isVerySmallScreen ? 16.0 : (isSmallScreen ? 17.0 : 18.0);
    final descriptionSize =
        isVerySmallScreen ? 12.0 : (isSmallScreen ? 13.0 : 14.0);
    final metadataSize =
        isVerySmallScreen ? 11.0 : (isSmallScreen ? 12.0 : 13.0);

    // Adjust container padding
    final containerPadding =
        isVerySmallScreen ? 14.0 : (isSmallScreen ? 16.0 : 20.0);

    // Adjust icon size
    final iconSize = isVerySmallScreen ? 20.0 : (isSmallScreen ? 22.0 : 24.0);

    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
          boxShadow: [
            BoxShadow(
              color: isHovered
                  ? AppTheme.primaryColor.withOpacity(0.15)
                  : Colors.black.withOpacity(0.06),
              blurRadius: isHovered ? 15 : 8,
              spreadRadius: isHovered ? 1 : 0,
              offset: isHovered ? const Offset(0, 6) : const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: isHovered
                ? AppTheme.primaryColor.withOpacity(0.3)
                : Colors.grey.shade200,
            width: isHovered ? 1.5 : 1,
          ),
        ),
        transform:
            isHovered ? (Matrix4.identity()..scaleByDouble(1.02)) : Matrix4.identity(),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
            splashColor: AppTheme.primaryColor.withOpacity(0.1),
            highlightColor: AppTheme.primaryColor.withOpacity(0.05),
            child: Padding(
              padding: EdgeInsets.all(containerPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Group header
                  Row(
                    children: [
                      // Animated group icon
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.95, end: 1.05),
                        duration: Duration(milliseconds: isHovered ? 800 : 1800),
                        curve: Curves.easeInOut,
                        builder: (context, scale, child) {
                          return Transform.scale(
                            scale: isHovered ? 1.0 + (scale - 1.0) * 0.5 : 1.0,
                            child: Container(
                              padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryColor
                                        .withOpacity(isHovered ? 0.2 : 0.1),
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.group,
                                size: iconSize,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          );
                        },
                        onEnd: () => setState(() {}), // Restart animation
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.group.name,
                              style: TextStyle(
                                fontSize: titleSize,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.calendar_today_rounded,
                                        size: isSmallScreen ? 10 : 12,
                                        color: Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        widget.formatDate(widget.group.created_at),
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 10 : 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Action menu with animated entry
                      AnimatedOpacity(
                        opacity: isHovered ? 1.0 : 0.7,
                        duration: const Duration(milliseconds: 200),
                        child: PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert,
                            size: isSmallScreen ? 20 : 24,
                            color: isHovered
                                ? AppTheme.primaryColor
                                : Colors.grey.shade600,
                          ),
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          offset: const Offset(0, 40),
                          onSelected: (value) {
                            if (value == 'edit') {
                              widget.onTap();
                            } else if (value == 'delete') {
                              widget.onDelete(widget.group);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_rounded,
                                      color: AppTheme.primaryColor, size: 18),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Edit',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  const Icon(Icons.delete_rounded,
                                      color: Colors.red, size: 18),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Delete',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Group description with optimized visibility
                  Expanded(
                    child: Text(
                      widget.group.description,
                      style: TextStyle(
                        fontSize: descriptionSize,
                        color: AppTheme.textSecondaryColor,
                        height: 1.4,
                      ),
                      maxLines: isVerySmallScreen ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Group members count with animated badge
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 10 : 12,
                      vertical: isSmallScreen ? 6 : 8,
                    ),
                    decoration: BoxDecoration(
                      color: isHovered
                          ? AppTheme.primaryColor.withOpacity(0.15)
                          : AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(isSmallScreen ? 16 : 20),
                      boxShadow: isHovered
                          ? [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.2),
                                blurRadius: 6,
                                spreadRadius: 0,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(
                              scale: isHovered ? 1.0 + (value * 0.2) : 1.0,
                              child: Icon(
                                Icons.person_rounded,
                                size: isSmallScreen ? 12 : 14,
                                color: AppTheme.primaryColor,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.group.memberCount == null
                              ? 'Loading...'
                              : '${widget.group.memberCount} ${widget.group.memberCount == 1 ? "member" : "members"}',
                          style: TextStyle(
                            fontSize: metadataSize,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
