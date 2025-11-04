import 'package:flutter/material.dart';
import 'package:jala_form/features/forms/models/user_group.dart';
import '../widgets/groups/groups_header.dart';
import '../widgets/groups/groups_content.dart';
import '../widgets/groups/groups_grid.dart';
import '../widgets/groups/group_card.dart';
import '../widgets/states/empty_groups_state.dart';

/// Groups view - displays and manages user groups
class GroupsView extends StatelessWidget {
  final List<UserGroup> userGroups;
  final bool isLoading;
  final VoidCallback onCreateGroup;
  final Function(UserGroup) onDeleteGroup;
  final Function(UserGroup) onOpenGroupDetails;
  final String Function(DateTime) formatDate;

  const GroupsView({
    super.key,
    required this.userGroups,
    required this.isLoading,
    required this.onCreateGroup,
    required this.onDeleteGroup,
    required this.onOpenGroupDetails,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Animated header section
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: GroupsHeader(
                  groupsCount: userGroups.length,
                  onCreateGroup: onCreateGroup,
                ),
              ),
            );
          },
        ),

        // Groups content
        Expanded(
          child: GroupsContent(
            userGroups: userGroups,
            buildGroupsGrid: () => GroupsGrid(
              groups: userGroups,
              buildGroupCard: (group) => GroupCard(
                group: group,
                onTap: () => onOpenGroupDetails(group),
                onDelete: onDeleteGroup,
                formatDate: formatDate,
              ),
            ),
            buildEmptyGroupsState: () => EmptyGroupsState(
              onCreateGroup: onCreateGroup,
            ),
          ),
        ),
      ],
    );
  }
}
