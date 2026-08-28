import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/quran_constants.dart';
import '../domain/entities/student_transfer.dart';
import '../domain/repositories/student_transfer_repository.dart';

class StudentTransferRepositoryImpl implements StudentTransferRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const _transfersCollection = 'student_transfers';
  static const _rosterCollection = 'roster_students';

  @override
  Future<void> transferStudent({
    required String studentId,
    required String studentName,
    required String fromMosqueId,
    required String fromMosqueName,
    required String fromSchoolId,
    required String fromSchoolName,
    required String fromCircleId,
    required String fromCircleName,
    required String toMosqueId,
    required String toMosqueName,
    required String toSchoolId,
    required String toSchoolName,
    required String toCircleId,
    required String toCircleName,
    required String transferHijriMonth,
    required String transferHijriYear,
    required String performedByUid,
    required String performedByName,
    String reason = '',
  }) async {
    final batch = _firestore.batch();

    // (أ) تحديث الحلقة الحالية للطالبة — هذا وحده هو ما يحدّد في أي حلقة
    // ستظهر عند إنشاء أي تقرير جديد من الآن فصاعداً. لا يمسّ أي تقرير
    // موجود مسبقاً (انظر توثيق StudentTransferRepository).
    batch.update(
      _firestore.collection(_rosterCollection).doc(studentId),
      {'circleId': toCircleId},
    );

    // (ب) سجل تاريخي مستقل لعملية النقل نفسها.
    final transferRef = _firestore.collection(_transfersCollection).doc();
    batch.set(transferRef, {
      'studentId': studentId,
      'studentName': studentName,
      'fromMosqueId': fromMosqueId,
      'fromMosqueName': fromMosqueName,
      'fromSchoolId': fromSchoolId,
      'fromSchoolName': fromSchoolName,
      'fromCircleId': fromCircleId,
      'fromCircleName': fromCircleName,
      'toMosqueId': toMosqueId,
      'toMosqueName': toMosqueName,
      'toSchoolId': toSchoolId,
      'toSchoolName': toSchoolName,
      'toCircleId': toCircleId,
      'toCircleName': toCircleName,
      'transferHijriMonth': transferHijriMonth,
      'transferHijriYear': transferHijriYear,
      'transferPeriodKey':
          QuranConstants.hijriPeriodKey(transferHijriMonth, transferHijriYear),
      'performedAt': DateTime.now().toIso8601String(),
      'performedByUid': performedByUid,
      'performedByName': performedByName,
      'reason': reason.trim(),
    });

    // نفّذي العمليتين معاً أو لا شيء إطلاقاً — لا يجوز أن يُحدَّث circleId
    // بدون أن يُكتَب سجل يوثّق ذلك.
    await batch.commit();
  }

  @override
  Stream<List<StudentTransfer>> watchByMosque(String mosqueId) {
    // فلترة من جهة السيرفر بحقل واحد (بدون orderBy مركّب يحتاج فهرساً
    // إضافياً في Firestore) — الترتيب يتم في الذاكرة بعد الجلب، بنفس
    // الأسلوب اليم المُتَّبع فعلاً في notification_service.dart.
    return _firestore
        .collection(_transfersCollection)
        .where('fromMosqueId', isEqualTo: mosqueId)
        .snapshots()
        .map(_sortedFromSnapshot);
  }

  @override
  Stream<List<StudentTransfer>> watchAll() {
    return _firestore
        .collection(_transfersCollection)
        .snapshots()
        .map(_sortedFromSnapshot);
  }

  List<StudentTransfer> _sortedFromSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final list = snapshot.docs
        .map((doc) => StudentTransfer.fromJson(doc.id, doc.data()))
        .toList();
    list.sort((a, b) => b.performedAt.compareTo(a.performedAt));
    return list;
  }
}
