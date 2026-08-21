import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user_model.dart';
import 'auth_provider.dart';

/// قائمة كل المعلمات كـ Stream حيّة
final teachersStreamProvider = StreamProvider<List<UserModel>>((ref) {
  return ref.watch(authRepositoryProvider).watchAllTeachers();
});

/// معلمات مسجد معيّن فقط (لمشرفة المسجد)
///
/// تحسين أداء: نفس ملاحظة `schoolsByMosqueProvider` — `autoDispose` +
/// `keepAlive` بمؤقّت 60 ثانية بدل `.family` دائم يتراكم مستمعوه طوال الجلسة.
final teachersByMosqueProvider =
    StreamProvider.family.autoDispose<List<UserModel>, String>((ref, mosqueId) {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(seconds: 60), link.close);
  ref.onDispose(timer.cancel);
  return ref.watch(authRepositoryProvider).watchTeachersByMosque(mosqueId);
});