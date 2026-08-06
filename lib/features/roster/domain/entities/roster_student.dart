import 'package:equatable/equatable.dart';

/// طالبة في سجل الحلقة الدائم
///
/// كيان مستقل عن StudentRecord (بيانات الأداء الشهري).
/// RosterStudent = من هي الطالبة وهل هي نشطة حالياً؟
class RosterStudent extends Equatable {
  final String id;
  final String name;
  final bool isActive;
  final DateTime createdAt;

  const RosterStudent({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
  });

  RosterStudent copyWith({
    String? id,
    String? name,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return RosterStudent(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };

  factory RosterStudent.fromJson(Map<String, dynamic> json) {
    return RosterStudent(
      id: json['id'] as String,
      name: json['name'] as String,
      isActive: json['isActive'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  List<Object?> get props => [id, name, isActive, createdAt];
}