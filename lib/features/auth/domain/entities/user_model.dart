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
  final String email; // بريد حساب المعلمة في Firebase Auth، يُحفَظ هنا لتتمكن المشرفة من عرضه ونسخه لاحقاً

  const UserModel({
    required this.uid,
    required this.name,
    required this.role,
    this.mosqueId,
    required this.isActive,
    required this.createdAt,
    this.assignedSchoolIds = const [],
    this.assignedCircleIds = const [],
    this.email = '',
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
        'email': email,
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
      // بعض الحسابات القديمة (قبل إضافة هذا الحقل) لن يوجد فيها email —
      // نُرجع نص فارغاً بدل رمي استثناء حتى لا تنهار الشاشة.
      email: json['email'] as String? ?? '',
    );
  }

  UserModel copyWith({
    String? name,
    UserRole? role,
    String? mosqueId,
    bool? isActive,
    List<String>? assignedSchoolIds,
    List<String>? assignedCircleIds,
    String? email,
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
      email: email ?? this.email,
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
        email,
      ];
}