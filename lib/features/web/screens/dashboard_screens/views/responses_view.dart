import 'package:flutter/material.dart';
import 'package:jala_form/core/theme/app_theme.dart';
import 'package:jala_form/features/forms/models/custom_form.dart';
import 'package:jala_form/features/forms/models/form_response.dart';
import '../widgets/responses/responses_header.dart';
import '../widgets/responses/enhanced_form_responses_list.dart';
import '../widgets/responses/search_filter_bar.dart';
import '../widgets/responses/exporting_indicator.dart';
import '../widgets/responses/responses_table.dart';
import '../widgets/common/animated_stat_card.dart';
import '../widgets/common/empty_state.dart';

/// Responses view - displays and manages form responses
class ResponsesView extends StatelessWidget {
  final List<CustomForm> myForms;
  final Map<String, List<FormResponse>> formResponses;
  final int selectedFormIndex;
  final bool isExporting;
  final String searchQuery;
  final String sortBy;
  final TextEditingController searchController;
  final Function(int) onSelectForm;
  final Function(CustomForm) onExportToExcel;
  final Function(CustomForm) onOpenFormSubmission;
  final Function(CustomForm, FormResponse) onShowResponseDetails;
  final VoidCallback onBack;
  final String Function(DateTime) formatDate;
  final String Function(DateTime) formatDateTime;
  final Widget Function(dynamic, dynamic) buildFieldCell;

  const ResponsesView({
    super.key,
    required this.myForms,
    required this.formResponses,
    required this.selectedFormIndex,
    required this.isExporting,
    required this.searchQuery,
    required this.sortBy,
    required this.searchController,
    required this.onSelectForm,
    required this.onExportToExcel,
    required this.onOpenFormSubmission,
    required this.onShowResponseDetails,
    required this.onBack,
    required this.formatDate,
    required this.formatDateTime,
    required this.buildFieldCell,
  });

  @override
  Widget build(BuildContext context) {
    if (myForms.isEmpty) {
      return EmptyState(
        title: 'No Forms Yet',
        message: 'Create your first form to start collecting responses',
        icon: Icons.assignment_outlined,
        actionLabel: null,
        onActionPressed: null,
      );
    }

    // If no form is selected, show the form selection screen
    if (selectedFormIndex == -1) {
      return _buildFormSelectionForResponses(context);
    }

    // Show the responses for the selected form
    return _buildFormResponsesView(context);
  }

  Widget _buildFormSelectionForResponses(BuildContext context) {
    // Filter and sort forms based on search query and sort option
    List<CustomForm> filteredForms = myForms;
    if (searchQuery.isNotEmpty) {
      filteredForms = myForms
          .where((form) =>
              form.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
              form.description.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
    }

    // Sort forms
    _sortForms(filteredForms);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Animated header
          ResponsesHeader(
            title: 'Form Responses',
            subtitle: 'Select a form below to view detailed submission data and analytics',
          ),

          // Search and filter bar
          SearchFilterBar(
            searchController: searchController,
            sortBy: sortBy,
            onSearchChanged: (value) {}, // Handled by controller
          ),

          // Form list or empty state
          Expanded(
            child: filteredForms.isEmpty
                ? EmptyState(
                    title: 'No Forms Found',
                    message: 'Try adjusting your search or create a new form',
                    icon: Icons.analytics_rounded,
                    actionLabel: null,
                    onActionPressed: null,
                  )
                : EnhancedFormResponsesList(
                    forms: filteredForms,
                    formResponses: formResponses,
                    onFormSelected: (index) => onSelectForm(
                        myForms.indexOf(filteredForms[index])),
                    formatDate: formatDate,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormResponsesView(BuildContext context) {
    if (selectedFormIndex < 0 || selectedFormIndex >= myForms.length) {
      return const Center(child: Text('No form selected'));
    }

    final form = myForms[selectedFormIndex];
    final responses = formResponses[form.id] ?? [];
    final screenWidth = MediaQuery.of(context).size.width;

    if (isExporting) {
      return const ExportingIndicator();
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fixed Header Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Back button
                  Material(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: onBack,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: const Icon(Icons.arrow_back, size: 20),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Form title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          form.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (form.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            form.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Export button
                  SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                      onPressed: () => onExportToExcel(form),
                      icon: const Icon(Icons.download_rounded,
                          color: Colors.white, size: 16),
                      label: Text(
                        screenWidth < 400 ? "Export" : "Export to Excel",
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        padding: EdgeInsets.symmetric(
                            horizontal: screenWidth < 400 ? 10 : 12,
                            vertical: 10),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Stats cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: _buildStatsCards(screenWidth, responses),
            ),

            // Responses table
            Expanded(
              child: responses.isEmpty
                  ? EmptyState(
                      title: 'No Responses Yet',
                      message: 'This form hasn\'t received any responses',
                      icon: Icons.inbox_outlined,
                      actionLabel: 'Submit Response',
                      onActionPressed: () => onOpenFormSubmission(form),
                    )
                  : ResponsesTable(
                      form: form,
                      responses: responses,
                      onShowDetails: onShowResponseDetails,
                      onExportToPdf: (form, response) {}, // Implement if needed
                      formatDateTime: formatDateTime,
                      buildFieldCell: buildFieldCell,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards(double screenWidth, List<FormResponse> responses) {
    final lastResponse = responses.isNotEmpty
        ? responses.reduce((a, b) => a.submitted_at.isAfter(b.submitted_at) ? a : b)
        : null;

    if (screenWidth < 450) {
      return Column(
        children: [
          AnimatedStatCard(
            icon: Icons.analytics_rounded,
            iconColor: Colors.blue,
            backgroundColor: Colors.blue.shade50,
            title: "Total Responses",
            valueText: "${responses.length}",
            delay: 0,
          ),
          const SizedBox(height: 6),
          AnimatedStatCard(
            icon: Icons.calendar_today_rounded,
            iconColor: Colors.green,
            backgroundColor: Colors.green.shade50,
            title: "Last Response",
            valueText: lastResponse != null
                ? formatDateTime(lastResponse.submitted_at)
                : "No responses",
            delay: 100,
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: AnimatedStatCard(
              icon: Icons.analytics_rounded,
              iconColor: Colors.blue,
              backgroundColor: Colors.blue.shade50,
              title: "Total Responses",
              valueText: "${responses.length}",
              delay: 0,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AnimatedStatCard(
              icon: Icons.calendar_today_rounded,
              iconColor: Colors.green,
              backgroundColor: Colors.green.shade50,
              title: "Last Response",
              valueText: lastResponse != null
                  ? formatDateTime(lastResponse.submitted_at)
                  : "No responses",
              delay: 100,
            ),
          ),
        ],
      );
    }
  }

  void _sortForms(List<CustomForm> forms) {
    switch (sortBy) {
      case 'newest':
        forms.sort((a, b) => b.created_at.compareTo(a.created_at));
        break;
      case 'oldest':
        forms.sort((a, b) => a.created_at.compareTo(b.created_at));
        break;
      case 'alphabetical':
        forms.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'most_responses':
        forms.sort((a, b) {
          final aResponses = formResponses[a.id]?.length ?? 0;
          final bResponses = formResponses[b.id]?.length ?? 0;
          return bResponses.compareTo(aResponses);
        });
        break;
    }
  }
}
