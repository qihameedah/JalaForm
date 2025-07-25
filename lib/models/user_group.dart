class UserGroup {
  String id;
  String name;
  String description;
  String created_by;
  DateTime created_at;
  List<String>? members; // Optional list of member IDs
  int? memberCount; // New property for displaying member count

  UserGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.created_by,
    required this.created_at,
    this.members,
    this.memberCount, // Add this as an optional parameter
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_by': created_by,
      'created_at': created_at.toIso8601String(),
      // Don't include memberCount in the JSON as it's calculated dynamically
      // Only include members if it's not null
      if (members != null) 'members': members,
    };
  }

  factory UserGroup.fromJson(Map<String, dynamic> json) {
    return UserGroup(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      created_by: json['created_by'],
      created_at: DateTime.parse(json['created_at']),
      // Parse members list if present
      members:
          json['members'] != null ? List<String>.from(json['members']) : null,
      // Don't try to parse memberCount from JSON as it's calculated at runtime
    );
  }

  // Helper method to set member count
  void setMemberCount(int count) {
    memberCount = count;
  }

  // Helper method to get member count (either from cached value or members list length)
  int getMemberCount() {
    if (memberCount != null) {
      return memberCount!;
    } else if (members != null) {
      return members!.length;
    } else {
      return 0;
    }
  }

  // Clone method to create a copy with optional property updates
  UserGroup copyWith({
    String? id,
    String? name,
    String? description,
    String? created_by,
    DateTime? created_at,
    List<String>? members,
    int? memberCount,
  }) {
    return UserGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      created_by: created_by ?? this.created_by,
      created_at: created_at ?? this.created_at,
      members: members ?? this.members,
      memberCount: memberCount ?? this.memberCount,
    );
  }
}
