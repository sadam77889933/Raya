import '../domain/entities/report_summary.dart';
import '../domain/entities/student_attendance_summary.dart';

class AttendanceAggregator {
  static const List<String> hijriMonths = [
    'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر',
    'جمادى الأولى', 'جمادى الآخرة', 'رجب', 'شعبان',
    'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
  ];

  static int _monthKey(String month, String year) {
    final monthIndex = hijriMonths.indexOf(month);
    final yearNum = int.tryParse(year) ?? 0;
    return yearNum * 12 + (monthIndex >= 0 ? monthIndex : 0);
  }

  static List<StudentAttendanceSummary> aggregate({
    required List<ReportSummary> allReports,
    required String fromMonth,
    required String fromYear,
    required String toMonth,
    required String toYear,
    String? studentNameFilter,
    String? mosqueIdFilter,
    String? teacherNameFilter,
    String? schoolNameFilter,
    String? circleNameFilter,
  }) {
    final fromKey = _monthKey(fromMonth, fromYear);
    final toKey = _monthKey(toMonth, toYear);

    final filteredReports = allReports.where((r) {
      final reportKey = _monthKey(r.month, r.year);
      if (reportKey < fromKey || reportKey > toKey) return false;

      if (mosqueIdFilter != null && r.mosqueId != mosqueIdFilter) return false;
      // مطابقة تامة (وليست "يحتوي على"): هذه القيم تأتي دائماً من اختيار
      // فعلي في قائمة منسدلة (اسم معلمة/دار/حلقة حقيقي)، وليست نصاً حراً،
      // فتفادي المطابقة الجزئية يمنع تداخل الأسماء المتشابهة.
      if (teacherNameFilter != null && r.teacherName != teacherNameFilter) {
        return false;
      }
      if (schoolNameFilter != null && r.schoolName != schoolNameFilter) {
        return false;
      }
      if (circleNameFilter != null && r.circleName != circleNameFilter) {
        return false;
      }

      return true;
    }).toList();

    final Map<String, _Accumulator> accumulators = {};

    for (final report in filteredReports) {
      for (final studentMap in report.students) {
        final name = studentMap['name'] as String? ?? '';
        if (name.isEmpty) continue;

        if (studentNameFilter != null &&
            studentNameFilter.isNotEmpty &&
            !name.contains(studentNameFilter)) {
          continue;
        }

        final attendance = studentMap['attendanceDays'] as int? ?? 0;
        final absence = studentMap['absenceDays'] as int? ?? 0;

        final acc = accumulators.putIfAbsent(
          name,
          () => _Accumulator(
            teacherName: report.teacherName,
            circleName: report.circleName,
            mosqueId: report.mosqueId,
          ),
        );
        acc.attendance += attendance;
        acc.absence += absence;
        acc.reportsCount += 1;
      }
    }

    final result = accumulators.entries
        .map((entry) => StudentAttendanceSummary(
              studentName: entry.key,
              teacherName: entry.value.teacherName,
              circleName: entry.value.circleName,
              mosqueId: entry.value.mosqueId,
              totalAttendanceDays: entry.value.attendance,
              totalAbsenceDays: entry.value.absence,
              reportsCount: entry.value.reportsCount,
            ))
        .toList();

    result.sort((a, b) => b.totalAbsenceDays.compareTo(a.totalAbsenceDays));
    return result;
  }
}

class _Accumulator {
  final String teacherName;
  final String circleName;
  final String mosqueId;
  int attendance = 0;
  int absence = 0;
  int reportsCount = 0;

  _Accumulator({
    required this.teacherName,
    required this.circleName,
    required this.mosqueId,
  });
}