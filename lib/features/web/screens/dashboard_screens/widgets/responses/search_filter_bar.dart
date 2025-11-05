import 'package:flutter/material.dart';

class SearchFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final String sortBy;
  final ValueChanged<String?> onSortChanged;
  final VoidCallback? onFilterPressed;

  const SearchFilterBar({
    super.key,
    required this.searchController,
    required this.sortBy,
    required this.onSortChanged,
    this.onFilterPressed,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmallScreen = screenWidth < 380;
    final isSmallScreen = screenWidth < 600;

    // Adjust paddings based on screen size
    final horizontalPadding =
        isVerySmallScreen ? 8.0 : (isSmallScreen ? 12.0 : 16.0);
    final verticalPadding =
        isVerySmallScreen ? 6.0 : (isSmallScreen ? 8.0 : 8.0);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding, vertical: verticalPadding),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isVerySmallScreen
                  ? _buildVerticalLayout(screenWidth)
                  : _buildHorizontalLayout(screenWidth, isSmallScreen),
            ),
          ),
        );
      },
    );
  }

  // Vertical layout for very small screens
  Widget _buildVerticalLayout(double screenWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search field
        Container(
          height: 40,
          margin: const EdgeInsets.only(bottom: 8),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search forms...',
              prefixIcon: Icon(Icons.search,
                  color: Colors.grey.shade500, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
            style: const TextStyle(fontSize: 13),
          ),
        ),

        // Action row with filter and sort
        Row(
          children: [
            // Filter button
            Expanded(
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onFilterPressed,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.filter_list,
                              size: 16, color: Colors.grey.shade700),
                          const SizedBox(width: 4),
                          Text(
                            'Filter',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Sort dropdown
            Expanded(
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: sortBy,
                      icon: Icon(Icons.keyboard_arrow_down,
                          color: Colors.blue.shade800, size: 16),
                      items: const [
                        DropdownMenuItem(value: 'newest', child: Text('Newest')),
                        DropdownMenuItem(value: 'oldest', child: Text('Oldest')),
                        DropdownMenuItem(
                            value: 'alphabetical', child: Text('A to Z')),
                        DropdownMenuItem(
                            value: 'most_responses', child: Text('Responses ↓')),
                      ],
                      onChanged: onSortChanged,
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Horizontal layout for larger screens
  Widget _buildHorizontalLayout(double screenWidth, bool isSmallScreen) {
    return Row(
      children: [
        // Search field
        Expanded(
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search forms...',
              prefixIcon: Icon(Icons.search,
                  color: Colors.grey.shade500, size: isSmallScreen ? 18 : 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                  vertical: isSmallScreen ? 12 : 16),
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontSize: isSmallScreen ? 13 : 14,
              ),
            ),
            style: TextStyle(
              fontSize: isSmallScreen ? 13 : 14,
            ),
          ),
        ),

        SizedBox(width: isSmallScreen ? 6 : 8),

        // Filter button
        if (!isSmallScreen || screenWidth >= 480)
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onFilterPressed,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 8 : 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.filter_list,
                          size: isSmallScreen ? 16 : 18,
                          color: Colors.grey.shade700),
                      SizedBox(width: isSmallScreen ? 4 : 4),
                      Text(
                        'Filter',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                          fontSize: isSmallScreen ? 12 : 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        SizedBox(width: isSmallScreen ? 6 : 8),

        // Sort dropdown
        Container(
          height: 36,
          padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 8 : 12, vertical: 0),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: sortBy,
              icon: Icon(Icons.keyboard_arrow_down,
                  color: Colors.blue.shade800,
                  size: isSmallScreen ? 16 : 18),
              items: [
                DropdownMenuItem(
                    value: 'newest',
                    child: Text(isSmallScreen ? 'Newest' : 'Newest First')),
                DropdownMenuItem(
                    value: 'oldest',
                    child: Text(isSmallScreen ? 'Oldest' : 'Oldest First')),
                DropdownMenuItem(
                    value: 'alphabetical',
                    child: Text(isSmallScreen ? 'A to Z' : 'Alphabetical')),
                DropdownMenuItem(
                    value: 'most_responses',
                    child: Text(isSmallScreen ? 'Responses ↓' : 'Most Responses')),
              ],
              onChanged: onSortChanged,
              style: TextStyle(
                color: Colors.blue.shade800,
                fontWeight: FontWeight.w500,
                fontSize: isSmallScreen ? 12 : 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
