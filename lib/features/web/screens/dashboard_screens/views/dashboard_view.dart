import 'package:flutter/material.dart';
import 'package:jala_form/core/theme/app_theme.dart';
import 'package:jala_form/features/forms/models/custom_form.dart';
import 'package:jala_form/features/forms/models/form_response.dart';
import '../widgets/common/animated_stat_card.dart';
import '../widgets/common/filter_chip_widget.dart';
import '../widgets/forms/available_forms_list.dart';
import '../widgets/states/no_available_forms.dart';
import '../widgets/common/empty_state.dart';

/// Dashboard view - main dashboard with stats and available forms
class DashboardView extends StatelessWidget {
  final List<CustomForm> myForms;
  final List<CustomForm> availableForms;
  final List<CustomForm> availableRegularForms;
  final List<CustomForm> availableChecklistForms;
  final Map<String, List<FormResponse>> formResponses;
  final String selectedFormType;
  final String sortBy;
  final String searchQuery;
  final String username;
  final ValueChanged<String> onFormTypeChanged;
  final ValueChanged<String?> onSortByChanged;
  final VoidCallback onCreateForm;
  final Function(CustomForm) onOpenFormSubmission;
  final VoidCallback onViewAllForms;

  const DashboardView({
    super.key,
    required this.myForms,
    required this.availableForms,
    required this.availableRegularForms,
    required this.availableChecklistForms,
    required this.formResponses,
    required this.selectedFormType,
    required this.sortBy,
    required this.searchQuery,
    required this.username,
    required this.onFormTypeChanged,
    required this.onSortByChanged,
    required this.onCreateForm,
    required this.onOpenFormSubmission,
    required this.onViewAllForms,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    if (myForms.isEmpty && availableForms.isEmpty) {
      return EmptyState(
        title: 'Welcome to Jala Form',
        message: 'Create your first form or wait for forms to be shared with you',
        icon: Icons.assignment_outlined,
        actionLabel: 'Create Form',
        onActionPressed: onCreateForm,
      );
    }

    // Count forms by type
    final regularFormsCount = myForms.where((form) => !form.isChecklist).length;
    final checklistsCount = myForms.where((form) => form.isChecklist).length;

    // Count total responses
    int totalResponses = 0;
    formResponses.forEach((_, responses) {
      totalResponses += responses.length;
    });

    return SingleChildScrollView(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dashboard header with animated greeting
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(-30 * (1 - value), 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, $username!',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 20 : 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Welcome to your form dashboard',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 14 : 16,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isSmallScreen)
                        DropdownButton<String>(
                          value: sortBy,
                          icon: const Icon(Icons.sort),
                          underline: Container(),
                          items: const [
                            DropdownMenuItem(
                              value: 'newest',
                              child: Text('Newest First'),
                            ),
                            DropdownMenuItem(
                              value: 'oldest',
                              child: Text('Oldest First'),
                            ),
                            DropdownMenuItem(
                              value: 'alphabetical',
                              child: Text('Alphabetical'),
                            ),
                          ],
                          onChanged: onSortByChanged,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Stats cards with animations and responsive layout
          _buildStatsCards(
              screenWidth, regularFormsCount, checklistsCount, totalResponses),

          const SizedBox(height: 32),

          // Available Forms section
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Available Forms',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Forms that have been shared with you',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isSmallScreen && availableForms.isNotEmpty)
                        TextButton.icon(
                          onPressed: onViewAllForms,
                          icon: const Icon(Icons.arrow_forward, size: 16),
                          label: const Text('View All'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChipWidget(
                  label: 'All Forms',
                  isSelected: selectedFormType == 'all',
                  onSelected: () => onFormTypeChanged('all'),
                ),
                const SizedBox(width: 8),
                FilterChipWidget(
                  label: 'Regular Forms',
                  isSelected: selectedFormType == 'forms',
                  onSelected: () => onFormTypeChanged('forms'),
                ),
                const SizedBox(width: 8),
                FilterChipWidget(
                  label: 'Checklists',
                  isSelected: selectedFormType == 'checklists',
                  onSelected: () => onFormTypeChanged('checklists'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Available forms list
          availableForms.isEmpty
              ? const NoAvailableFormsMessage()
              : AvailableFormsList(
                  forms: _getFilteredForms(),
                  searchQuery: searchQuery,
                  onOpenFormSubmission: onOpenFormSubmission,
                ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(int screenWidth, int regularFormsCount,
      int checklistsCount, int totalResponses) {
    final useVerticalLayout = screenWidth < 800;

    if (useVerticalLayout) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: AnimatedStatCard(
                  icon: Icons.assignment_rounded,
                  iconColor: AppTheme.primaryColor,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  title: "Total Forms",
                  valueText: "${myForms.length}",
                  delay: 0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedStatCard(
                  icon: Icons.article_rounded,
                  iconColor: Colors.blue,
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  title: "Regular Forms",
                  valueText: "$regularFormsCount",
                  delay: 100,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AnimatedStatCard(
                  icon: Icons.checklist_rounded,
                  iconColor: Colors.orange,
                  backgroundColor: Colors.orange.withOpacity(0.1),
                  title: "Checklists",
                  valueText: "$checklistsCount",
                  delay: 200,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedStatCard(
                  icon: Icons.analytics_rounded,
                  iconColor: Colors.green,
                  backgroundColor: Colors.green.withOpacity(0.1),
                  title: "Total Responses",
                  valueText: "$totalResponses",
                  delay: 300,
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: AnimatedStatCard(
              icon: Icons.assignment_rounded,
              iconColor: AppTheme.primaryColor,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              title: "Total Forms",
              valueText: "${myForms.length}",
              delay: 0,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: AnimatedStatCard(
              icon: Icons.article_rounded,
              iconColor: Colors.blue,
              backgroundColor: Colors.blue.withOpacity(0.1),
              title: "Regular Forms",
              valueText: "$regularFormsCount",
              delay: 100,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: AnimatedStatCard(
              icon: Icons.checklist_rounded,
              iconColor: Colors.orange,
              backgroundColor: Colors.orange.withOpacity(0.1),
              title: "Checklists",
              valueText: "$checklistsCount",
              delay: 200,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: AnimatedStatCard(
              icon: Icons.analytics_rounded,
              iconColor: Colors.green,
              backgroundColor: Colors.green.withOpacity(0.1),
              title: "Total Responses",
              valueText: "$totalResponses",
              delay: 300,
            ),
          ),
        ],
      );
    }
  }

  List<CustomForm> _getFilteredForms() {
    List<CustomForm> formsToShow = [];
    switch (selectedFormType) {
      case 'forms':
        formsToShow = availableRegularForms;
        break;
      case 'checklists':
        formsToShow = availableChecklistForms;
        break;
      case 'all':
      default:
        formsToShow = availableForms;
        break;
    }

    // Filter forms based on search query
    if (searchQuery.isNotEmpty) {
      formsToShow = formsToShow
          .where((form) => form.title.toLowerCase().contains(searchQuery))
          .toList();
    }

    return formsToShow;
  }
}
