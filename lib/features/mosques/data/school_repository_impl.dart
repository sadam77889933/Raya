import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/entities/school.dart';

class SchoolRepositoryImpl {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _collection = 'schools';

  Stream<List<School>> watchAll() {
    return _firestore
        .collection(_collection)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => School.fromJson(doc.id, doc.data()))
            .toList());
  }

  Stream<List<School>> watchByMosque(String mosqueId) {
    return _firestore
        .collection(_collection)
        .where('mosqueId', isEqualTo: mosqueId)
        .snapshots()
        .map((snapshot) {
      final schools = snapshot.docs
          .map((doc) => School.fromJson(doc.id, doc.data()))
          .toList();
      schools.sort((a, b) => a.name.compareTo(b.name));
      return schools;
    });
  }

  Future<void> add(String name, String mosqueId) async {
    await _firestore.collection(_collection).add({
      'name': name.trim(),
      'mosqueId': mosqueId,
      'isActive': true,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateName(String schoolId, String name) async {
    await _firestore
        .collection(_collection)
        .doc(schoolId)
        .update({'name': name.trim()});
  }

  Future<void> setActive(String schoolId, bool isActive) async {
    await _firestore
        .collection(_collection)
        .doc(schoolId)
        .update({'isActive': isActive});
  }
}
