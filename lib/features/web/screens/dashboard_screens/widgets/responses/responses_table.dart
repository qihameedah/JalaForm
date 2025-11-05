import 'package:flutter/material.dart';
import 'package:jala_form/core/theme/app_theme.dart';
import 'package:jala_form/features/forms/models/custom_form.dart';
import 'package:jala_form/features/forms/models/form_response.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

/// Responsive responses table widget
/// Displays form responses in a table format with animations
class ResponsesTable extends StatelessWidget {
  final CustomForm form;
  final List<FormResponse> responses;
  final Function(CustomForm, FormResponse) onShowDetails;
  final Function(CustomForm, FormResponse) onExportToPdf;
  final String Function(DateTime) formatDateTime;
  final Widget Function(dynamic, dynamic) buildFieldCell;

  const ResponsesTable({
    super.key,
    required this.form,
    required this.responses,
    required this.onShowDetails,
    required this.onExportToPdf,
    required this.formatDateTime,
    required this.buildFieldCell,
  });

  @override
  Widget build(BuildContext context) {
    // Get form fields for display
    final fields = form.fields;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            offset: const Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Table header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Checkbox column
                  SizedBox(
                    width: 40,
                    child: Theme(
                      data: ThemeData(
                        checkboxTheme: CheckboxThemeData(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      child: Checkbox(
                        value: false,
                        onChanged: (value) {
                          // Select all functionality
                        },
                        activeColor: AppTheme.primaryColor,
                      ),
                    ),
                  ),

                  // # Column
                  SizedBox(
                    width: 40,
                    child: Text(
                      "#",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),

                  // Date Column
                  LayoutBuilder(builder: (context, constraints) {
                    return SizedBox(
                      width: 120,
                      child: Text(
                        "Date",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    );
                  }),

                  // Dynamic field columns - adjust based on screen size
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Determine how many fields we can show based on width
                        final availableWidth = constraints.maxWidth;
                        int fieldsToShow = 1; // Show at least one field

                        if (availableWidth > 300) fieldsToShow = 2;
                        if (availableWidth > 600) fieldsToShow = fields.length;

                        return Row(
                          children: fields.take(fieldsToShow).map((field) {
                            return Expanded(
                              child: Text(
                                field.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.grey.shade800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),

                  // Actions Column
                  SizedBox(
                    width: 80,
                    child: Text(
                      "Actions",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey.shade800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            // Table body
            Expanded(
              child: responses.isEmpty
                  ? const Center(child: Text('No responses yet'))
                  : ListView.builder(
                      itemCount: responses.length,
                      itemBuilder: (context, index) {
                        final response = responses[index];
                        final isEven = index % 2 == 0;

                        // Add animation to each row with key for proper state management
                        return AnimationConfiguration.staggeredList(
                          key: ValueKey(response.id),
                          position: index,
                          duration: const Duration(milliseconds: 375),
                          child: SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isEven
                                      ? Colors.white
                                      : Colors.grey.shade50,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey.shade200,
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => onShowDetails(form, response),
                                    highlightColor:
                                        Colors.blue.withOpacity(0.05),
                                    splashColor: Colors.blue.withOpacity(0.05),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      child: Row(
                                        children: [
                                          // Checkbox column
                                          SizedBox(
                                            width: 40,
                                            child: Theme(
                                              data: ThemeData(
                                                checkboxTheme:
                                                    CheckboxThemeData(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                ),
                                              ),
                                              child: Checkbox(
                                                value:
                                                    false, // Row selection state
                                                onChanged: (value) {
                                                  // Row selection functionality
                                                },
                                                activeColor:
                                                    AppTheme.primaryColor,
                                              ),
                                            ),
                                          ),

                                          // # Column
                                          SizedBox(
                                            width: 40,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                "${index + 1}",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: Colors.blue.shade800,
                                                ),
                                              ),
                                            ),
                                          ),

                                          // Date Column
                                          SizedBox(
                                            width: 120,
                                            child: Text(
                                              formatDateTime(
                                                  response.submitted_at),
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontFamily: 'Roboto Mono',
                                                color: Colors.grey.shade700,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),

                                          // Dynamic field columns
                                          Expanded(
                                            child: LayoutBuilder(
                                              builder: (context, constraints) {
                                                // Determine how many fields we can show based on width
                                                final availableWidth =
                                                    constraints.maxWidth;
                                                int fieldsToShow =
                                                    1; // Show at least one field

                                                if (availableWidth > 300) {
                                                  fieldsToShow = 2;
                                                }
                                                if (availableWidth > 600) {
                                                  fieldsToShow = fields.length;
                                                }

                                                return Row(
                                                  children: fields
                                                      .take(fieldsToShow)
                                                      .map((field) {
                                                    final value = response
                                                        .responses[field.id];
                                                    return Expanded(
                                                      child: buildFieldCell(
                                                          field, value),
                                                    );
                                                  }).toList(),
                                                );
                                              },
                                            ),
                                          ),

                                          // Actions Column with eye-catching hover effects
                                          SizedBox(
                                            width: 80,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                _AnimatedActionButton(
                                                  icon:
                                                      Icons.visibility_outlined,
                                                  color: Colors.blue,
                                                  tooltip: 'View Details',
                                                  onPressed: () =>
                                                      onShowDetails(
                                                          form, response),
                                                ),
                                                const SizedBox(width: 8),
                                                _AnimatedActionButton(
                                                  icon: Icons.download_outlined,
                                                  color: Colors.red,
                                                  tooltip: 'Download PDF',
                                                  onPressed: () =>
                                                      onExportToPdf(
                                                          form, response),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated action button for tables
class _AnimatedActionButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const _AnimatedActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  State<_AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<_AnimatedActionButton> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isHovered
              ? widget.color.withOpacity(0.15)
              : widget.color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Tooltip(
          message: widget.tooltip,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(6),
              child: Icon(
                widget.icon,
                size: 18,
                color: widget.color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
