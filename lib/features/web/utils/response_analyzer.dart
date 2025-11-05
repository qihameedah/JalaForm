import 'package:jala_form/features/forms/models/form_response.dart';

/// Utility class for analyzing form responses
class ResponseAnalyzer {
  /// Gets the most active time period for form responses
  static String getMostActiveTime(List<FormResponse> responses) {
    if (responses.isEmpty) return "N/A";

    Map<String, int> periods = {
      'Morning': 0,
      'Afternoon': 0,
      'Evening': 0,
    };

    for (var response in responses) {
      final hour = response.submitted_at.hour;
      if (hour >= 5 && hour < 12) {
        periods['Morning'] = (periods['Morning'] ?? 0) + 1;
      } else if (hour >= 12 && hour < 18) {
        periods['Afternoon'] = (periods['Afternoon'] ?? 0) + 1;
      } else {
        periods['Evening'] = (periods['Evening'] ?? 0) + 1;
      }
    }

    periods.removeWhere((key, value) => value == 0);
    if (periods.isEmpty) return "N/A";

    return periods.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }
}
