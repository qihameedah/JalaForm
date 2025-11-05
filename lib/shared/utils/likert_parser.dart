import 'package:jala_form/features/forms/models/form_field.dart';
import '../models/likert/likert_option.dart';
import '../models/likert/likert_display_data.dart';

/// Utility class for parsing Likert scale data
///
/// Provides methods to parse Likert options and display data from FormFieldModel
/// to ensure consistent parsing logic across the application.
class LikertParser {
  LikertParser._(); // Private constructor to prevent instantiation

  /// Parses Likert options from a FormFieldModel
  ///
  /// Supports two formats:
  /// 1. Custom options in "label|value" format (e.g., "Strongly Agree|5")
  /// 2. Numeric scale generation based on likertScale property
  ///
  /// Returns a list of LikertOption objects
  static List<LikertOption> parseLikertOptions(FormFieldModel field) {
    // If field.options contains likert scale options in format "label|value"
    if (field.options != null && field.options!.isNotEmpty) {
      return field.options!.map((option) {
        if (option.contains('|')) {
          final parts = option.split('|');
          return LikertOption(
            label: parts[0].trim(),
            value: parts.length > 1 ? parts[1].trim() : parts[0].trim(),
          );
        } else {
          return LikertOption(label: option, value: option);
        }
      }).toList();
    }

    // Fallback to default scale if no custom options
    final scale = field.likertScale ?? 5;
    final startLabel = field.likertStartLabel ?? 'Strongly Disagree';
    final endLabel = field.likertEndLabel ?? 'Strongly Agree';
    final middleLabel = field.likertMiddleLabel;

    List<LikertOption> options = [];

    for (int i = 1; i <= scale; i++) {
      String label;
      if (i == 1) {
        label = startLabel;
      } else if (i == scale) {
        label = endLabel;
      } else if (i == ((scale + 1) ~/ 2) &&
          middleLabel != null &&
          middleLabel.isNotEmpty) {
        label = middleLabel;
      } else {
        label = i.toString();
      }
      options.add(LikertOption(label: label, value: 'scale_$i'));
    }

    return options;
  }

  /// Parses complete Likert display data from a FormFieldModel and response map
  ///
  /// Returns a LikertDisplayData object containing questions, options, and responses
  static LikertDisplayData parseLikertDisplayData(
    FormFieldModel field,
    Map<dynamic, dynamic> responseMap,
  ) {
    // Convert response map to proper types
    final Map<String, String> responses = {};
    responseMap.forEach((key, value) {
      responses[key.toString()] = value.toString();
    });

    // Get questions
    final questions = field.likertQuestions ?? [];

    // Parse options
    final options = parseLikertOptions(field);

    return LikertDisplayData(
      questions: questions,
      options: options,
      responses: responses,
    );
  }

  /// Gets the label for a given value from a list of Likert options
  ///
  /// Returns the label if found, otherwise returns the value itself
  static String getLabelForValue(List<LikertOption> options, String value) {
    try {
      return options.firstWhere((opt) => opt.value == value).label;
    } catch (e) {
      return value;
    }
  }

  /// Validates that all required questions have responses
  ///
  /// Returns true if all questions have responses, false otherwise
  static bool hasAllRequiredResponses(
    List<String> questions,
    Map<String, String> responses,
  ) {
    return questions.every((question) => responses.containsKey(question));
  }
}
