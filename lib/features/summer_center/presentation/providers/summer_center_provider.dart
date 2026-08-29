import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/summer_center_repository_impl.dart';
import '../../domain/entities/summer_center.dart';

final summerCenterRepositoryProvider = Provider<SummerCenterRepositoryImpl>(
  (ref) => SummerCenterRepositoryImpl(),
);

/// كل مراكز مسجد واحد (عادة مركز فعّال واحد + أرشيف مراكز سابقة).
final summerCentersByMosqueProvider =
    StreamProvider.family.autoDispose<List<SummerCenter>, String>((ref, mosqueId) {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(seconds: 60), link.close);
  ref.onDispose(timer.cancel);
  return ref.watch(summerCenterRepositoryProvider).watchCentersByMosque(mosqueId);
});

/// مركز واحد بمعرّفه (لشاشة تفاصيل المركز، وللتحقق السريع من
/// testsEnabledForTeachers).
final summerCenterProvider =
    StreamProvider.family.autoDispose<SummerCenter?, String>((ref, centerId) {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(seconds: 60), link.close);
  ref.onDispose(timer.cancel);
  return ref.watch(summerCenterRepositoryProvider).watchCenter(centerId);
});
