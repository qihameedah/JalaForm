import 'package:flutter/material.dart';
import 'package:jala_form/core/theme/app_theme.dart';

/// Navigation button widget for dashboard header
class NavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final bool isCompact;

  const NavButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Adjust spacing based on screen width
    final spacing = screenWidth < 400 ? 2.0 : (isCompact ? 3.0 : 6.0);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 6 : (screenWidth < 400 ? 8 : 12),
              vertical: isCompact ? 6 : (screenWidth < 400 ? 6 : 8)),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.primaryColor.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? Border.all(color: AppTheme.primaryColor.withOpacity(0.3))
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: isCompact ? 16 : (screenWidth < 400 ? 16 : 18),
                color: isActive
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondaryColor,
              ),
              SizedBox(width: isCompact ? 4 : 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  fontSize: isCompact ? 12 : (screenWidth < 400 ? 12 : 14),
                  color: isActive
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
