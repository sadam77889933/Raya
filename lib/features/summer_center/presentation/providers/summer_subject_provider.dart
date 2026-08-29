import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/summer_subject.dart';
import 'summer_center_provider.dart';

final summerSubjectsByCenterProvider =
    StreamProvider.family.autoDispose<List<SummerSubject>, String>((ref, centerId) {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(seconds: 60), link.close);
  ref.onDispose(timer.cancel);
  return ref.watch(summerCenterRepositoryProvider).watchSubjectsByCenter(centerId);
});

final activeSummerSubjectsByCenterProvider =
    Provider.family.autoDispose<List<SummerSubject>, String>((ref, centerId) {
  final subjectsAsync = ref.watch(summerSubjectsByCenterProvider(centerId));
  return subjectsAsync.when(
    data: (subjects) => subjects.where((s) => s.isActive).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});
