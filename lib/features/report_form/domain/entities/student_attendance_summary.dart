/// ملخّص حضور وغياب طالبة واحدة، مُجمَّع من عدة تقارير شهرية
/// خلال فترة زمنية محدَّدة
class StudentAttendanceSummary {
  final String studentName;
  final String teacherName;
  final String circleName;
  final String mosqueId;
  final int totalAttendanceDays;
  final int totalAbsenceDays;
  final int reportsCount;

  const StudentAttendanceSummary({
    required this.studentName,
    required this.teacherName,
    required this.circleName,
    required this.mosqueId,
    required this.totalAttendanceDays,
    required this.totalAbsenceDays,
    required this.reportsCount,
  });
}