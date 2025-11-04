import 'package:flutter/material.dart';
import 'package:jala_form/features/forms/models/custom_form.dart';
import 'package:jala_form/features/forms/models/form_response.dart';
import 'package:jala_form/features/web/utils/date_formatter.dart';
import 'package:jala_form/features/web/screens/dashboard_screens/widgets/common/icon_button_widget.dart';
import 'package:jala_form/features/web/screens/dashboard_screens/widgets/common/metadata_pill.dart';

class FormCard extends StatelessWidget {
  final CustomForm form;
  final List<FormResponse> responses;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSubmit;
  final VoidCallback onViewResponses;

  const FormCard({
    super.key,
    required this.form,
    required this.responses,
    required this.onEdit,
    required this.onDelete,
    required this.onSubmit,
    required this.onViewResponses,
  });

  @override
  Widget build(BuildContext context) {
    final bool isChecklist = form.isChecklist;
    final Color accentColor = isChecklist ? Colors.orange : Colors.blue;
    final IconData formIcon =
        isChecklist ? Icons.checklist_rounded : Icons.article_rounded;

    final screenWidth = MediaQuery.of(context).size.width;
    final isXsScreen = screenWidth < 380; // Extra small screens
    final isSmScreen = screenWidth < 500; // Small screens

    // Adjust padding based on screen size
    final cardPadding = isXsScreen ? 8.0 : (isSmScreen ? 10.0 : 12.0);
    final iconSize = isXsScreen ? 16.0 : (isSmScreen ? 18.0 : 20.0);
    final actionIconSize = isXsScreen ? 16.0 : (isSmScreen ? 18.0 : 20.0);
    final iconContainerSize = isXsScreen ? 32.0 : (isSmScreen ? 36.0 : 40.0);
    final titleFontSize = isXsScreen ? 13.0 : (isSmScreen ? 14.0 : 15.0);
    final metadataFontSize = isXsScreen ? 10.0 : (isSmScreen ? 11.0 : 13.0);

    return Container(
      width: double.infinity, // Ensure full width
      constraints: const BoxConstraints(
        minHeight: 80, // Minimum height
        maxWidth: double.infinity,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, 1),
            blurRadius: 4,
          ),
        ],
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Form header with icon and title
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Form type icon
                    Container(
                      width: iconContainerSize,
                      height: iconContainerSize,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(
                          formIcon,
                          color: accentColor,
                          size: iconSize,
                        ),
                      ),
                    ),

                    SizedBox(width: isXsScreen ? 8 : 12),

                    // Form info (title, description, metadata)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title
                          Text(
                            form.title,
                            style: TextStyle(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF2D3748),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          if (form.description.isNotEmpty && !isXsScreen) ...[
                            const SizedBox(height: 3),
                            // Description (hide on very small screens)
                            Text(
                              form.description,
                              style: TextStyle(
                                fontSize: metadataFontSize,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],

                          const SizedBox(height: 6),

                          // Metadata pills in a row - use Wrap for flexibility
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              MetadataPill(
                                label:
                                    "${form.fields.length} ${form.fields.length == 1 ? 'field' : 'fields'}",
                                icon: Icons.list_alt_rounded,
                                fontSize: metadataFontSize,
                                iconSize: metadataFontSize + 1,
                              ),
                              MetadataPill(
                                label:
                                    "${responses.length} ${responses.length == 1 ? 'response' : 'responses'}",
                                icon: Icons.analytics_rounded,
                                fontSize: metadataFontSize,
                                iconSize: metadataFontSize + 1,
                                color: responses.isNotEmpty
                                    ? Colors.green.shade700
                                    : null,
                              ),
                              if (!isXsScreen)
                                MetadataPill(
                                  label: DateFormatter.formatDate(form.created_at),
                                  icon: Icons.calendar_today_rounded,
                                  fontSize: metadataFontSize,
                                  iconSize: metadataFontSize + 1,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Action buttons
                    if (!isXsScreen)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButtonWidget(
                            icon: Icons.edit_outlined,
                            color: Colors.blue,
                            tooltip: 'Edit',
                            onPressed: onEdit,
                            iconSize: actionIconSize,
                          ),
                          IconButtonWidget(
                            icon: Icons.send_outlined,
                            color: Colors.green,
                            tooltip: 'Submit',
                            onPressed: onSubmit,
                            iconSize: actionIconSize,
                          ),
                          IconButtonWidget(
                            icon: Icons.analytics_outlined,
                            color: Colors.orange,
                            tooltip: 'Responses',
                            onPressed: onViewResponses,
                            iconSize: actionIconSize,
                          ),
                          IconButtonWidget(
                            icon: Icons.delete_outline,
                            color: Colors.red,
                            tooltip: 'Delete',
                            onPressed: onDelete,
                            iconSize: actionIconSize,
                          ),
                        ],
                      ),
                  ],
                ),

                // Action buttons for small screens
                if (isXsScreen) ...[
                  const SizedBox(height: 8),
                  Divider(height: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 8),
                  // Action buttons in a separate row for small screens
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        IconButtonWidget(
                          icon: Icons.edit_outlined,
                          color: Colors.blue,
                          tooltip: 'Edit',
                          onPressed: onEdit,
                          iconSize: actionIconSize,
                        ),
                        IconButtonWidget(
                          icon: Icons.send_outlined,
                          color: Colors.green,
                          tooltip: 'Submit',
                          onPressed: onSubmit,
                          iconSize: actionIconSize,
                        ),
                        IconButtonWidget(
                          icon: Icons.analytics_outlined,
                          color: Colors.orange,
                          tooltip: 'Responses',
                          onPressed: onViewResponses,
                          iconSize: actionIconSize,
                        ),
                        IconButtonWidget(
                          icon: Icons.delete_outline,
                          color: Colors.red,
                          tooltip: 'Delete',
                          onPressed: onDelete,
                          iconSize: actionIconSize,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
