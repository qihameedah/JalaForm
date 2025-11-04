import 'package:flutter/material.dart';
import 'package:jala_form/features/forms/models/user_group.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

/// Groups grid widget with responsive layout
/// Displays groups in a grid with animations
class GroupsGrid extends StatelessWidget {
  final List<UserGroup> groups;
  final Widget Function(UserGroup) buildGroupCard;

  const GroupsGrid({
    super.key,
    required this.groups,
    required this.buildGroupCard,
  });

  @override
  Widget build(BuildContext context) {
    // Dynamic grid columns based on screen size
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 1;
    if (screenWidth >= 600 && screenWidth < 900) {
      crossAxisCount = 2;
    } else if (screenWidth >= 900 && screenWidth < 1200) {
      crossAxisCount = 3;
    } else if (screenWidth >= 1200) {
      crossAxisCount = 4;
    }

    // Dynamic aspect ratio based on screen size
    double childAspectRatio = 1.6;
    if (screenWidth >= 400 && screenWidth < 500) {
      childAspectRatio = 1.4; // Slightly taller cards for medium-small screens
    } else if (screenWidth < 400) {
      childAspectRatio = 1.2; // Taller cards for very small screens
    }

    // Adjust spacing based on screen size
    final gridSpacing = screenWidth < 600 ? 12.0 : 20.0;

    return AnimationLimiter(
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: childAspectRatio,
          crossAxisSpacing: gridSpacing,
          mainAxisSpacing: gridSpacing,
        ),
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          return AnimationConfiguration.staggeredGrid(
            key: ValueKey(group.id),
            position: index,
            duration: const Duration(milliseconds: 500),
            columnCount: crossAxisCount,
            child: SlideAnimation(
              horizontalOffset: 50.0,
              child: FadeInAnimation(
                curve: Curves.easeOutQuint,
                child: buildGroupCard(group),
              ),
            ),
          );
        },
      ),
    );
  }
}
