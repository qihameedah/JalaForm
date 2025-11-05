/// Utility class for date formatting
class DateFormatter {
  /// Formats date to DD/MM/YYYY format
  static String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Formats date and time to DD/MM/YYYY HH:MM format
  static String formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} $hour:$minute';
  }
}
