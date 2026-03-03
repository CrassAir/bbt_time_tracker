import 'dart:convert';

class Project {
  String id;
  String name;
  String workingDirectory;
  String? sessionId;
  DateTime createdAt;
  DateTime lastUsedAt;

  Project({
    required this.id,
    required this.name,
    required this.workingDirectory,
    this.sessionId,
    DateTime? createdAt,
    DateTime? lastUsedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastUsedAt = lastUsedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'workingDirectory': workingDirectory,
        'sessionId': sessionId,
        'createdAt': createdAt.toIso8601String(),
        'lastUsedAt': lastUsedAt.toIso8601String(),
      };

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String,
        name: json['name'] as String,
        workingDirectory: json['workingDirectory'] as String,
        sessionId: json['sessionId'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] ?? ''),
        lastUsedAt: DateTime.tryParse(json['lastUsedAt'] ?? ''),
      );

  static String encode(List<Project> projects) =>
      jsonEncode(projects.map((p) => p.toJson()).toList());

  static List<Project> decode(String source) {
    final data = jsonDecode(source);
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map((m) => Project.fromJson(m))
          .toList();
    }
    return [];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Project && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
