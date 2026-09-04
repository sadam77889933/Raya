import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/entities/certificate_batch.dart';
import '../domain/repositories/certificate_repository.dart';

/// تنفيذ فعلي عبر Firestore — مجموعة certificate_batches، مستند واحد لكل
/// عملية إنشاء دفعة شهادات (لا مستند لكل شهادة)، بنفس نمط بقية مستودعات
/// المشروع (RosterRepositoryImpl، SchoolRepositoryImpl...).
class CertificateRepositoryImpl implements CertificateRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _collection = 'certificate_batches';

  @override
  Stream<List<CertificateBatch>> watchByMosque(String mosqueId,
      {int limit = 20}) {
    return _firestore
        .collection(_collection)
        .where('mosqueId', isEqualTo: mosqueId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CertificateBatch.fromJson(doc.id, doc.data()))
            .toList());
  }

  @override
  Stream<List<CertificateBatch>> watchAll({int limit = 20}) {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CertificateBatch.fromJson(doc.id, doc.data()))
            .toList());
  }

  @override
  Future<void> create(CertificateBatch batch) async {
    await _firestore.collection(_collection).add(batch.toJson());
  }
}
