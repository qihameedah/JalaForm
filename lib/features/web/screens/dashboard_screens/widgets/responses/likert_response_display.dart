import 'package:flutter/material.dart';
import 'package:jala_form/features/forms/models/form_field.dart';
import 'package:jala_form/features/web/models/likert_models.dart';

/// Likert scale response display widget
/// Shows Likert responses in a formatted table-like view
class LikertResponseDisplay extends StatelessWidget {
  final FormFieldModel field;
  final Map<dynamic, dynamic> value;
  final bool isSmallScreen;
  final LikertDisplayData Function(FormFieldModel, Map<dynamic, dynamic>)
      parseLikertData;

  const LikertResponseDisplay({
    super.key,
    required this.field,
    required this.value,
    required this.isSmallScreen,
    required this.parseLikertData,
  });

  @override
  Widget build(BuildContext context) {
    final likertData = parseLikertData(field, value);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF9C27B0).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C27B0).withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF9C27B0).withOpacity(0.08),
                  const Color(0xFF9C27B0).withOpacity(0.12),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.poll_outlined,
                    color: Colors.white,
                    size: isSmallScreen ? 18 : 20,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12 : 16),
                Expanded(
                  child: Text(
                    'Likert Scale Response',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF9C27B0),
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 8 : 10,
                    vertical: isSmallScreen ? 4 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${likertData.responses.length}/${likertData.questions.length}',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF9C27B0),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Questions and responses
          Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...likertData.questions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final question = entry.value;
                  final questionKey = index.toString();
                  final responseValue = likertData.responses[questionKey];

                  // Find the option label for this response
                  String responseLabel = 'Not answered';
                  if (responseValue != null) {
                    final option = likertData.options.firstWhere(
                      (opt) => opt.value == responseValue,
                      orElse: () => LikertOption(
                          label: responseValue, value: responseValue),
                    );
                    responseLabel = option.label;
                  }

                  final isAnswered = responseValue != null;

                  return Container(
                    margin: EdgeInsets.only(
                      bottom: index < likertData.questions.length - 1
                          ? (isSmallScreen ? 16 : 20)
                          : 0,
                    ),
                    padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
                    decoration: BoxDecoration(
                      color: isAnswered
                          ? const Color(0xFF9C27B0).withOpacity(0.05)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isAnswered
                            ? const Color(0xFF9C27B0).withOpacity(0.2)
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Question
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: isSmallScreen ? 24 : 28,
                              height: isSmallScreen ? 24 : 28,
                              decoration: BoxDecoration(
                                color: isAnswered
                                    ? const Color(0xFF9C27B0)
                                    : Colors.grey.shade400,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isSmallScreen ? 12 : 14,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: isSmallScreen ? 12 : 16),
                            Expanded(
                              child: Text(
                                question,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 14 : 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade800,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: isSmallScreen ? 12 : 16),

                        // Response
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                          decoration: BoxDecoration(
                            color: isAnswered
                                ? Colors.white
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isAnswered
                                  ? const Color(0xFF9C27B0).withOpacity(0.3)
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isAnswered
                                    ? Icons.check_circle
                                    : Icons.help_outline,
                                color: isAnswered
                                    ? const Color(0xFF9C27B0)
                                    : Colors.grey.shade500,
                                size: isSmallScreen ? 18 : 20,
                              ),
                              SizedBox(width: isSmallScreen ? 10 : 12),
                              Expanded(
                                child: Text(
                                  responseLabel,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 16,
                                    fontWeight: isAnswered
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: isAnswered
                                        ? const Color(0xFF9C27B0)
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          // Summary footer
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            decoration: BoxDecoration(
              color: const Color(0xFF9C27B0).withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  size: isSmallScreen ? 16 : 18,
                  color: const Color(0xFF9C27B0),
                ),
                SizedBox(width: isSmallScreen ? 8 : 10),
                Text(
                  'Completion: ${likertData.responses.length}/${likertData.questions.length} questions answered',
                  style: TextStyle(
                    color: const Color(0xFF9C27B0),
                    fontSize: isSmallScreen ? 12 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Likert table cell widget for compact display in tables
class LikertTableCell extends StatelessWidget {
  final FormFieldModel field;
  final dynamic value;
  final LikertDisplayData Function(FormFieldModel, Map<dynamic, dynamic>)
      parseLikertData;

  const LikertTableCell({
    super.key,
    required this.field,
    required this.value,
    required this.parseLikertData,
  });

  @override
  Widget build(BuildContext context) {
    if (value == null || value is! Map) {
      return Text(
        'No response',
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade500,
          fontStyle: FontStyle.italic,
        ),
        overflow: TextOverflow.ellipsis,
      );
    }

    final likertData = parseLikertData(field, value);
    final answeredCount = likertData.responses.length;
    final totalCount = likertData.questions.length;

    // Show a summary in table view
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF9C27B0).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Likert ($answeredCount/$totalCount)',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9C27B0),
            ),
          ),
        ),
        if (answeredCount > 0) ...[
          const SizedBox(height: 6),
          Text(
            '${((answeredCount / totalCount) * 100).round()}% completed',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }
}
