import 'circle_info.dart';
import 'circle_report.dart';
import 'student_record.dart';
class ReportSummary {
  final String id;
  final String teacherName;
  final String mosqueId;
  final String circleId;
  final String circleName;
  final String schoolName;
  final String month;
  final String year;
  final int studentsCount;
  final DateTime createdAt;
  final List<Map<String, dynamic>> students;

  const ReportSummary({
    required this.id,
    required this.teacherName,
    required this.mosqueId,
    this.circleId = '',
    required this.circleName,
    required this.schoolName,
    required this.month,
    required this.year,
    required this.studentsCount,
    required this.createdAt,
    required this.students,
  });

  factory ReportSummary.fromFirestore(Map<String, dynamic> data) {
    return ReportSummary(
      id: data['id'] as String,
      teacherName: data['teacherName'] as String? ?? '',
      mosqueId: data['mosqueId'] as String? ?? '',
      circleId: data['circleId'] as String? ?? '',
      circleName: data['circleName'] as String? ?? '',
      schoolName: data['schoolName'] as String? ?? '',
      month: data['month'] as String? ?? '',
      year: data['year'] as String? ?? '',
      studentsCount: data['studentsCount'] as int? ?? 0,
      createdAt: DateTime.tryParse(data['createdAt'] as String? ?? '') ??
          DateTime.now(),
      students: (data['students'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
    );
  }

  ReportSummary copyWith({
    String? id,
    String? teacherName,
    String? mosqueId,
    String? circleId,
    String? circleName,
    String? schoolName,
    String? month,
    String? year,
    int? studentsCount,
    DateTime? createdAt,
    List<Map<String, dynamic>>? students,
  }) {
    return ReportSummary(
      id: id ?? this.id,
      teacherName: teacherName ?? this.teacherName,
      mosqueId: mosqueId ?? this.mosqueId,
      circleId: circleId ?? this.circleId,
      circleName: circleName ?? this.circleName,
      schoolName: schoolName ?? this.schoolName,
      month: month ?? this.month,
      year: year ?? this.year,
      studentsCount: studentsCount ?? this.studentsCount,
      createdAt: createdAt ?? this.createdAt,
      students: students ?? this.students,
    );
  }

  /// تحويل الملخص إلى CircleReport كامل لإعادة استخدام PdfGenerator
  /// الموجود بالفعل بدون تكرار أي كود
  CircleReport toCircleReport() {
    return CircleReport(
      id: id,
      circleInfo: CircleInfo(
        teacherName: teacherName,
        circleId: circleId,
        circleName: circleName,
        mosqueName: '', // يُملأ من الخارج عند الحاجة لاسم المسجد الحقيقي
        schoolId: '', // غير مُخزَّن ضمن ReportSummary حالياً
        schoolName: schoolName,
        month: month,
        year: year,
        studentsCount: studentsCount,
      ),
      students: students
          .map((s) => StudentRecord.fromJson(s))
          .toList(),
      createdAt: createdAt,
    );
  }
}
