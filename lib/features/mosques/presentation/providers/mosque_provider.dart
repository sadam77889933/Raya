import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/mosque_repository_impl.dart';
import '../../domain/entities/mosque.dart';
import '../../domain/repositories/mosque_repository.dart';

final mosqueRepositoryProvider = Provider<MosqueRepository>(
  (ref) => MosqueRepositoryImpl(),
);

final mosquesStreamProvider = StreamProvider<List<Mosque>>((ref) {
  return ref.watch(mosqueRepositoryProvider).watchAll();
});

final activeMosquesProvider = Provider<List<Mosque>>((ref) {
  final mosquesAsync = ref.watch(mosquesStreamProvider);
  return mosquesAsync.when(
    data: (mosques) => mosques.where((m) => m.isActive).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});