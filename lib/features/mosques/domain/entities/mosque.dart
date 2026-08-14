import 'package:equatable/equatable.dart';

/// مسجد مسجَّل في النظام
class Mosque extends Equatable {
  final String id;
  final String name;
  final bool isActive;
  final DateTime createdAt;

  /// صورة ختم مشرفة الحلقات الخاصة بهذا المسجد، مخزّنة كنص Base64.
  /// null تعني أن هذا المسجد ليس له ختم بعد (يظهر مكانه فارغاً في التقرير).
  final String? stampBase64;

  /// اسم مشرفة الحلقات الخاصة بهذا المسجد (يظهر في تذييل التقرير).
  final String? supervisorName;

  const Mosque({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
    this.stampBase64,
    this.supervisorName,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        if (stampBase64 != null) 'stampBase64': stampBase64,
        if (supervisorName != null) 'supervisorName': supervisorName,
      };

  factory Mosque.fromJson(String id, Map<String, dynamic> json) {
    return Mosque(
      id: id,
      name: json['name'] as String,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      stampBase64: json['stampBase64'] as String?,
      supervisorName: json['supervisorName'] as String?,
    );
  }

  Mosque copyWith({
    String? name,
    bool? isActive,
    String? stampBase64,
    String? supervisorName,
  }) {
    return Mosque(
      id: id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      stampBase64: stampBase64 ?? this.stampBase64,
      supervisorName: supervisorName ?? this.supervisorName,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, isActive, createdAt, stampBase64, supervisorName];
}