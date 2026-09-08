/// بيانات مُجهَّزة لملء قالب شهادة واحدة لمستفيد واحد — تُجمَّع من مصادرها
/// الأصلية (سجل الحلقة، الدور، المساجد) وقت التوليد، بلا أي تكرار
/// لتخزينها بشكل منفصل.
class CertificateRenderData {
  final String recipientId;
  final String recipientName;
  final String mosqueName;
  final String schoolName;
  final String circleName;
  final String? teacherName;
  final String? supervisorName;
  final String? date;
  final String? academicYear;

  /// نوع الشهادة المعروضة على المستفيد - يؤخَذ من اسم القالب المعروض (`CertificateTemplateDefinition.displayName`)
  /// نفسه لكل مستفيد في نفس الدفعة - لا مصدر آخر له غير اسم القالب نفسه.
  final String? certificateType;

  const CertificateRenderData({
    required this.recipientId,
    required this.recipientName,
    this.mosqueName = '',
    this.schoolName = '',
    this.circleName = '',
    this.teacherName,
    this.supervisorName,
    this.date,
    this.academicYear,
    this.certificateType,
  });
}
