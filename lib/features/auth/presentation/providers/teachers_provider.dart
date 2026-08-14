import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user_model.dart';
import 'auth_provider.dart';

/// قائمة كل المعلمات كـ Stream حيّة
final teachersStreamProvider = StreamProvider<List<UserModel>>((ref) {
  return ref.watch(authRepositoryProvider).watchAllTeachers();
});
/// معلمات مسجد معيّن فقط (لمشرفة المسجد)
final teachersByMosqueProvider =
    StreamProvider.family<List<UserModel>, String>((ref, mosqueId) {
  return ref.watch(authRepositoryProvider).watchTeachersByMosque(mosqueId);
});