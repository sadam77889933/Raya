import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/entities/circle_report.dart';

/// رفع التقارير الشهرية إلى Firestore
///
/// القرار المعماري: لا نُنفّذ ReportRepository الأصلي حرفياً هنا
/// (الذي صُمم لتخزين محلي مستقبلي)، بل نبني خدمة مستقلة مخصصة
/// للرفع السحابي، لأن شكل البيانات المطلوب (ربط بالمعلمة والمسجد)
/// يختلف عن التخزين المحلي البسيط.
class FirestoreReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _collection = 'reports';

  /// رفع تقرير جديد للسحابة
  Future<void> uploadReport(
    CircleReport report, {
    required String teacherId,
    required String mosqueId,
  }) async {
    await _firestore.collection(_collection).add(
          report.toFirestoreJson(
            teacherId: teacherId,
            mosqueId: mosqueId,
          ),
        );
  }

  /// جلب كل تقارير معلمة معينة (لاستخدام مستقبلي: "تقاريري السابقة")
  Stream<List<Map<String, dynamic>>> watchTeacherReports(String teacherId) {
    return _firestore
        .collection(_collection)
        .where('teacherId', isEqualTo: teacherId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }

  /// جلب كل التقارير (لشاشة المشرفة القادمة)
  Stream<List<Map<String, dynamic>>> watchAllReports() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }
}