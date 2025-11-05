/// Model class for Likert scale options
///
/// Represents a single option in a Likert scale with a display label
/// and an internal value used for data storage.
class LikertOption {
  final String label;
  final String value;

  const LikertOption({
    required this.label,
    required this.value,
  });

  /// Creates a LikertOption from a JSON map
  factory LikertOption.fromJson(Map<String, dynamic> json) {
    return LikertOption(
      label: json['label'] as String,
      value: json['value'] as String,
    );
  }

  /// Converts this LikertOption to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'value': value,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LikertOption &&
          runtimeType == other.runtimeType &&
          label == other.label &&
          value == other.value;

  @override
  int get hashCode => label.hashCode ^ value.hashCode;

  @override
  String toString() => 'LikertOption(label: $label, value: $value)';
}
