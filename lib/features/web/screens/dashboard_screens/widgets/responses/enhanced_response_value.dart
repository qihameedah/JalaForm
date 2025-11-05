import 'package:flutter/material.dart';
import 'package:jala_form/features/forms/models/form_field.dart';
import 'likert_response_display.dart';

/// Enhanced response value display widget
/// Displays different field types (text, image, checkbox, likert) with proper formatting
class EnhancedResponseValue extends StatelessWidget {
  final FormFieldModel field;
  final dynamic value;
  final LikertDisplayData Function(FormFieldModel, Map<dynamic, dynamic>)
      parseLikertData;

  const EnhancedResponseValue({
    super.key,
    required this.field,
    required this.value,
    required this.parseLikertData,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 500;

    if (value == null) {
      return Container(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          'No response',
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.grey.shade500,
            fontSize: isSmallScreen ? 13 : 14,
          ),
        ),
      );
    }

    if (field.type == FieldType.image && value.toString().isNotEmpty) {
      return LayoutBuilder(builder: (context, constraints) {
        final double maxWidth = constraints.maxWidth;
        final double imageSize =
            maxWidth < 280 ? maxWidth : (isSmallScreen ? 240 : 280);

        return Container(
          width: imageSize,
          height: imageSize,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              value.toString(),
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey.shade100,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image_rounded,
                            size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Image not available',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      });
    }

    if (field.type == FieldType.checkbox && value is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: value.map<Widget>((item) {
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            builder: (context, animValue, child) {
              return Opacity(
                opacity: animValue,
                child: Container(
                  margin: EdgeInsets.only(bottom: isSmallScreen ? 6 : 8),
                  padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12 : 16,
                      vertical: isSmallScreen ? 10 : 12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: isSmallScreen ? 16 : 18,
                        color: Colors.green.shade600,
                      ),
                      SizedBox(width: isSmallScreen ? 8 : 12),
                      Flexible(
                        child: Text(
                          item.toString(),
                          style: TextStyle(
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w500,
                            fontSize: isSmallScreen ? 13 : 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }).toList(),
      );
    }

    // Add Likert handling
    if (field.type == FieldType.likert && value is Map) {
      return LikertResponseDisplay(
        field: field,
        value: value,
        isSmallScreen: isSmallScreen,
        parseLikertData: parseLikertData,
      );
    }

    // For text, number, email, etc.
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        value.toString(),
        style: TextStyle(
          fontSize: isSmallScreen ? 14 : 16,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }
}

/// Build field cell for table display
class FieldCell extends StatelessWidget {
  final FormFieldModel field;
  final dynamic value;
  final String Function(FormFieldModel, dynamic) getDisplayValue;
  final LikertDisplayData Function(FormFieldModel, Map<dynamic, dynamic>)
      parseLikertData;

  const FieldCell({
    super.key,
    required this.field,
    required this.value,
    required this.getDisplayValue,
    required this.parseLikertData,
  });

  @override
  Widget build(BuildContext context) {
    if (field.type == FieldType.likert) {
      return LikertTableCell(
        field: field,
        value: value,
        parseLikertData: parseLikertData,
      );
    }

    return Text(
      getDisplayValue(field, value),
      style: TextStyle(
        fontSize: 14,
        color: Colors.grey.shade800,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 2,
    );
  }
}
