import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/certificate_template_layout_repository_impl.dart';
import '../../domain/entities/certificate_template_layout.dart';
import '../../domain/repositories/certificate_template_layout_repository.dart';

final certificateTemplateLayoutRepositoryProvider =
    Provider<CertificateTemplateLayoutRepository>(
        (ref) => CertificateTemplateLayoutRepositoryImpl());

/// معرِّف مركَّب (مسجد + قالب أساسي) — `record` يوفّر مساواة بنيوية
/// تلقائياً، فيصلح مباشرة كمعامل `family` بلا أي صنف مساعد إضافي.
typedef CertificateTemplateLayoutKey = ({String mosqueId, String templateId});

/// التخطيط المخصَّص (إن وُجد) لمسجد+قالب أساسي معيّنين — `autoDispose` +
/// `keepAlive` بمؤقّت ٦٠ ثانية، بنفس نمط بقية مزوّدات الميزة المُقسَّمة
/// حسب مُعرّف (`certificateBatchesByMosqueProvider`، `teachersByMosqueProvider`...).
final certificateTemplateLayoutProvider = StreamProvider.family
    .autoDispose<CertificateTemplateLayout?, CertificateTemplateLayoutKey>(
        (ref, key) {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(seconds: 60), link.close);
  ref.onDispose(timer.cancel);
  return ref
      .watch(certificateTemplateLayoutRepositoryProvider)
      .watch(key.mosqueId, key.templateId);
});
