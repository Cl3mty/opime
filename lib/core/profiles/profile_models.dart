class Profile {
  final String id;
  final String name;
  final String relationship;
  final bool isMaster;
  final DateTime createdAt;

  Profile({
    required this.id,
    required this.name,
    required this.relationship,
    required this.isMaster,
    required this.createdAt,
  });

  Profile copyWith({String? name, String? relationship}) => Profile(
    id: id,
    name: name ?? this.name,
    relationship: relationship ?? this.relationship,
    isMaster: isMaster,
    createdAt: createdAt,
  );

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    relationship: json['relationship'] as String? ?? '',
    isMaster: json['isMaster'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'relationship': relationship,
    'isMaster': isMaster,
    'createdAt': createdAt.toIso8601String(),
  };
}
