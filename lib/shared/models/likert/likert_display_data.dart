import 'likert_option.dart';

/// Model class for Likert scale display data
///
/// Contains all the information needed to display a Likert scale
/// including questions, available options, and user responses.
class LikertDisplayData {
  final List<String> questions;
  final List<LikertOption> options;
  final Map<String, String> responses;

  const LikertDisplayData({
    required this.questions,
    required this.options,
    required this.responses,
  });

  /// Creates a LikertDisplayData from a JSON map
  factory LikertDisplayData.fromJson(Map<String, dynamic> json) {
    return LikertDisplayData(
      questions: List<String>.from(json['questions'] as List),
      options: (json['options'] as List)
          .map((option) => LikertOption.fromJson(option as Map<String, dynamic>))
          .toList(),
      responses: Map<String, String>.from(json['responses'] as Map),
    );
  }

  /// Converts this LikertDisplayData to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'questions': questions,
      'options': options.map((option) => option.toJson()).toList(),
      'responses': responses,
    };
  }

  @override
  String toString() => 'LikertDisplayData(questions: ${questions.length}, '
      'options: ${options.length}, responses: ${responses.length})';
}
