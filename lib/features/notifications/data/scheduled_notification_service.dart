import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/entities/scheduled_notification.dart';
import 'notification_service.dart';

class ScheduledNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _collection = 'scheduled_notifications';
  static const _lastCheckedPrefsKey = 'scheduled_notifications_last_checked_hijri_day';
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

  /// تعديل محتوى رسالة مجدولة موجودة (العنوان/النص/اليوم/المسجد المستهدَف).
  /// لا نُصفّر `lastSentHijriMonth` هنا عمداً — تعديل المحتوى لا يجب أن
  /// يتسبّب بإعادة إرسال فورية لرسالة أُرسلت بالفعل هذا الشهر الهجري.
  Future<void> update({
    required String id,
    required String title,
    required String body,
    required int hijriDayOfMonth,
    String? targetMosqueId,
  }) async {
    await _firestore.collection(_collection).doc(id).update({
      'title': title,
      'body': body,
      'hijriDayOfMonth': hijriDayOfMonth,
      'targetMosqueId': targetMosqueId,
    });
  }

  Future<void> delete(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  /// يُستدعى عند فتح التطبيق — يفحص كل الرسائل المجدولة النشطة
  /// ويُرسل ما حان وقته، مرة واحدة فقط لكل شهر هجري.
  ///
  /// تحسين أداء: هذا الفحص كان يقرأ كامل مجموعة `scheduled_notifications`
  /// (`.get()` بلا فلترة) في كل مرة يُفتح التطبيق فيها، لكل مستخدم على
  /// حدة (معلمة أو مشرفة) — أي أن N مستخدماً نشطاً يعني N قراءة كاملة
  /// للمجموعة في نفس اليوم، مع أن نتيجة الفحص لا تتغيّر إلا مرة واحدة
  /// يومياً بالفعل (لا يوجد سبب منطقي لتكراره). نُخزِّن هنا آخر يوم هجري
  /// تم فيه الفحص فعلياً على هذا الجهاز (عبر shared_preferences، وهي
  /// حزمة مضافة أصلاً في المشروع)، ونتخطى القراءة كاملة إن كان الفحص قد
  /// تم اليوم بالفعل على هذا الجهاز — يقلّل التكرار الناتج عن إغلاق/فتح
  /// التطبيق عدة مرات في نفس اليوم، وهو الجزء الذي يمكن حله من طرف
  /// العميل بلا أي تغيير في البنية أو ترقية خطة Firebase. (التخلص الكامل
  /// من تكرار القراءة بين مستخدمين مختلفين في نفس اليوم يحتاج معالجة من
  /// طرف الخادم — Cloud Function مجدولة — وهذا يتطلب خطة Blaze، فتُرك
  /// كخيار مستقبلي منفصل حسب ما اتفقنا عليه.)
  Future<void> checkAndSendDueNotifications() async {
    try {
      final today = HijriCalendar.now();
      final todayKey =
          '${today.hYear}-${today.hMonth.toString().padLeft(2, '0')}-${today.hDay.toString().padLeft(2, '0')}';

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_lastCheckedPrefsKey) == todayKey) {
        return; // فُحص هذا اليوم الهجري على هذا الجهاز بالفعل — لا حاجة لقراءة جديدة
      }

      final snapshot = await _firestore.collection(_collection).get();

      for (final doc in snapshot.docs) {
        final scheduled =
            ScheduledNotification.fromJson(doc.id, doc.data());

        final due = scheduled.shouldSendNow(today);
        if (!due) continue;

        // نُرسل الإشعار الفعلي للمعلمات — نُمرّر scheduledNotificationId
        // حتى تسمح قواعد أمان Firestore بإنشاء الإشعار حتى لو كانت صاحبة
        // الحساب التي فتحت التطبيق الآن معلمة وليست مشرفة (انظر
        // isFromActiveSchedule في firestore.rules)
        await _notificationService.sendCustomMessage(
          title: scheduled.title,
          body: scheduled.body,
          senderName: scheduled.senderName,
          targetMosqueId: scheduled.targetMosqueId,
          scheduledNotificationId: doc.id,
        );

        // نُسجّل أنها أُرسلت هذا الشهر الهجري لمنع التكرار
        final currentHijriMonthKey =
            '${today.hYear}-${today.hMonth.toString().padLeft(2, '0')}';
        await _firestore.collection(_collection).doc(doc.id).update({
          'lastSentHijriMonth': currentHijriMonthKey,
        });
      }

      // نُسجّل نجاح الفحص لهذا اليوم الهجري فقط بعد اكتماله فعلاً — إن
      // فشل الفحص (استثناء أعلاه) لا نُسجّل شيئاً، فيُعاد المحاولة كاملة
      // عند فتح التطبيق التالي بدل تفويت يوم كامل بصمت.
      await prefs.setString(_lastCheckedPrefsKey, todayKey);
    } catch (_) {
      // فشل الفحص لا يجب أن يعطّل فتح التطبيق
    }
  }
}