import 'package:equatable/equatable.dart';

/// دور المستخدم في التطبيق
enum UserRole { teacher, supervisor, mosqueSupervisor }

/// بيانات المستخدم كما تُخزَّن في Firestore
class UserModel extends Equatable {
  final String uid;
  final String name;
  final UserRole role;
  final String? mosqueId; // فقط للمعلمة
  final bool isActive;
  final DateTime createdAt;
  final List<String> assignedSchoolIds; // الدور/المدارس التي تُدرّس بها المعلمة
  final List<String> assignedCircleIds; // الحلقات التي تُدرّس بها المعلمة

  const UserModel({
    required this.uid,
    required this.name,
    required this.role,
    this.mosqueId,
    required this.isActive,
    required this.createdAt,
    this.assignedSchoolIds = const [],
    this.assignedCircleIds = const [],
  });

  bool get isTeacher => role == UserRole.teacher;
  bool get isSupervisor => role == UserRole.supervisor;
  bool get isMosqueSupervisor => role == UserRole.mosqueSupervisor;
  Map<String, dynamic> toJson() => {
        'name': name,
        'role': role.name,
        'mosqueId': mosqueId,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'assignedSchoolIds': assignedSchoolIds,
        'assignedCircleIds': assignedCircleIds,
      };

  factory UserModel.fromJson(String uid, Map<String, dynamic> json) {
    UserRole parsedRole;
    switch (json['role']) {
      case 'supervisor':
        parsedRole = UserRole.supervisor;
        break;
      case 'mosqueSupervisor':
        parsedRole = UserRole.mosqueSupervisor;
        break;
      default:
        parsedRole = UserRole.teacher;
    }
    return UserModel(
      uid: uid,
      name: json['name'] as String,
      role: parsedRole,
      mosqueId: json['mosqueId'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      assignedSchoolIds: (json['assignedSchoolIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      assignedCircleIds: (json['assignedCircleIds'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  UserModel copyWith({
    String? name,
    UserRole? role,
    String? mosqueId,
    bool? isActive,
    List<String>? assignedSchoolIds,
    List<String>? assignedCircleIds,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      role: role ?? this.role,
      mosqueId: mosqueId ?? this.mosqueId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      assignedSchoolIds: assignedSchoolIds ?? this.assignedSchoolIds,
      assignedCircleIds: assignedCircleIds ?? this.assignedCircleIds,
    );
  }

  @override
  List<Object?> get props => [
        uid,
        name,
        role,
        mosqueId,
        isActive,
        createdAt,
        assignedSchoolIds,
        assignedCircleIds,
      ];
}