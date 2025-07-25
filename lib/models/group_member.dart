class GroupMember {
  String group_id;
  String user_id;
  String added_by;
  DateTime added_at;

  // Optional user details
  String? user_email;
  String? user_name;

  GroupMember({
    required this.group_id,
    required this.user_id,
    required this.added_by,
    required this.added_at,
    this.user_email,
    this.user_name,
  });

  Map<String, dynamic> toJson() {
    return {
      'group_id': group_id,
      'user_id': user_id,
      'added_by': added_by,
      'added_at': added_at.toIso8601String(),
    };
  }

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      group_id: json['group_id'],
      user_id: json['user_id'],
      added_by: json['added_by'],
      added_at: DateTime.parse(json['added_at']),
      user_email: json['user_email'],
      user_name: json['user_name'],
    );
  }
}
