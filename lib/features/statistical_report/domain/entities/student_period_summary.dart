import 'package:equatable/equatable.dart';

/// ملخّص أداء طالبة واحدة مُجمَّع من عدة تقارير شهرية خلال فترة هجرية محدَّدة.
///
/// القرار المعماري: هذا كيان مُشتق (Derived) بحت — يُبنى بالكامل بواسطة
/// StatisticalReportAggregator من بيانات [ReportSummary] الشهرية الموجودة
/// أصلاً، ولا يُخزَّن في Firestore بذاته.
class StudentPeriodSummary extends Equatable {
  final String studentName;
  final int totalAttendanceDays;
  final int totalAbsenceDays;

  /// إجمالي عدد أيام الأشهر الهجرية التي وردت فيها تقارير فعلية لهذه
  /// الطالبة (وليس عدد أيام الفترة المطلوبة كاملة) — يُستخدم كمقام لحساب
  /// نسبة الحضور/الغياب. يعتمد على طول كل شهر هجري فعلي (29 أو 30 يوماً)
  /// بدل افتراض ثابت، بحسب توجيه المستخدم.
  final int totalPossibleDays;

  /// متوسط درجة "السلوك" من 10 عبر كل التقارير المتاحة لهذه الطالبة.
  final double behaviorAvg;

  /// تقييم الحفظ المُجمَّع (أحد: ممتاز/جيد جداً/جيد/مقبول/ضعيف) — نتيجة
  /// تحويل كل تقييم شهري لرقم، حساب المتوسط، ثم إعادة الترجمة لأقرب
  /// تصنيف نصي. لا تُعرض قيمة عشرية للمستخدم أبداً.
  final String memorizationGrade;

  /// نفس مبدأ [memorizationGrade] لتقييم المراجعة.
  final String revisionGrade;

  /// عدد التقارير الشهرية الفعلية التي ساهمت في هذا الملخص (قد يكون أقل
  /// من عدد أشهر الفترة المطلوبة إن لم تُقدَّم الطالبة في كل الأشهر).
  final int reportsCount;

  const StudentPeriodSummary({
    required this.studentName,
    required this.totalAttendanceDays,
    required this.totalAbsenceDays,
    required this.totalPossibleDays,
    required this.behaviorAvg,
    required this.memorizationGrade,
    required this.revisionGrade,
    required this.reportsCount,
  });

  double get attendancePercent =>
      totalPossibleDays == 0 ? 0 : (totalAttendanceDays / totalPossibleDays) * 100;

  double get absencePercent =>
      totalPossibleDays == 0 ? 0 : (totalAbsenceDays / totalPossibleDays) * 100;

  @override
  List<Object?> get props => [
        studentName,
        totalAttendanceDays,
        totalAbsenceDays,
        totalPossibleDays,
        behaviorAvg,
        memorizationGrade,
        revisionGrade,
        reportsCount,
      ];
}
