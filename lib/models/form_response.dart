class FormResponse {
  String id;
  String form_id;
  Map<String, dynamic> responses; // Field ID -> Response value
  String? respondent_id;
  DateTime submitted_at;

  FormResponse({
    required this.id,
    required this.form_id,
    required this.responses,
    this.respondent_id,
    required this.submitted_at,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'form_id': form_id,
      'responses': responses,
      'respondent_id': respondent_id,
      'submitted_at': submitted_at.toIso8601String(),
    };
  }

  factory FormResponse.fromJson(Map<String, dynamic> json) {
    return FormResponse(
      id: json['id'],
      form_id: json['form_id'],
      responses: json['responses'],
      respondent_id: json['respondent_id'],
      submitted_at: DateTime.parse(json['submitted_at']),
    );
  }
}
