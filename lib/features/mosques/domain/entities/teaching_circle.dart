import 'package:equatable/equatable.dart';

/// حلقة تحفيظ تابعة لدار/مدرسة معيّنة
///
/// سُمّيت "TeachingCircle" (وليس "Circle") لتفادي التعارض مع
/// CircleInfo/CircleReport الموجودين في report_form، واللذين يمثّلان
/// شيئاً مختلفاً تماماً (بيانات تقرير شهري، لا الحلقة كوحدة تنظيمية).
class TeachingCircle extends Equatable {
  final String id;
  final String name;
  final String schoolId;
  final bool isActive;
  final DateTime createdAt;

  const TeachingCircle({
    required this.id,
    required this.name,
    required this.schoolId,
    required this.isActive,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'schoolId': schoolId,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TeachingCircle.fromJson(String id, Map<String, dynamic> json) {
    return TeachingCircle(
      id: id,
      name: json['name'] as String,
      schoolId: json['schoolId'] as String,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  TeachingCircle copyWith({String? name, bool? isActive}) {
    return TeachingCircle(
      id: id,
      name: name ?? this.name,
      schoolId: schoolId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, name, schoolId, isActive, createdAt];
}
