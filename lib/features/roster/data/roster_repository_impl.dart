import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/entities/roster_student.dart';
import '../domain/repositories/roster_repository.dart';

/// تنفيذ فعلي لسجل الحلقة عبر Firestore
///
/// كل طالبة موثّقة بمستند مستقل ضمن مجموعة roster_students، مرتبطة
/// بحلقة تحفيظ واحدة عبر circleId (يماثل تماماً نمط SchoolRepositoryImpl
/// و TeachingCircleRepositoryImpl الموجودَين في features/mosques).
class RosterRepositoryImpl implements RosterRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _collection = 'roster_students';

  @override
  Stream<List<RosterStudent>> watchByCircle(String circleId) {
    return _firestore
        .collection(_collection)
        .where('circleId', isEqualTo: circleId)
        .snapshots()
        .map((snapshot) {
      final students = snapshot.docs
          .map((doc) =>
              RosterStudent.fromJson({...doc.data(), 'id': doc.id}))
          .toList();
      // ترتيب أبجدي على مستوى العميل، كما تفعل بقية المستودعات هنا
      students.sort((a, b) => a.name.compareTo(b.name));
      return students;
    });
  }

  @override
  Future<void> add(String name, String circleId) async {
    await _firestore.collection(_collection).add({
      'name': name.trim(),
      'circleId': circleId,
      'isActive': true,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> updateName(String studentId, String name) async {
    await _firestore
        .collection(_collection)
        .doc(studentId)
        .update({'name': name.trim()});
  }

  @override
  Future<void> setActive(String studentId, bool isActive) async {
    await _firestore
        .collection(_collection)
        .doc(studentId)
        .update({'isActive': isActive});
  }
}
