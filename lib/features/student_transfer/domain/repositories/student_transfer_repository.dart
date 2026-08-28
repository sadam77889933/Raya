import '../entities/student_transfer.dart';

/// عقد نقل طالبة من حلقة إلى أخرى (داخل نفس المسجد أو بين مسجدين).
///
/// **ملاحظة معمارية مهمة:** هذا المستودع يُنفّذ عمليتين معاً بشكل ذرّي عبر
/// `WriteBatch` واحدة: (أ) تحديث `circleId` الحالي للطالبة في `roster_students`
/// — وهو الحقل الوحيد الذي يحدّد أين تظهر الطالبة في أي تقرير *جديد* يُنشأ
/// من الآن فصاعداً؛ و(ب) إنشاء سجل تاريخي في `student_transfers` لا يمكن
/// لأي كود آخر في التطبيق قراءته إلا لعرضه كسجل ("من نقل، من أين، إلى أين").
///
/// **لماذا لا يمسّ هذا أي تقرير قديم:** كل تقرير شهري في مجموعة `reports`
/// يُخزَّن كنسخة كاملة ومستقلة وقت إنشائه (circleId + اسم كل طالبة كنص
/// مباشر ضمن مصفوفة مضمَّنة)، وليس رابطاً حياً بـ`roster_students`. لا يوجد
/// أي كود في التطبيق يُعيد قراءة `roster_students` بعد حفظ تقرير لتحديث ذلك
/// التقرير — لذلك تغيير `circleId` هنا لا يغيّر ولا يمكن أن يغيّر أي تقرير
/// سابق، بغضّ النظر عمّا يحدث لاحقاً لسجل الطالبة في القائمة.
abstract class StudentTransferRepository {
  Future<void> transferStudent({
    required String studentId,
    required String studentName,
    required String fromMosqueId,
    required String fromMosqueName,
    required String fromSchoolId,
    required String fromSchoolName,
    required String fromCircleId,
    required String fromCircleName,
    required String toMosqueId,
    required String toMosqueName,
    required String toSchoolId,
    required String toSchoolName,
    required String toCircleId,
    required String toCircleName,
    required String transferHijriMonth,
    required String transferHijriYear,
    required String performedByUid,
    required String performedByName,
    String reason = '',
  });

  /// كل عمليات النقل التي طرفها (من أو إلى) هذا المسجد — تكفي وحدها لمشرفة
  /// المسجد لأنها مقفلة على مسجدها من الطرفين (من وإلى) دائماً، فـ
  /// `fromMosqueId == toMosqueId` في كل عملية تنفّذها.
  Stream<List<StudentTransfer>> watchByMosque(String mosqueId);

  /// كل عمليات النقل في كل المساجد — للمشرف العام فقط.
  Stream<List<StudentTransfer>> watchAll();
}
