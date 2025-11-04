import 'package:flutter/material.dart';
import 'package:jala_form/core/theme/app_theme.dart';

class FormsHeader extends StatelessWidget {
  final int formsCount;
  final String sortBy;
  final ValueChanged<String?> onSortChanged;
  final VoidCallback onCreateForm;

  const FormsHeader({
    super.key,
    required this.formsCount,
    required this.sortBy,
    required this.onSortChanged,
    required this.onCreateForm,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 480;
    final isTablet = screenWidth >= 480 && screenWidth < 800;

    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Forms',
                      style: TextStyle(
                        fontSize: isMobile ? 18 : (isTablet ? 20 : 24),
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage all your forms and checklists',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : (isTablet ? 13 : 14),
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isMobile) ...[
                // Sort dropdown
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 6 : 8, vertical: 0),
                  margin: EdgeInsets.only(right: isTablet ? 8 : 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: sortBy,
                      icon: Icon(Icons.keyboard_arrow_down,
                          color: Colors.grey.shade700,
                          size: isTablet ? 16 : 18),
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: isTablet ? 12 : 13,
                        fontWeight: FontWeight.w500,
                      ),
                      isDense: isTablet,
                      items: const [
                        DropdownMenuItem(
                            value: 'newest', child: Text('Newest First')),
                        DropdownMenuItem(
                            value: 'oldest', child: Text('Oldest First')),
                        DropdownMenuItem(
                            value: 'alphabetical', child: Text('Alphabetical')),
                      ],
                      onChanged: onSortChanged,
                    ),
                  ),
                ),

                // Create form button
                ElevatedButton.icon(
                  icon: Icon(Icons.add,
                      color: Colors.white, size: isTablet ? 14 : 16),
                  label: Text(
                    isTablet ? 'Create' : 'Create Form',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: isTablet ? 12 : 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 10 : 16,
                      vertical: isTablet ? 8 : 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 0,
                  ),
                  onPressed: onCreateForm,
                ),
              ],
            ],
          ),
          if (isMobile) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                // Sort dropdown for mobile
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: sortBy,
                        icon: Icon(Icons.keyboard_arrow_down,
                            color: Colors.grey.shade700, size: 16),
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        isExpanded: true,
                        isDense: true,
                        items: const [
                          DropdownMenuItem(
                              value: 'newest', child: Text('Newest First')),
                          DropdownMenuItem(
                              value: 'oldest', child: Text('Oldest First')),
                          DropdownMenuItem(
                              value: 'alphabetical',
                              child: Text('Alphabetical')),
                        ],
                        onChanged: onSortChanged,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Create form button for mobile
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, color: Colors.white, size: 14),
                  label: const Text(
                    'Create',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 0,
                  ),
                  onPressed: onCreateForm,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
