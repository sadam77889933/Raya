import '../entities/imported_certificate_template.dart';

/// عقد الوصول لقوالب الشهادات **المستورَدة** (القسم ٦ من تصميم الميزة) —
/// منفصل تماماً عن `CertificateTemplateLayoutRepository` (تخطيطات القوالب
/// الأساسية) لأن هذه سجلات قوالب كاملة جديدة (صورة خلفية + بيانات وصفية)،
/// لا مجرد تخصيص فوق قالب موجود أصلاً. التنفيذ الفعلي محلي بحتاً على جهاز
/// المشرفة (لا Firestore) — انظر `ImportedCertificateTemplateRepositoryImpl`.
abstract class ImportedCertificateTemplateRepository {
  /// كل القوالب المستورَدة لمسجد معيّن.
  Future<List<ImportedCertificateTemplate>> getForMosque(String mosqueId);

  Future<void> add(ImportedCertificateTemplate template);

  /// تحذف السجل من الفهرس، وتحاول حذف ملف صورة الخلفية المرتبط به أيضاً
  /// (فشل حذف الصورة نفسها لا يمنع حذف السجل من الفهرس).
  Future<void> delete(String mosqueId, String templateId);
}
