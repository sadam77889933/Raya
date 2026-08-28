import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/student_transfer_repository_impl.dart';
import '../../domain/entities/student_transfer.dart';
import '../../domain/repositories/student_transfer_repository.dart';

final studentTransferRepositoryProvider = Provider<StudentTransferRepository>(
  (ref) => StudentTransferRepositoryImpl(),
);

/// سجل انتقالات مسجد واحد — لمشرفة المسجد. `autoDispose` + `keepAlive`
/// بمؤقّت 60 ثانية بنفس نمط بقية مزوّدات family في المشروع، لتفادي إبقاء
/// مستمع Firestore حيّاً للأبد بعد مغادرة شاشة السجل.
final mosqueTransferHistoryProvider =
    StreamProvider.family.autoDispose<List<StudentTransfer>, String>(
        (ref, mosqueId) {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(seconds: 60), link.close);
  ref.onDispose(timer.cancel);
  return ref.watch(studentTransferRepositoryProvider).watchByMosque(mosqueId);
});

/// سجل انتقالات كل المساجد — للمشرف العام فقط.
final allTransferHistoryProvider = StreamProvider<List<StudentTransfer>>((ref) {
  return ref.watch(studentTransferRepositoryProvider).watchAll();
});
