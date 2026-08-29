import 'package:equatable/equatable.dart';

/// إسناد معلمة إلى (مستوى + مادة) داخل مركز صيفي واحد.
///
/// وثيقة مستقلة واحدة لكل (معلمة، مستوى، مادة) — معلمة واحدة قد تُدرِّس
/// أكثر من مستوى وأكثر من مادة في المستوى الواحد، فتظهر لها عدة وثائق.
/// [teacherName] و[mosqueId] مُخزَّنان هنا كتكرار مقصود (denormalized)
/// لتُعرض شاشة "توزيع المعلمات" وشاشة "اختباراتي" مباشرة من هذه المجموعة
/// وحدها دون أي قراءة إضافية لوثيقة المعلمة أو المسجد.
class SummerAssignment extends Equatable {
  final String id;
  final String centerId;
  final String mosqueId;
  final String levelId;
  final String subjectId;
  final String teacherId;
  final String teacherName;
  final DateTime createdAt;

  const SummerAssignment({
    required this.id,
    required this.centerId,
    required this.mosqueId,
    required this.levelId,
    required this.subjectId,
    required this.teacherId,
    required this.teacherName,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'centerId': centerId,
        'mosqueId': mosqueId,
        'levelId': levelId,
        'subjectId': subjectId,
        'teacherId': teacherId,
        'teacherName': teacherName,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SummerAssignment.fromJson(String id, Map<String, dynamic> json) {
    return SummerAssignment(
      id: id,
      centerId: json['centerId'] as String,
      mosqueId: json['mosqueId'] as String,
      levelId: json['levelId'] as String,
      subjectId: json['subjectId'] as String,
      teacherId: json['teacherId'] as String,
      teacherName: json['teacherName'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  List<Object?> get props => [
        id,
        centerId,
        mosqueId,
        levelId,
        subjectId,
        teacherId,
        teacherName,
        createdAt,
      ];
}
