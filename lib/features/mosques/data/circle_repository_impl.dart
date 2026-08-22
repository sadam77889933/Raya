import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/entities/teaching_circle.dart';

class TeachingCircleRepositoryImpl {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _collection = 'circles';

  Stream<List<TeachingCircle>> watchAll() {
    return _firestore
        .collection(_collection)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TeachingCircle.fromJson(doc.id, doc.data()))
            .toList());
  }

  Stream<List<TeachingCircle>> watchBySchool(String schoolId) {
    return _firestore
        .collection(_collection)
        .where('schoolId', isEqualTo: schoolId)
        .snapshots()
        .map((snapshot) {
      final circles = snapshot.docs
          .map((doc) => TeachingCircle.fromJson(doc.id, doc.data()))
          .toList();
      circles.sort((a, b) => a.name.compareTo(b.name));
      return circles;
    });
  }

  Future<void> add(
    String name,
    String schoolId, {
    String circleTime = TeachingCircle.defaultCircleTime,
  }) async {
    await _firestore.collection(_collection).add({
      'name': name.trim(),
      'schoolId': schoolId,
      'isActive': true,
      'createdAt': DateTime.now().toIso8601String(),
      'circleTime': circleTime,
    });
  }

  Future<void> updateName(String circleId, String name) async {
    await _firestore
        .collection(_collection)
        .doc(circleId)
        .update({'name': name.trim()});
  }

  /// تحديث وقت الحلقة اليومي (فجراً/صباحاً/ضحى/ظهراً/عصراً/مساءً/ليلاً).
  Future<void> updateCircleTime(String circleId, String circleTime) async {
    await _firestore
        .collection(_collection)
        .doc(circleId)
        .update({'circleTime': circleTime});
  }

  /// إعادة ربط الحلقة بدار/مدرسة أخرى (تصحيح خطأ عند الإضافة مثلاً)
  Future<void> updateSchoolId(String circleId, String schoolId) async {
    await _firestore
        .collection(_collection)
        .doc(circleId)
        .update({'schoolId': schoolId});
  }

  Future<void> setActive(String circleId, bool isActive) async {
    await _firestore
        .collection(_collection)
        .doc(circleId)
        .update({'isActive': isActive});
  }
}
