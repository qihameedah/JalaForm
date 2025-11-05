import 'package:jala_form/features/forms/models/custom_form.dart';
import 'package:jala_form/features/forms/models/form_response.dart';

/// Dashboard statistics model
///
/// Precomputed statistics for dashboard display
class DashboardStats {
  final int totalForms;
  final int regularFormsCount;
  final int checklistsCount;
  final int totalResponses;
  final int availableFormsCount;

  const DashboardStats({
    required this.totalForms,
    required this.regularFormsCount,
    required this.checklistsCount,
    required this.totalResponses,
    required this.availableFormsCount,
  });

  /// Compute stats from forms and responses
  ///
  /// This method performs all calculations once and caches the result
  factory DashboardStats.compute({
    required List<CustomForm> myForms,
    required List<CustomForm> availableForms,
    required Map<String, List<FormResponse>> formResponses,
  }) {
    int regularCount = 0;
    int checklistCount = 0;
    int totalResponsesCount = 0;

    // Count forms by type
    for (var form in myForms) {
      if (form.isChecklist) {
        checklistCount++;
      } else {
        regularCount++;
      }
    }

    // Count total responses
    for (var responses in formResponses.values) {
      totalResponsesCount += responses.length;
    }

    return DashboardStats(
      totalForms: myForms.length,
      regularFormsCount: regularCount,
      checklistsCount: checklistCount,
      totalResponses: totalResponsesCount,
      availableFormsCount: availableForms.length,
    );
  }

  /// Empty stats (for initialization)
  const DashboardStats.empty()
      : totalForms = 0,
        regularFormsCount = 0,
        checklistsCount = 0,
        totalResponses = 0,
        availableFormsCount = 0;

  @override
  String toString() {
    return 'DashboardStats(total: $totalForms, regular: $regularFormsCount, '
        'checklists: $checklistsCount, responses: $totalResponses, '
        'available: $availableFormsCount)';
  }
}
