import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/certificate_repository_impl.dart';
import '../../domain/entities/certificate_batch.dart';
import '../../domain/repositories/certificate_repository.dart';

final certificateRepositoryProvider = Provider<CertificateRepository>(
  (ref) => CertificateRepositoryImpl(),
);

/// آخر دُفعات الشهادات ضمن مسجد واحد (لمشرفة المسجد) — قراءة واحدة خفيفة
/// مُقيَّدة بعدد صغير، لا علاقة لها بعدد الطالبات داخل كل دفعة.
///
/// autoDispose + keepAlive بمؤقّت 60 ثانية: بنفس نمط schoolsByMosqueProvider
/// وبقية المزوّدات المُقسَّمة حسب mosqueId في هذا المشروع — حتى لا يبقى
/// مستمع Firestore حيّاً للأبد بعد مغادرة شاشة الشهادات.
final certificateBatchesByMosqueProvider =
    StreamProvider.family.autoDispose<List<CertificateBatch>, String>(
        (ref, mosqueId) {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(seconds: 60), link.close);
  ref.onDispose(timer.cancel);
  return ref.watch(certificateRepositoryProvider).watchByMosque(mosqueId);
});

/// كل الدُفعات (للمشرف العام بلا قيود على مسجد).
final certificateBatchesAllProvider =
    StreamProvider<List<CertificateBatch>>((ref) {
  return ref.watch(certificateRepositoryProvider).watchAll();
});
