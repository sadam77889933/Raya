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
final schoolsByMosqueProvider =
    StreamProvider.family<List<School>, String>((ref, mosqueId) {
  return ref.watch(schoolRepositoryProvider).watchByMosque(mosqueId);
});

/// الدور النشطة فقط لمسجد معيّن
final activeSchoolsByMosqueProvider =
    Provider.family<List<School>, String>((ref, mosqueId) {
  final schoolsAsync = ref.watch(schoolsByMosqueProvider(mosqueId));
  return schoolsAsync.when(
    data: (schools) => schools.where((s) => s.isActive).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});
