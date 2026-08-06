import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/entities/mosque.dart';
import '../domain/repositories/mosque_repository.dart';

class MosqueRepositoryImpl implements MosqueRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _collection = 'mosques';

  @override
  Stream<List<Mosque>> watchAll() {
    return _firestore
        .collection(_collection)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Mosque.fromJson(doc.id, doc.data()))
            .toList());
  }

  @override
  Future<void> add(String name) async {
    await _firestore.collection(_collection).add({
      'name': name.trim(),
      'isActive': true,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> setActive(String mosqueId, bool isActive) async {
    await _firestore
        .collection(_collection)
        .doc(mosqueId)
        .update({'isActive': isActive});
  }
}