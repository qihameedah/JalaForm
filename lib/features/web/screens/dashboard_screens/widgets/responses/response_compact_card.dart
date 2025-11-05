import 'package:flutter/material.dart';
import 'package:jala_form/features/forms/models/custom_form.dart';
import 'package:jala_form/features/forms/models/form_response.dart';

class ResponseCompactCard extends StatelessWidget {
  final CustomForm form;
  final List<FormResponse> responses;
  final VoidCallback onTap;

  const ResponseCompactCard({
    super.key,
    required this.form,
    required this.responses,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final responseCount = responses.length;
    final isChecklist = form.isChecklist;
    final accentColor = isChecklist ? Colors.orange : Colors.blue;

    return Container(
      height: 48, // Extremely reduced height to fit many more cards
      margin: const EdgeInsets.only(bottom: 4), // Minimum margin
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(color: accentColor.withOpacity(0.2), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4), // Minimal padding
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon indicator (tiny)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Icon(
                      isChecklist
                          ? Icons.checklist_rounded
                          : Icons.article_rounded,
                      color: accentColor,
                      size: 14,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Title
                Expanded(
                  child: Text(
                    form.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Simple metadata
                Container(
                  margin: const EdgeInsets.only(left: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isChecklist
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isChecklist ? "Checklist" : "Form",
                    style: TextStyle(
                      fontSize: 10,
                      color: accentColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Response count
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: responseCount > 0
                        ? Colors.green.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.analytics_rounded,
                        size: 8,
                        color: responseCount > 0
                            ? Colors.green
                            : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        "$responseCount",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: responseCount > 0
                              ? Colors.green
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 4),

                // Tiny arrow
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 10,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
