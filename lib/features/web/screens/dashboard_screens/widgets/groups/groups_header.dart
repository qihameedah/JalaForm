import 'package:flutter/material.dart';
import 'package:jala_form/core/theme/app_theme.dart';

class GroupsHeader extends StatefulWidget {
  final int groupsCount;
  final VoidCallback onCreateGroup;

  const GroupsHeader({
    super.key,
    required this.groupsCount,
    required this.onCreateGroup,
  });

  @override
  State<GroupsHeader> createState() => _GroupsHeaderState();
}

class _GroupsHeaderState extends State<GroupsHeader> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final isMediumScreen = screenWidth >= 600 && screenWidth < 900;

    final horizontalPadding =
        isSmallScreen ? 16.0 : (isMediumScreen ? 20.0 : 24.0);
    final verticalPadding =
        isSmallScreen ? 16.0 : (isMediumScreen ? 20.0 : 24.0);
    final iconSize = isSmallScreen ? 20.0 : (isMediumScreen ? 24.0 : 28.0);
    final titleSize = isSmallScreen ? 20.0 : (isMediumScreen ? 22.0 : 24.0);
    final subtitleSize = isSmallScreen ? 14.0 : (isMediumScreen ? 15.0 : 16.0);

    return Container(
      padding: EdgeInsets.all(verticalPadding),
      margin: EdgeInsets.fromLTRB(horizontalPadding, verticalPadding,
          horizontalPadding, horizontalPadding / 1.5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.05),
            AppTheme.primaryColor.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.08),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isSmallScreen
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.group_rounded,
                    color: AppTheme.primaryColor,
                    size: iconSize,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Group Management',
                  style: TextStyle(
                    fontSize: titleSize,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Manage your groups to easily share forms with multiple users at once',
                  style: TextStyle(
                    fontSize: subtitleSize,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Create Group',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: widget.onCreateGroup,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMediumScreen ? 12 : 16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.group_rounded,
                    color: AppTheme.primaryColor,
                    size: iconSize,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Group Management',
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Manage your groups to easily share forms with multiple users at once',
                        style: TextStyle(
                          fontSize: subtitleSize,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: Text(isMediumScreen ? 'Create' : 'Create Group',
                      style: const TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMediumScreen ? 14 : 18,
                      vertical: isMediumScreen ? 12 : 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: widget.onCreateGroup,
                ),
              ],
            ),
    );
  }
}
