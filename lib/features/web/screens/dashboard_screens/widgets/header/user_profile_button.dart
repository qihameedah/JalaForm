import 'package:flutter/material.dart';
import 'package:jala_form/core/theme/app_theme.dart';

/// User profile button widget
class UserProfileButton extends StatelessWidget {
  final String username;
  final VoidCallback onProfilePressed;
  final VoidCallback onLogoutPressed;
  final bool isTabletSize;

  const UserProfileButton({
    super.key,
    required this.username,
    required this.onProfilePressed,
    required this.onLogoutPressed,
    this.isTabletSize = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primaryColor,
            radius: isTabletSize ? 14 : 16,
            child: Text(
              username.isNotEmpty ? username[0].toUpperCase() : 'U',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: isTabletSize ? 12 : 14,
              ),
            ),
          ),
          if (screenWidth >= 600 && !isTabletSize) ...[
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: Text(
                username,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          // For tablet size, just show the icon menu without username
          PopupMenuButton(
            icon: Icon(
              Icons.keyboard_arrow_down,
              size: isTabletSize ? 16 : 18,
              color: Colors.grey.shade600,
            ),
            padding: EdgeInsets.zero,
            offset: const Offset(0, 40),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.account_circle,
                        color: AppTheme.primaryColor,
                        size: isTabletSize ? 16 : 18),
                    const SizedBox(width: 8),
                    const Text('Profile'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout,
                        color: AppTheme.errorColor,
                        size: isTabletSize ? 16 : 18),
                    const SizedBox(width: 8),
                    const Text('Logout'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'profile') {
                onProfilePressed();
              } else if (value == 'logout') {
                onLogoutPressed();
              }
            },
          ),
        ],
      ),
    );
  }
}
