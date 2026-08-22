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

  /// وقت الحلقة اليومي. القيمة الافتراضية "عصراً" لأي حلقة لم يُحدَّد
  /// وقتها صراحةً (حلقات قديمة أو لم تُعدَّل بعد)، حتى لا تحتاج المشرفة
  /// لتعديل كل حلقة يدوياً بعد إضافة هذا الحقل.
  final String circleTime;

  static const String defaultCircleTime = 'عصراً';

  /// خيارات وقت الحلقة الظاهرة في نافذة إضافة/تعديل الحلقة.
  static const List<String> circleTimeOptions = [
    'فجراً',
    'صباحاً',
    'ضحى',
    'ظهراً',
    'عصراً',
    'مساءً',
    'ليلاً',
  ];

  const TeachingCircle({
    required this.id,
    required this.name,
    required this.schoolId,
    required this.isActive,
    required this.createdAt,
    this.circleTime = defaultCircleTime,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'schoolId': schoolId,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'circleTime': circleTime,
      };

  factory TeachingCircle.fromJson(String id, Map<String, dynamic> json) {
    return TeachingCircle(
      id: id,
      name: json['name'] as String,
      schoolId: json['schoolId'] as String,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      circleTime: json['circleTime'] as String? ?? defaultCircleTime,
    );
  }

  TeachingCircle copyWith({String? name, bool? isActive, String? circleTime}) {
    return TeachingCircle(
      id: id,
      name: name ?? this.name,
      schoolId: schoolId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      circleTime: circleTime ?? this.circleTime,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, schoolId, isActive, createdAt, circleTime];
}
