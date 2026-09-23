import 'imported_template_index_store_web.dart'
    if (dart.library.io) 'imported_template_index_store_io.dart' as impl;

import '../domain/entities/imported_certificate_template.dart';

/// يقرأ ويحفظ فهرس القوالب المستورَدة (بيانات وصفية فقط — لا صور) لكل
/// مسجد، بمعزل عن اختلاف طبقة التخزين الفعلية بين المنصات: ملف
/// `index.json` (أندرويد/iOS/سطح المكتب، كما كان دائماً) مقابل
/// `shared_preferences` (الويب — لا نظام ملفات هناك). صور الخلفيات نفسها
/// مسؤولية `TemplateImageStore` المنفصلة تماماً.
abstract class ImportedTemplateIndexStore {
  static Future<List<ImportedCertificateTemplate>> getForMosque(
          String mosqueId) =>
      impl.getForMosqueImpl(mosqueId);

  static Future<void> saveIndex(
          String mosqueId, List<ImportedCertificateTemplate> list) =>
      impl.saveIndexImpl(mosqueId, list);
}
