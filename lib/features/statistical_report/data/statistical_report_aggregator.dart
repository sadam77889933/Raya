import 'package:hijri/hijri_calendar.dart';

import '../../../core/constants/quran_constants.dart';
import '../../report_form/domain/entities/report_summary.dart';
import '../domain/entities/follow_up_student.dart';
import '../domain/entities/statistical_report_result.dart';
import '../domain/entities/student_period_summary.dart';
import '../domain/performance_rating.dart';

/// يجمّع تقارير شهرية متعددة (ReportSummary) ضمن فترة هجرية محدَّدة إلى
/// [StatisticalReportResult] واحد — منطق حسابي بحت بلا أي اعتماد على
/// الواجهة، بنفس روح AttendanceAggregator الموجود مسبقاً في المشروع.
///
/// معايير التجميع:
/// - القيم الرقمية (حضور/غياب/سلوك): متوسط حسابي عبر كل التقارير المتاحة.
/// - القيم الوصفية (تقييم الحفظ/المراجعة): تُحوَّل لرقم، يُحسب متوسطها،
///   ثم تُعاد لأقرب تصنيف نصي — لا تُعرض قيمة عشرية للمستخدم أبداً.
/// - مقام نسبة الحضور/الغياب لكل طالبة هو مجموع "عدد أيام الشهر الهجري"
///   (29 أو 30 حسب الشهر الفعلي) لكل شهر وردت فيه هذه الطالبة ضمن تقرير
///   فعلي — وليس عدد أيام الفترة المطلوبة كاملة، تفادياً لتحميل الطالبة
///   نسبة غياب وهمية عن أشهر لم تُرفع فيها تقارير أصلاً.
class StatisticalReportAggregator {
  static int _monthIndex(String month) =>
      QuranConstants.hijriMonths.indexOf(month);

  // نفس صيغة `QuranConstants.hijriPeriodKey` تماماً — مُوحَّدة هناك الآن بدل
  // تكرارها هنا (كانت مكرَّرة سابقاً مع AttendanceAggregator ومع حساب
  // periodKey عند رفع التقرير في CircleReport.toFirestoreJson).
  static int _monthKey(String month, String year) =>
      QuranConstants.hijriPeriodKey(month, year);

  static int _daysInHijriMonth(String month, String year) {
    final mi = _monthIndex(month);
    final y = int.tryParse(year) ?? 0;
    if (mi < 0 || y <= 0) return 30;
    try {
      return HijriCalendar().getDaysInMonth(y, mi + 1);
    } catch (_) {
      return 30;
    }
  }

  /// عتبات "بحاجة إلى متابعة" — قابلة للتعديل لاحقاً من مكان واحد.
  static const double followUpAttendanceThreshold = 80;
  static const double followUpAbsenceThreshold = 20;
  static const double followUpBehaviorThreshold = 6.5;
  static const List<String> followUpLowGrades = ['ضعيف', 'مقبول'];

