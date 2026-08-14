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
final teachingCirclesBySchoolProvider =
    StreamProvider.family<List<TeachingCircle>, String>((ref, schoolId) {
  return ref.watch(teachingCircleRepositoryProvider).watchBySchool(schoolId);
});

/// الحلقات النشطة فقط لدار معيّنة
final activeTeachingCirclesBySchoolProvider =
    Provider.family<List<TeachingCircle>, String>((ref, schoolId) {
  final circlesAsync = ref.watch(teachingCirclesBySchoolProvider(schoolId));
  return circlesAsync.when(
    data: (circles) => circles.where((c) => c.isActive).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});
