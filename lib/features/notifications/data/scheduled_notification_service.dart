import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hijri/hijri_calendar.dart';
import '../domain/entities/scheduled_notification.dart';
import 'notification_service.dart';

class ScheduledNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _collection = 'scheduled_notifications';
  final NotificationService _notificationService = NotificationService();

  /// إنشاء رسالة مجدولة جديدة (تستخدمها المشرفة)
  Future<void> create({
    required String title,
    required String body,
    required int hijriDayOfMonth,
    required String senderName,
    String? targetMosqueId,
  }) async {
    await _firestore.collection(_collection).add({
      'title': title,
      'body': body,
      'hijriDayOfMonth': hijriDayOfMonth,
      'targetMosqueId': targetMosqueId,
      'senderName': senderName,
      'isActive': true,
      'lastSentHijriMonth': null,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// جلب كل الرسائل المجدولة (لعرضها للمشرفة)
  Stream<List<ScheduledNotification>> watchAll({String? restrictToMosqueId}) {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                ScheduledNotification.fromJson(doc.id, doc.data()))
            .where((s) =>
                restrictToMosqueId == null ||
                s.targetMosqueId == restrictToMosqueId)
            .toList());
  }

  Future<void> setActive(String id, bool isActive) async {
    await _firestore.collection(_collection).doc(id).update({
      'isActive': isActive,
    });
  }

  Future<void> delete(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  /// يُستدعى عند فتح التطبيق — يفحص كل الرسائل المجدولة النشطة
  /// ويُرسل ما حان وقته، مرة واحدة فقط لكل شهر هجري
  Future<void> checkAndSendDueNotifications() async {
    try {
      final today = HijriCalendar.now();
      final snapshot = await _firestore.collection(_collection).get();

      for (final doc in snapshot.docs) {
        final scheduled =
            ScheduledNotification.fromJson(doc.id, doc.data());

        if (!scheduled.shouldSendNow(today)) continue;

        // نُرسل الإشعار الفعلي للمعلمات
        await _notificationService.sendCustomMessage(
          title: scheduled.title,
          body: scheduled.body,
          senderName: scheduled.senderName,
          targetMosqueId: scheduled.targetMosqueId,
        );

        // نُسجّل أنها أُرسلت هذا الشهر الهجري لمنع التكرار
        final currentHijriMonthKey =
            '${today.hYear}-${today.hMonth.toString().padLeft(2, '0')}';
        await _firestore.collection(_collection).doc(doc.id).update({
          'lastSentHijriMonth': currentHijriMonthKey,
        });
      }
    } catch (_) {
      // فشل الفحص لا يجب أن يعطّل فتح التطبيق
    }
  }
}