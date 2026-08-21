import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/school_repository_impl.dart';
import '../../domain/entities/school.dart';

final schoolRepositoryProvider = Provider<SchoolRepositoryImpl>(
  (ref) => SchoolRepositoryImpl(),
);

/// كل الدور/المدارس (لشاشة المشرفة في تبويب "الدور")
final schoolsStreamProvider = StreamProvider<List<School>>((ref) {
  return ref.watch(schoolRepositoryProvider).watchAll();
});

/// دور مسجد معيّن فقط (تُستخدم في تبويب إنشاء التقرير عند المعلمة،
/// وفي فلتر ربط الحلقة بالمسجد الصحيح)
///
/// تحسين أداء: كان هذا المزوّد (`.family` بلا `autoDispose`) يُبقي مُستمِعاً
/// حيّاً دائماً لكل مسجد جرى فتحه خلال الجلسة، بلا أي تحرير حتى تسجيل
/// الخروج — أي أن تصفّح عدة مساجد يعني تراكم مستمعين لا يُغلَق أي منهم أبداً.
/// `autoDispose` يجعل المزوّد يُتخلَّص منه فعلياً عند عدم وجود أي شاشة تتابعه،
/// و`ref.keepAlive()` مع مؤقّت 60 ثانية يمنع إعادة الجلب الفوري إن رجعت
/// المستخدمة لنفس المسجد بسرعة (كالتنقل بين التبويبات).
final schoolsByMosqueProvider =
    StreamProvider.family.autoDispose<List<School>, String>((ref, mosqueId) {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(seconds: 60), link.close);
  ref.onDispose(timer.cancel);
  return ref.watch(schoolRepositoryProvider).watchByMosque(mosqueId);
});

/// الدور النشطة فقط لمسجد معيّن
///
/// `autoDispose` هنا أيضاً (بلا حاجة لـ keepAlive، فهو حساب فوري بلا مورد
/// يُغلَق) ليتوقف عن متابعة [schoolsByMosqueProvider] فعلياً عند عدم
/// الحاجة له، بدل إبقائه حيّاً للأبد ويُبقي بذلك المزوّد الأصل حيّاً معه.
final activeSchoolsByMosqueProvider =
    Provider.family.autoDispose<List<School>, String>((ref, mosqueId) {
  final schoolsAsync = ref.watch(schoolsByMosqueProvider(mosqueId));
  return schoolsAsync.when(
    data: (schools) => schools.where((s) => s.isActive).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});