  static StatisticalReportResult aggregate({
    required List<ReportSummary> allReports,
    required String fromMonth,
    required String fromYear,
    required String toMonth,
    required String toYear,
    String? mosqueIdFilter,
    String? schoolNameFilter,
    String? circleNameFilter,
    String? teacherNameFilter,
  }) {
    final fromKey = _monthKey(fromMonth, fromYear);
    final toKey = _monthKey(toMonth, toYear);

    final filteredReports = allReports.where((r) {
      final key = _monthKey(r.month, r.year);
      if (key < fromKey || key > toKey) return false;
      if (mosqueIdFilter != null && r.mosqueId != mosqueIdFilter) return false;
      if (schoolNameFilter != null && r.schoolName != schoolNameFilter) {
        return false;
      }
      if (circleNameFilter != null && r.circleName != circleNameFilter) {
        return false;
      }
      if (teacherNameFilter != null && r.teacherName != teacherNameFilter) {
        return false;
      }
      return true;
    }).toList();

    final Map<String, _StudentAcc> studentAccs = {};
    final _CircleAcc circleAcc = _CircleAcc();

    for (final report in filteredReports) {
      final possibleDays = _daysInHijriMonth(report.month, report.year);

      for (final studentMap in report.students) {
        final name = studentMap['name'] as String? ?? '';
        if (name.isEmpty) continue;

        final attendance = studentMap['attendanceDays'] as int? ?? 0;
        final absence = studentMap['absenceDays'] as int? ?? 0;
        final behavior = studentMap['behaviorScore'] as int? ?? 10;
        final grade = studentMap['grade'] as String? ?? '';
        final reviewGrade = studentMap['reviewGrade'] as String? ?? '';

        final acc = studentAccs.putIfAbsent(name, () => _StudentAcc());
        acc.attendance += attendance;
        acc.absence += absence;
        acc.possibleDays += possibleDays;
        acc.behaviorSum += behavior;
        acc.behaviorCount += 1;
        acc.reportsCount += 1;

        final gradeScore = PerformanceRating.scoreOf(grade);
        if (gradeScore > 0) {
          acc.gradeSum += gradeScore;
          acc.gradeCount += 1;
          circleAcc.gradeSum += gradeScore;
          circleAcc.gradeCount += 1;
        }
        final reviewScore = PerformanceRating.scoreOf(reviewGrade);
        if (reviewScore > 0) {
          acc.reviewSum += reviewScore;
          acc.reviewCount += 1;
          circleAcc.reviewSum += reviewScore;
          circleAcc.reviewCount += 1;
        }

        circleAcc.behaviorSum += behavior;
        circleAcc.behaviorCount += 1;
      }
    }

    final students = studentAccs.entries.map((entry) {
      final a = entry.value;
      return StudentPeriodSummary(
        studentName: entry.key,
        totalAttendanceDays: a.attendance,
        totalAbsenceDays: a.absence,
        totalPossibleDays: a.possibleDays,
        behaviorAvg: a.behaviorCount == 0 ? 0.0 : a.behaviorSum / a.behaviorCount,
        memorizationGrade: a.gradeCount == 0
            ? ''
            : PerformanceRating.gradeFromAverageScore(a.gradeSum / a.gradeCount),
        revisionGrade: a.reviewCount == 0
            ? ''
            : PerformanceRating.gradeFromAverageScore(a.reviewSum / a.reviewCount),
        reportsCount: a.reportsCount,
      );
    }).toList()
      ..sort((x, y) => x.studentName.compareTo(y.studentName));

    final followUps = <FollowUpStudent>[];
    for (final s in students) {
      final reasons = <String>[];
      if (s.totalPossibleDays > 0 &&
          s.attendancePercent < followUpAttendanceThreshold) {
        reasons.add('انخفاض نسبة الحضور');
      }
      if (s.totalPossibleDays > 0 &&
          s.absencePercent > followUpAbsenceThreshold) {
        reasons.add('ارتفاع نسبة الغياب');
      }
      if (followUpLowGrades.contains(s.memorizationGrade)) {
        reasons.add('تراجع تقييم الحفظ');
      }
      if (s.behaviorAvg > 0 && s.behaviorAvg < followUpBehaviorThreshold) {
        reasons.add('انخفاض درجة السلوك');
      }
      if (reasons.isNotEmpty) {
        followUps.add(FollowUpStudent(summary: s, reasons: reasons));
      }
    }
    // الأكثر إلحاحاً أولاً: عدد أسباب أكثر يعني وضعاً أصعب.
    followUps.sort((a, b) => b.reasons.length.compareTo(a.reasons.length));

    final withAttendanceData =
        students.where((s) => s.totalPossibleDays > 0).toList();
    double avg(Iterable<double> xs) {
      final list = xs.toList();
      return list.isEmpty ? 0.0 : list.reduce((a, b) => a + b) / list.length;
    }

    return StatisticalReportResult(
      reportsCount: filteredReports.length,
      students: students,
      followUps: followUps,
      avgAttendancePercent: avg(withAttendanceData.map((s) => s.attendancePercent)),
      avgAbsencePercent: avg(withAttendanceData.map((s) => s.absencePercent)),
      avgBehavior: circleAcc.behaviorCount == 0
          ? 0.0
          : circleAcc.behaviorSum / circleAcc.behaviorCount,
      overallMemorizationGrade: circleAcc.gradeCount == 0
          ? ''
          : PerformanceRating.gradeFromAverageScore(
              circleAcc.gradeSum / circleAcc.gradeCount),
      overallRevisionGrade: circleAcc.reviewCount == 0
          ? ''
          : PerformanceRating.gradeFromAverageScore(
              circleAcc.reviewSum / circleAcc.reviewCount),
    );
  }
}

class _StudentAcc {
  int attendance = 0;
  int absence = 0;
  int possibleDays = 0;
  int behaviorSum = 0;
  int behaviorCount = 0;
  int gradeSum = 0;
  int gradeCount = 0;
  int reviewSum = 0;
  int reviewCount = 0;
  int reportsCount = 0;
}

class _CircleAcc {
  int behaviorSum = 0;
  int behaviorCount = 0;
  int gradeSum = 0;
  int gradeCount = 0;
  int reviewSum = 0;
  int reviewCount = 0;
}
