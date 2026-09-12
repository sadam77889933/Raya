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

  /// اسم معلمة (أو معلمات، مفصولة بفاصلة عربية) هذه الحلقة تحديداً — يُملأ
  /// فقط من طرف مستهلِكي هذا الكيان الذين يحتاجونه فعلاً (الشهادات، حقل
  /// [CertificateField.teacherName] القابل للإضافة يدوياً على قوالب
  /// الطالبات)؛ تقرير "قائمة أسماء الطالبات" الأصلي لا يمرّره فيبقى
  /// `null` هناك دون أي أثر عليه. `null` تعني ببساطة عدم وجود معلمة
  /// مسندة لهذه الحلقة حالياً، لا خطأً.
  final String? teacherName;

  const RosterReportGroup({
    required this.mosqueName,
    required this.schoolName,
    required this.circleName,
    required this.students,
    this.teacherName,
  });
}
