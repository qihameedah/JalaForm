import 'package:flutter/material.dart';
import 'package:jala_form/features/forms/models/custom_form.dart';
import 'package:jala_form/features/forms/models/form_response.dart';
import '../widgets/forms/forms_header.dart';
import '../widgets/forms/forms_list.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/no_items_found.dart';

/// Forms view - displays and manages all user forms
class FormsView extends StatelessWidget {
  final List<CustomForm> myForms;
  final Map<String, List<FormResponse>> formResponses;
  final String searchQuery;
  final String sortBy;
  final bool isLoading;
  final TextEditingController searchController;
  final ValueChanged<String?> onSortChanged;
  final VoidCallback onCreateForm;
  final Function(CustomForm) onEditForm;
  final Function(CustomForm) onDeleteForm;
  final Function(CustomForm) onOpenFormSubmission;
  final Function(CustomForm) onViewResponses;

  const FormsView({
    super.key,
    required this.myForms,
    required this.formResponses,
    required this.searchQuery,
    required this.sortBy,
    required this.isLoading,
    required this.searchController,
    required this.onSortChanged,
    required this.onCreateForm,
    required this.onEditForm,
    required this.onDeleteForm,
    required this.onOpenFormSubmission,
    required this.onViewResponses,
  });

  @override
  Widget build(BuildContext context) {
    if (myForms.isEmpty && !isLoading) {
      return EmptyState(
        title: 'No Forms Yet',
        message: 'Create your first form to start collecting responses',
        icon: Icons.assignment_outlined,
        actionLabel: 'Create Form',
        onActionPressed: onCreateForm,
      );
    }

    // Filter forms based on search query
    List<CustomForm> filteredForms = List<CustomForm>.from(myForms);
    if (searchQuery.isNotEmpty) {
      filteredForms = myForms.where((form) {
        final title = form.title.toLowerCase();
        final description = form.description.toLowerCase();
        return title.contains(searchQuery) || description.contains(searchQuery);
      }).toList();
    }

    // Sort forms according to selected sort option
    _sortFormsList(filteredForms);

    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding =
        screenWidth < 400 ? 12.0 : (screenWidth < 600 ? 16.0 : 24.0);
    final verticalPadding =
        screenWidth < 400 ? 10.0 : (screenWidth < 600 ? 12.0 : 16.0);

    return Container(
      color: Colors.grey.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and actions
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding, vertical: verticalPadding),
            child: FormsHeader(
              formsCount: filteredForms.length,
              sortBy: sortBy,
              onSortChanged: onSortChanged,
              onCreateForm: onCreateForm,
            ),
          ),

          // Search field
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Container(
              margin: EdgeInsets.symmetric(vertical: screenWidth < 400 ? 12 : 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Search forms...',
                  prefixIcon: Icon(Icons.search,
                      color: Colors.grey.shade500,
                      size: screenWidth < 400 ? 16 : 18),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: screenWidth < 400 ? 10 : 12,
                    horizontal: screenWidth < 400 ? 8 : 12,
                  ),
                  hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: screenWidth < 400 ? 13 : 14),
                ),
                style: TextStyle(fontSize: screenWidth < 400 ? 13 : 14),
              ),
            ),
          ),

          // Forms list
          Expanded(
            child: filteredForms.isEmpty
                ? NoItemsFound(searchQuery: searchQuery)
                : Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: FormsList(
                      forms: filteredForms,
                      formResponses: formResponses,
                      onEditForm: onEditForm,
                      onDeleteForm: onDeleteForm,
                      onOpenFormSubmission: onOpenFormSubmission,
                      onViewResponses: onViewResponses,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _sortFormsList(List<CustomForm> forms) {
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
    }
  }
}
