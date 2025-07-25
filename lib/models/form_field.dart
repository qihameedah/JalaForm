enum FieldType {
  text,
  number,
  email,
  multiline,
  textarea,
  dropdown,
  checkbox,
  radio,
  date,
  image,
  time,
  likert, // Add this new type
}

class FormFieldModel {
  String id;
  String label;
  FieldType type;
  bool isRequired;
  List<String>? options; // For dropdown, checkbox, radio
  String? placeholder;
  String? validation;

  // New properties for Likert scale
  int? likertScale; // Scale size (e.g., 5 for 1-5 scale)
  String? likertStartLabel; // e.g., "Strongly Disagree"
  String? likertEndLabel; // e.g., "Strongly Agree"
  String? likertMiddleLabel; // e.g., "Neutral" (optional)
  List<String>? likertQuestions; // Multiple questions for the same scale

  FormFieldModel({
    required this.id,
    required this.label,
    required this.type,
    this.isRequired = false,
    this.options,
    this.placeholder,
    this.validation,
    this.likertScale,
    this.likertStartLabel,
    this.likertEndLabel,
    this.likertMiddleLabel,
    this.likertQuestions,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'type': type.toString().split('.').last,
      'isRequired': isRequired,
      'options': options,
      'placeholder': placeholder,
      'validation': validation,
      'likertScale': likertScale,
      'likertStartLabel': likertStartLabel,
      'likertEndLabel': likertEndLabel,
      'likertMiddleLabel': likertMiddleLabel,
      'likertQuestions': likertQuestions,
    };
  }

  factory FormFieldModel.fromJson(Map<String, dynamic> json) {
    return FormFieldModel(
      id: json['id'],
      label: json['label'],
      type: FieldType.values.firstWhere(
          (e) => e.toString() == 'FieldType.${json['type']}',
          orElse: () => FieldType.text),
      isRequired: json['isRequired'] ?? false,
      options:
          json['options'] != null ? List<String>.from(json['options']) : null,
      placeholder: json['placeholder'],
      validation: json['validation'],
      likertScale: json['likertScale'],
      likertStartLabel: json['likertStartLabel'],
      likertEndLabel: json['likertEndLabel'],
      likertMiddleLabel: json['likertMiddleLabel'],
      likertQuestions: json['likertQuestions'] != null
          ? List<String>.from(json['likertQuestions'])
          : null,
    );
  }
}
