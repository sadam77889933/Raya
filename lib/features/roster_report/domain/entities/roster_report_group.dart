import '../../../roster/domain/entities/roster_student.dart';

/// طالبات حلقة واحدة ضمن نطاق تقرير "قائمة أسماء الطالبات" الحالي، بعد
/// تطبيق فلاتر المسجد/الدار/الحلقة وخيار إظهار/إخفاء غير النشطات.
///
/// يُستخدم هذا الكيان لعرض القائمة داخل التطبيق ولتوليد ملف الـPDF معاً،
/// حتى لا يُعاد حساب نفس التجميع (مسجد → دار → حلقة → طالبات) بمنطقين
/// منفصلين قد يختلفان لاحقاً بغير قصد.
class RosterReportGroup {
  final String mosqueName;
  final String schoolName;
  final String circleName;
  final List<RosterStudent> students;

  const RosterReportGroup({
    required this.mosqueName,
    required this.schoolName,
    required this.circleName,
    required this.students,
  });
}
