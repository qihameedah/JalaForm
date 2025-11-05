import 'package:flutter/material.dart';
import 'package:jala_form/features/forms/models/user_group.dart';

/// Groups content widget
/// Container for groups display with empty state handling
class GroupsContent extends StatelessWidget {
  final List<UserGroup> userGroups;
  final Widget Function() buildGroupsGrid;
  final Widget Function() buildEmptyGroupsState;

  const GroupsContent({
    super.key,
    required this.userGroups,
    required this.buildGroupsGrid,
    required this.buildEmptyGroupsState,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 600 ? 16.0 : 24.0;

    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding, vertical: horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Groups list with staggered appearance
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: userGroups.isEmpty
                      ? buildEmptyGroupsState()
                      : buildGroupsGrid(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
