import '../entities/certificate_template_layout.dart';

/// عقد الوصول لتخطيطات القوالب المخصَّصة لكل مسجد (القسم ١٣ من تصميم
/// الميزة) — منفصل تماماً عن `CertificateRepository` (دُفعات الشهادات)
/// لأن هذه بيانات إعداد قالب، لا سجل إصدار.
abstract class CertificateTemplateLayoutRepository {
  /// دفق التخطيط المخصَّص لمسجد+قالب أساسي معيّنين، أو `null` إن لم تُخصِّص
  /// هذه المسجد أي تعديل على هذا القالب بعد (تُستخدم عندها المواضع
  /// الثابتة في القالب الأساسي كما هي).
  Stream<CertificateTemplateLayout?> watch(
      String mosqueId, String baseTemplateId);

  /// قراءة واحدة فورية (تُستخدَم وقت توليد PDF فعلي، لا للعرض المستمر).
  Future<CertificateTemplateLayout?> get(
      String mosqueId, String baseTemplateId);

  Future<void> save(CertificateTemplateLayout layout);
}
