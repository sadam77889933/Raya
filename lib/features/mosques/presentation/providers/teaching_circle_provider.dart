import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/circle_repository_impl.dart';
import '../../domain/entities/teaching_circle.dart';

final teachingCircleRepositoryProvider = Provider<TeachingCircleRepositoryImpl>(
  (ref) => TeachingCircleRepositoryImpl(),
);

/// كل الحلقات (لشاشة المشرفة في تبويب "الحلقات")
final teachingCirclesStreamProvider = StreamProvider<List<TeachingCircle>>((ref) {
  return ref.watch(teachingCircleRepositoryProvider).watchAll();
});

/// حلقات دار معيّنة فقط (تُستخدم عند إنشاء التقرير بعد اختيار الدار)
///
/// تحسين أداء: نفس ملاحظة `schoolsByMosqueProvider` — `autoDispose` +
/// `keepAlive` بمؤقّت 60 ثانية بدل `.family` دائم يتراكم مستمعوه طوال الجلسة.
final teachingCirclesBySchoolProvider =
    StreamProvider.family.autoDispose<List<TeachingCircle>, String>(
        (ref, schoolId) {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(seconds: 60), link.close);
  ref.onDispose(timer.cancel);
  return ref.watch(teachingCircleRepositoryProvider).watchBySchool(schoolId);
});

/// الحلقات النشطة فقط لدار معيّنة
final activeTeachingCirclesBySchoolProvider =
    Provider.family.autoDispose<List<TeachingCircle>, String>((ref, schoolId) {
  final circlesAsync = ref.watch(teachingCirclesBySchoolProvider(schoolId));
  return circlesAsync.when(
    data: (circles) => circles.where((c) => c.isActive).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});
