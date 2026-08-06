import 'package:equatable/equatable.dart';

/// دور المستخدم في التطبيق
enum UserRole { teacher, supervisor }

/// بيانات المستخدم كما تُخزَّن في Firestore
class UserModel extends Equatable {
  final String uid;
  final String name;
  final UserRole role;
  final String? mosqueId; // فقط للمعلمة
  final bool isActive;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.role,
    this.mosqueId,
    required this.isActive,
    required this.createdAt,
  });

  bool get isTeacher => role == UserRole.teacher;
  bool get isSupervisor => role == UserRole.supervisor;

  Map<String, dynamic> toJson() => {
        'name': name,
        'role': role.name,
        'mosqueId': mosqueId,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserModel.fromJson(String uid, Map<String, dynamic> json) {
    return UserModel(
      uid: uid,
      name: json['name'] as String,
      role: json['role'] == 'supervisor'
          ? UserRole.supervisor
          : UserRole.teacher,
      mosqueId: json['mosqueId'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  UserModel copyWith({
    String? name,
    UserRole? role,
    String? mosqueId,
    bool? isActive,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      role: role ?? this.role,
      mosqueId: mosqueId ?? this.mosqueId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [uid, name, role, mosqueId, isActive, createdAt];
}