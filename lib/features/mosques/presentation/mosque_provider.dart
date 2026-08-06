import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/mosque_repository_impl.dart';
import '../../domain/entities/mosque.dart';
import '../../domain/repositories/mosque_repository.dart';

final mosqueRepositoryProvider = Provider<MosqueRepository>(
  (ref) => MosqueRepositoryImpl(),
);

/// قائمة المساجد كـ Stream حيّة — تتحدث تلقائياً عند أي إضافة
final mosquesStreamProvider = StreamProvider<List<Mosque>>((ref) {
  return ref.watch(mosqueRepositoryProvider).watchAll();
});

/// المساجد النشطة فقط (للاستخدام في القوائم المنسدلة)
final activeMosquesProvider = Provider<List<Mosque>>((ref) {
  final mosquesAsync = ref.watch(mosquesStreamProvider);
  return mosquesAsync.when(
    data: (mosques) => mosques.where((m) => m.isActive).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});