import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/summer_level.dart';
import 'summer_center_provider.dart';

final summerLevelsByCenterProvider =
    StreamProvider.family.autoDispose<List<SummerLevel>, String>((ref, centerId) {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(seconds: 60), link.close);
  ref.onDispose(timer.cancel);
  return ref.watch(summerCenterRepositoryProvider).watchLevelsByCenter(centerId);
});

final activeSummerLevelsByCenterProvider =
    Provider.family.autoDispose<List<SummerLevel>, String>((ref, centerId) {
  final levelsAsync = ref.watch(summerLevelsByCenterProvider(centerId));
  return levelsAsync.when(
    data: (levels) => levels.where((l) => l.isActive).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});
