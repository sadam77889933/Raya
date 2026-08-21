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

  @override
  Future<void> updateBranding(
    String mosqueId, {
    String? stampBase64,
    bool removeStamp = false,
    String? supervisorName,
  }) async {
    final data = <String, dynamic>{};
    if (removeStamp) {
      data['stampBase64'] = FieldValue.delete();
    } else if (stampBase64 != null) {
      data['stampBase64'] = stampBase64;
    }
    if (supervisorName != null) {
      data['supervisorName'] = supervisorName;
    }
    if (data.isEmpty) return;
    await _firestore.collection(_collection).doc(mosqueId).update(data);
  }

  @override
  Future<void> updateHeaderSettings(
    String mosqueId, {
    String? rightHeaderText,
    String? leftHeaderText,
    String? headerLogoBase64,
    bool removeHeaderLogo = false,
  }) async {
    final data = <String, dynamic>{};
    if (rightHeaderText != null) {
      data['rightHeaderText'] = rightHeaderText;
    }
    if (leftHeaderText != null) {
      data['leftHeaderText'] = leftHeaderText;
    }
    if (removeHeaderLogo) {
      data['headerLogoBase64'] = FieldValue.delete();
    } else if (headerLogoBase64 != null) {
      data['headerLogoBase64'] = headerLogoBase64;
    }
    if (data.isEmpty) return;
    await _firestore.collection(_collection).doc(mosqueId).update(data);
  }
}