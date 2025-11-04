import 'package:flutter/material.dart';
import 'package:jala_form/core/theme/app_theme.dart';
import 'nav_button.dart';
import 'user_profile_button.dart';

class DashboardHeader extends StatelessWidget {
  final String currentView;
  final String username;
  final VoidCallback onDashboardPressed;
  final VoidCallback onFormsPressed;
  final VoidCallback onResponsesPressed;
  final VoidCallback onGroupsPressed;
  final VoidCallback onCreateForm;
  final VoidCallback onProfilePressed;
  final VoidCallback onLogoutPressed;

  const DashboardHeader({
    super.key,
    required this.currentView,
    required this.username,
    required this.onDashboardPressed,
    required this.onFormsPressed,
    required this.onResponsesPressed,
    required this.onGroupsPressed,
    required this.onCreateForm,
    required this.onProfilePressed,
    required this.onLogoutPressed,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Define breakpoints more precisely for the in-between sizes
    final isTabletSize = screenWidth >= 600 && screenWidth < 1024;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top row with logo and user profile
          Row(
            children: [
              // Logo - make it more compact on tablet
              Container(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.assignment_rounded,
                  color: AppTheme.primaryColor,
                  size: isTabletSize ? 20 : 22,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Jala Form',
                style: TextStyle(
                  fontSize: isTabletSize ? 15 : 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
              ),

              // On large screens, place tabs in the top row
              if (screenWidth >= 1024)
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      NavButton(
                        label: 'Dashboard',
                        icon: Icons.dashboard_outlined,
                        isActive: currentView == 'dashboard',
                        onTap: onDashboardPressed,
                        isCompact: false,
                      ),
                      NavButton(
                        label: 'Forms',
                        icon: Icons.article_outlined,
                        isActive: currentView == 'forms',
                        onTap: onFormsPressed,
                        isCompact: false,
                      ),
                      NavButton(
                        label: 'Responses',
                        icon: Icons.analytics_outlined,
                        isActive: currentView == 'responses',
                        onTap: onResponsesPressed,
                        isCompact: false,
                      ),
                      NavButton(
                        label: 'Groups',
                        icon: Icons.group_outlined,
                        isActive: currentView == 'groups',
                        onTap: onGroupsPressed,
                        isCompact: false,
                      ),
                    ],
                  ),
                )
              else
                // We need this to push items to the right on tablet sizes
                const Spacer(),

              // Create Form button - adjust size for tablet
              if (screenWidth >= 600)
                Padding(
                  padding: EdgeInsets.only(right: isTabletSize ? 8 : 12),
                  child: ElevatedButton.icon(
                    onPressed: onCreateForm,
                    icon: Icon(Icons.add,
                        color: Colors.white, size: isTabletSize ? 14 : 16),
                    label: Text(
                      isTabletSize ? 'Create' : 'Create Form',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: isTabletSize ? 13 : 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: EdgeInsets.symmetric(
                          horizontal: isTabletSize ? 12 : 16,
                          vertical: isTabletSize ? 8 : 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.add, color: Colors.white, size: 18),
                    onPressed: onCreateForm,
                    color: Colors.white,
                    padding: const EdgeInsets.all(8),
                    constraints:
                        const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ),

              // User profile - make it more compact on tablet
              UserProfileButton(
                username: username,
                isTabletSize: isTabletSize,
                onProfilePressed: onProfilePressed,
                onLogoutPressed: onLogoutPressed,
              ),
            ],
          ),

          // Second row with tabs for medium and small screens
          if (screenWidth < 1024)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment
                      .start, // Align to start to avoid overflow
                  children: [
                    NavButton(
                      label: 'Dashboard',
                      icon: Icons.dashboard_outlined,
                      isActive: currentView == 'dashboard',
                      onTap: onDashboardPressed,
                      isCompact: isTabletSize,
                    ),
                    NavButton(
                      label: 'Forms',
                      icon: Icons.article_outlined,
                      isActive: currentView == 'forms',
                      onTap: onFormsPressed,
                      isCompact: isTabletSize,
                    ),
                    NavButton(
                      label: 'Responses',
                      icon: Icons.analytics_outlined,
                      isActive: currentView == 'responses',
                      onTap: onResponsesPressed,
                      isCompact: isTabletSize,
                    ),
                    NavButton(
                      label: 'Groups',
                      icon: Icons.group_outlined,
                      isActive: currentView == 'groups',
                      onTap: onGroupsPressed,
                      isCompact: isTabletSize,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
