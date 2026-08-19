import 'package:equatable/equatable.dart';

import 'follow_up_student.dart';
import 'student_period_summary.dart';

/// نتيجة تجميع التقرير الإحصائي لحلقة واحدة خلال فترة هجرية محدَّدة.
///
/// هذا كيان مُشتق بحت (Derived) يبنيه StatisticalReportAggregator من
/// تقارير شهرية موجودة أصلاً — لا يُخزَّن بذاته في Firestore، ويُعاد
/// حسابه في كل مرة تُختار فيها فترة/فلاتر جديدة.
class StatisticalReportResult extends Equatable {
  /// عدد التقارير الشهرية الفعلية التي دخلت في التجميع.
  final int reportsCount;

  /// ملخّص كل طالبة ظهرت في أي تقرير ضمن النطاق المختار.
  final List<StudentPeriodSummary> students;

  /// الطالبات اللواتي استوفين معياراً واحداً على الأقل من معايير المتابعة.
  final List<FollowUpStudent> followUps;

  /// متوسط نسبة الحضور على مستوى الحلقة (متوسط كل الطالبات اللواتي لهن
  /// بيانات فعلية خلال الفترة).
  final double avgAttendancePercent;
  final double avgAbsencePercent;

  /// متوسط درجة السلوك من 10 على مستوى الحلقة.
  final double avgBehavior;

  /// التقييم العام المُجمَّع للحفظ/المراجعة على مستوى الحلقة بأكملها
  /// (مُحتسب من كل التقييمات الفردية مباشرة، وليس من متوسط الطالبات
  /// المُقرَّب مسبقاً، لتفادي خطأ التقريب المزدوج).
  final String overallMemorizationGrade;
  final String overallRevisionGrade;

  const StatisticalReportResult({
    required this.reportsCount,
    required this.students,
    required this.followUps,
    required this.avgAttendancePercent,
    required this.avgAbsencePercent,
    required this.avgBehavior,
    required this.overallMemorizationGrade,
    required this.overallRevisionGrade,
  });

  static const empty = StatisticalReportResult(
    reportsCount: 0,
    students: [],
    followUps: [],
    avgAttendancePercent: 0,
    avgAbsencePercent: 0,
    avgBehavior: 0,
    overallMemorizationGrade: '',
    overallRevisionGrade: '',
  );

  @override
  List<Object?> get props => [
        reportsCount,
        students,
        followUps,
        avgAttendancePercent,
        avgAbsencePercent,
        avgBehavior,
        overallMemorizationGrade,
        overallRevisionGrade,
      ];
}
