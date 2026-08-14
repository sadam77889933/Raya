import 'package:equatable/equatable.dart';

/// دار/مدرسة تحفيظ تابعة لمسجد معيّن
///
/// المسجد الواحد يمكن أن يحتوي على أكثر من دار (مثال: مسجد له
/// دار للبنين ودار للبنات، أو أكثر من فرع).
class School extends Equatable {
  final String id;
  final String name;
  final String mosqueId;
  final bool isActive;
  final DateTime createdAt;

  const School({
    required this.id,
    required this.name,
    required this.mosqueId,
    required this.isActive,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'mosqueId': mosqueId,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };

  factory School.fromJson(String id, Map<String, dynamic> json) {
    return School(
      id: id,
      name: json['name'] as String,
      mosqueId: json['mosqueId'] as String,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  School copyWith({String? name, bool? isActive}) {
    return School(
      id: id,
      name: name ?? this.name,
      mosqueId: mosqueId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name, mosqueId, isActive, createdAt];
}
