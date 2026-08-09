import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/entities/app_notification.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _collection = 'notifications';

  /// إشعار تلقائي عند رفع معلمة تقريراً — يصل للمشرفات
  Future<void> notifyReportCreated({
    required String teacherName,
    required String circleName,
    required String mosqueId,
  }) async {
    await _firestore.collection(_collection).add({
      'type': 'report_created',
      'audienceRole': 'supervisor',
      'targetMosqueId': mosqueId,
      'title': 'تقرير جديد مرفوع',
      'body': 'قامت $teacherName برفع تقرير حلقة "$circleName"',
      'senderName': teacherName,
      'createdAt': DateTime.now().toIso8601String(),
      'readBy': <String>[],
    });
  }

  /// رسالة يدوية من مشرفة لمعلمات (مسجد معيّن أو الكل)
  Future<void> sendCustomMessage({
    required String title,
    required String body,
    required String senderName,
    String? targetMosqueId,
  }) async {
    await _firestore.collection(_collection).add({
      'type': 'custom_message',
      'audienceRole': 'teacher',
      'targetMosqueId': targetMosqueId,
      'title': title,
      'body': body,
      'senderName': senderName,
      'createdAt': DateTime.now().toIso8601String(),
      'readBy': <String>[],
    });
  }

  /// إشعارات المشرفات (تلقائية عند رفع تقرير) — مُصفّاة بمسجد إن وُجد
  Stream<List<AppNotification>> watchSupervisorNotifications({
    String? restrictToMosqueId,
  }) {
    Query query = _firestore
        .collection(_collection)
        .where('audienceRole', isEqualTo: 'supervisor');

    return query.orderBy('createdAt', descending: true).snapshots().map(
        (snapshot) => snapshot.docs
            .map((doc) => AppNotification.fromJson(
                doc.id, doc.data() as Map<String, dynamic>))
            .where((n) =>
                restrictToMosqueId == null ||
                n.targetMosqueId == restrictToMosqueId)
            .toList());
  }

  /// إشعارات المعلمات (رسائل توجيهية) — لمسجد معيّن أو للكل
  Stream<List<AppNotification>> watchTeacherNotifications({
    required String mosqueId,
  }) {
    return _firestore
        .collection(_collection)
        .where('audienceRole', isEqualTo: 'teacher')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppNotification.fromJson(doc.id, doc.data()))
            .where((n) =>
                n.targetMosqueId == null || n.targetMosqueId == mosqueId)
            .toList());
  }

  Future<void> markAsRead(String notificationId, String uid) async {
    await _firestore.collection(_collection).doc(notificationId).update({
      'readBy': FieldValue.arrayUnion([uid]),
    });
  }
}