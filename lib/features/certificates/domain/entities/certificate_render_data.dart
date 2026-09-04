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
  });
}
