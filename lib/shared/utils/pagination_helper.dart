/// Pagination utility for managing paginated data
///
/// Helps manage pagination state and provides helper methods
/// for calculating page ranges, total pages, etc.
class PaginationHelper {
  final int totalItems;
  final int itemsPerPage;
  final int currentPage;

  const PaginationHelper({
    required this.totalItems,
    required this.itemsPerPage,
    required this.currentPage,
  });

  /// Total number of pages
  int get totalPages => (totalItems / itemsPerPage).ceil();

  /// Whether there is a previous page
  bool get hasPreviousPage => currentPage > 1;

  /// Whether there is a next page
  bool get hasNextPage => currentPage < totalPages;

  /// Start index for current page (0-based)
  int get startIndex => (currentPage - 1) * itemsPerPage;

  /// End index for current page (0-based, exclusive)
  int get endIndex {
    final calculatedEnd = startIndex + itemsPerPage;
    return calculatedEnd > totalItems ? totalItems : calculatedEnd;
  }

  /// Get a sublist for the current page
  List<T> paginate<T>(List<T> items) {
    if (items.isEmpty || startIndex >= items.length) {
      return [];
    }
    return items.sublist(startIndex, endIndex.clamp(0, items.length));
  }

  /// Create a new instance with updated page number
  PaginationHelper withPage(int newPage) {
    return PaginationHelper(
      totalItems: totalItems,
      itemsPerPage: itemsPerPage,
      currentPage: newPage.clamp(1, totalPages),
    );
  }

  /// Create a new instance with updated total items
  PaginationHelper withTotalItems(int newTotal) {
    return PaginationHelper(
      totalItems: newTotal,
      itemsPerPage: itemsPerPage,
      currentPage: currentPage,
    );
  }

  /// Get display string like "Showing 1-20 of 100"
  String getDisplayString() {
    if (totalItems == 0) {
      return 'No items';
    }
    return 'Showing ${startIndex + 1}-$endIndex of $totalItems';
  }

  @override
  String toString() => getDisplayString();
}
