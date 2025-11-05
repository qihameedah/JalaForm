import 'package:flutter/material.dart';
import '../../utils/pagination_helper.dart';
import '../../constants/app_dimensions.dart';

/// A wrapper widget that adds pagination controls to any list
///
/// Displays pagination info and next/previous buttons
class PaginatedListWrapper<T> extends StatefulWidget {
  final List<T> items;
  final int itemsPerPage;
  final Widget Function(BuildContext, List<T>) builder;
  final String emptyMessage;

  const PaginatedListWrapper({
    super.key,
    required this.items,
    this.itemsPerPage = 20,
    required this.builder,
    this.emptyMessage = 'No items to display',
  });

  @override
  State<PaginatedListWrapper<T>> createState() => _PaginatedListWrapperState<T>();
}

class _PaginatedListWrapperState<T> extends State<PaginatedListWrapper<T>> {
  int _currentPage = 1;

  PaginationHelper get _pagination => PaginationHelper(
        totalItems: widget.items.length,
        itemsPerPage: widget.itemsPerPage,
        currentPage: _currentPage,
      );

  void _goToPage(int page) {
    setState(() {
      _currentPage = page.clamp(1, _pagination.totalPages);
    });
  }

  void _nextPage() {
    if (_pagination.hasNextPage) {
      _goToPage(_currentPage + 1);
    }
  }

  void _previousPage() {
    if (_pagination.hasPreviousPage) {
      _goToPage(_currentPage - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Center(
        child: Text(
          widget.emptyMessage,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
      );
    }

    final paginatedItems = _pagination.paginate(widget.items);

    return Column(
      children: [
        // Paginated content
        Expanded(
          child: widget.builder(context, paginatedItems),
        ),

        // Pagination controls
        if (_pagination.totalPages > 1)
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingLarge),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Pagination info
                Text(
                  _pagination.getDisplayString(),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),

                // Navigation buttons
                Row(
                  children: [
                    // Previous button
                    IconButton(
                      onPressed: _pagination.hasPreviousPage ? _previousPage : null,
                      icon: const Icon(Icons.chevron_left),
                      tooltip: 'Previous page',
                      color: Colors.blue,
                      disabledColor: Colors.grey.shade400,
                    ),

                    // Page numbers
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.paddingMedium,
                        vertical: AppDimensions.paddingSmall,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.borderRadiusSmall,
                        ),
                      ),
                      child: Text(
                        'Page $_currentPage of ${_pagination.totalPages}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    // Next button
                    IconButton(
                      onPressed: _pagination.hasNextPage ? _nextPage : null,
                      icon: const Icon(Icons.chevron_right),
                      tooltip: 'Next page',
                      color: Colors.blue,
                      disabledColor: Colors.grey.shade400,
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
