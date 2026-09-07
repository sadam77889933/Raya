import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/imported_certificate_template_repository_impl.dart';
import '../../domain/entities/imported_certificate_template.dart';
import '../../domain/repositories/imported_certificate_template_repository.dart';

final importedCertificateTemplateRepositoryProvider =
    Provider<ImportedCertificateTemplateRepository>(
        (ref) => ImportedCertificateTemplateRepositoryImpl());

/// قائمة القوالب المستورَدة لمسجد معيّن — تخزين محلي بحت فلا حاجة لدفق
/// (`Stream`) مستمر كتخطيطات القوالب الأساسية عبر Firestore؛ قراءة واحدة
/// كافية، تُنعَش يدوياً عبر `ref.invalidate` بعد أي عملية إضافة/حذف فعلية
/// (نفس ما تفعله بقية مزوّدات البيانات المحلية/المُقسَّمة بمعرِّف في هذا
/// المشروع).
final importedCertificateTemplatesProvider = FutureProvider.family
    .autoDispose<List<ImportedCertificateTemplate>, String>((ref, mosqueId) {
  return ref
      .watch(importedCertificateTemplateRepositoryProvider)
      .getForMosque(mosqueId);
});
