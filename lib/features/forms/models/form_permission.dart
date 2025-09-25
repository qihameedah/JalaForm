class FormPermission {
  String id;
  String form_id;
  String? user_id;
  String? group_id;
  DateTime created_at;

  // Optional user/group details for display
  String? user_email;
  String? group_name;

  FormPermission({
    required this.id,
    required this.form_id,
    this.user_id,
    this.group_id,
    required this.created_at,
    this.user_email,
    this.group_name,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'form_id': form_id,
      'user_id': user_id,
      'group_id': group_id,
      'created_at': created_at.toIso8601String(),
    };
  }

  factory FormPermission.fromJson(Map<String, dynamic> json) {
    return FormPermission(
      id: json['id'],
      form_id: json['form_id'],
      user_id: json['user_id'],
      group_id: json['group_id'],
      created_at: DateTime.parse(json['created_at']),
      user_email: json['user_email'],
      group_name: json['group_name'],
    );
  }
}
