import 'imported_template_index_store.dart';
import 'template_image_store.dart';
import '../domain/entities/imported_certificate_template.dart';
import '../domain/repositories/imported_certificate_template_repository.dart';

/// تنفيذ محلي بحت لمستودع القوالب المستورَدة — لا Firestore ولا Firebase
/// Storage إطلاقاً (قرار مقصود اعتمدته المستخدمة: صفر تكلفة تخزين سحابي،
/// مقابل فقدان القوالب المستورَدة عند حذف التطبيق أو تغيير الجهاز/
/// المتصفح). هذه الفئة نفسها بلا أي اعتماد خاص بمنصّة إطلاقاً الآن — كل
/// التفريع الفعلي بين المنصات مفوَّض بالكامل لطبقتين منفصلتين حسب مسؤولية
/// كل واحدة (Single Responsibility): `ImportedTemplateIndexStore` (فهرس
/// البيانات الوصفية) و`TemplateImageStore` (صورة الخلفية الثنائية).
class ImportedCertificateTemplateRepositoryImpl
    implements ImportedCertificateTemplateRepository {
  @override
  Future<List<ImportedCertificateTemplate>> getForMosque(
          String mosqueId) =>
      ImportedTemplateIndexStore.getForMosque(mosqueId);

  @override
  Future<void> add(ImportedCertificateTemplate template) async {
    final list = await getForMosque(template.mosqueId);
    final updated = [...list, template];
    await ImportedTemplateIndexStore.saveIndex(template.mosqueId, updated);
  }

  @override
  Future<void> delete(String mosqueId, String templateId) async {
    final list = await getForMosque(mosqueId);
    ImportedCertificateTemplate? target;
    for (final t in list) {
      if (t.id == templateId) {
        target = t;
        break;
      }
    }
    final updated = list.where((t) => t.id != templateId).toList();
    await ImportedTemplateIndexStore.saveIndex(mosqueId, updated);
    if (target != null) {
      // فشل حذف الصورة (ملف أو مُدخَل IndexedDB) مُعالَج داخلياً في
      // TemplateImageStore ولا يرمي استثناء — لا يمنع نجاح حذف السجل من
      // الفهرس أعلاه بأي حال.
      await TemplateImageStore.delete(target.backgroundImagePath);
    }
  }
}
