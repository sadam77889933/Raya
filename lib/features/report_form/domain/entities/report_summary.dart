import '../../../core/constants/quran_constants.dart';
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
  final List<String> companionCurriculums;

  /// مفتاح الفترة الهجرية الرقمي (السنة×12 + رقم الشهر). التقارير المرفوعة
  /// حديثاً تحمله مُخزَّناً في Firestore؛ التقارير القديمة التي رُفعت قبل
  /// إضافة هذا الحقل لا تملكه، فيُحسَب هنا في الذاكرة من `month`/`year`
  /// بنفس الصيغة تماماً (`QuranConstants.hijriPeriodKey`) — بحيث تبقى قيمة
  /// `periodKey` صحيحة ومتاحة لكل تقرير بلا استثناء، بغض النظر عن كونها
  /// مخزَّنة في المستند نفسه أو محسوبة عند القراءة.
  final int periodKey;

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
    this.companionCurriculums = const [],
    required this.periodKey,
  });

  factory ReportSummary.fromFirestore(Map<String, dynamic> data) {
    final month = data['month'] as String? ?? '';
    final year = data['year'] as String? ?? '';
    return ReportSummary(
      id: data['id'] as String,
      teacherName: data['teacherName'] as String? ?? '',
      mosqueId: data['mosqueId'] as String? ?? '',
      circleId: data['circleId'] as String? ?? '',
      circleName: data['circleName'] as String? ?? '',
      schoolName: data['schoolName'] as String? ?? '',
      month: month,
      year: year,
      studentsCount: data['studentsCount'] as int? ?? 0,
      createdAt: DateTime.tryParse(data['createdAt'] as String? ?? '') ??
          DateTime.now(),
      students: (data['students'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
      companionCurriculums: (data['companionCurriculums'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      periodKey: data['periodKey'] as int? ??
          QuranConstants.hijriPeriodKey(month, year),
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
    List<String>? companionCurriculums,
    int? periodKey,
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
      companionCurriculums: companionCurriculums ?? this.companionCurriculums,
      periodKey: periodKey ?? this.periodKey,
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
        companionCurriculums: companionCurriculums,
      ),
      students: students
          .map((s) => StudentRecord.fromJson(s))
          .toList(),
      createdAt: createdAt,
    );
  }
}
