import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/entities/certificate_template_layout.dart';
import '../domain/repositories/certificate_template_layout_repository.dart';

/// تنفيذ فعلي عبر Firestore — مجموعة `certificate_templates`، مستند واحد
/// فقط لكل (مسجد، قالب أساسي) بمعرّف حتمي `<mosqueId>_<baseTemplateId>`
/// (القسم ١٣ من تصميم الميزة): قراءة/كتابة مباشرة بلا استعلام، لأن كل
/// مسجد له تخطيط واحد كحدّ أقصى لكل قالب أساسي.
class CertificateTemplateLayoutRepositoryImpl
    implements CertificateTemplateLayoutRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _collection = 'certificate_templates';

  String _docId(String mosqueId, String baseTemplateId) =>
      '${mosqueId}_$baseTemplateId';

  @override
  Stream<CertificateTemplateLayout?> watch(
      String mosqueId, String baseTemplateId) {
    return _firestore
        .collection(_collection)
        .doc(_docId(mosqueId, baseTemplateId))
        .snapshots()
        .map((doc) =>
            doc.exists ? CertificateTemplateLayout.fromJson(doc.data()!) : null);
  }

  @override
  Future<CertificateTemplateLayout?> get(
      String mosqueId, String baseTemplateId) async {
    final doc = await _firestore
        .collection(_collection)
        .doc(_docId(mosqueId, baseTemplateId))
        .get();
    if (!doc.exists) return null;
    return CertificateTemplateLayout.fromJson(doc.data()!);
  }

  @override
  Future<void> save(CertificateTemplateLayout layout) async {
    await _firestore
        .collection(_collection)
        .doc(layout.docId)
        .set(layout.toJson());
  }
}
