/// Model class for Likert scale options
class LikertOption {
  final String label;
  final String value;

  LikertOption({required this.label, required this.value});
}

/// Model class for Likert display data
class LikertDisplayData {
  final List<String> questions;
  final List<LikertOption> options;
  final Map<String, String> responses;

  LikertDisplayData({
    required this.questions,
    required this.options,
    required this.responses,
  });
}
