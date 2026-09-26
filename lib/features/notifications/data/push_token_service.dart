import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة تسجيل/تحديث توكن FCM (Push Notifications) الخاص بكل معلمة/مشرفة،
/// على أندرويد والويب. لا علاقة لها بمحتوى الإشعارات نفسه (ذلك في
/// [NotificationService]) — مسؤوليتها فقط: طلب الإذن، جلب التوكن،
/// حفظه/تحديثه في Firestore، وتنظيف التوكنات القديمة عند تغيّرها.
///
/// بنية التخزين: `users/{uid}/fcmTokens/{token}` (مجموعة فرعية، وليس حقلاً
/// واحداً على وثيقة المستخدم) — تدعم عدة أجهزة لنفس المستخدمة، وتسمح بحذف
/// توكن واحد فاسد بمفرده دون التأثير على بقية أجهزتها. هذا هو النمط
/// الموثَّق من Firebase نفسها لإدارة توكنات متعددة الأجهزة.
class PushTokenService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static String _lastTokenPrefsKey(String uid) => 'fcm_last_token_$uid';

  /// هل الإذن ممنوح حالياً (بصرف النظر عن استدعاء أي طلب)؟
  Future<bool> hasPermission() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// يُستدعى فقط من ضغطة زر حقيقية من المستخدمة (شرط إلزامي على iOS تحديداً).
  /// يطلب الإذن، وعند المنح يجلب التوكن ويحفظه. يُعيد true إن اكتمل كل شيء
  /// بنجاح (إذن + توكن محفوظ)، و false في أي حالة أخرى (رفض، أو نجاح الإذن
  /// لكن تعذّر الحصول على توكن — مثلاً VAPID key غير مُعدّة بعد على الويب).
  ///
  /// [webVapidKey] مطلوب فقط على الويب (Web Push certificate من Firebase
  /// Console ← الإعدادات ← Cloud Messaging ← Web Push certificates). إن
  /// تُرك فارغاً على الويب، يُتخطّى جلب التوكن بأمان بدل رمي استثناء —
  /// أندرويد لا يتأثر إطلاقاً بهذه القيمة.
  Future<bool> requestPermissionAndRegister({
    required String uid,
    String? webVapidKey,
  }) async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!granted) return false;

    if (kIsWeb && (webVapidKey == null || webVapidKey.isEmpty)) {
      // الإذن مُنح لكن لا يمكن إتمام التسجيل بأمان بدون VAPID key حقيقي.
      return false;
    }

    final token = await _messaging.getToken(
      vapidKey: kIsWeb ? webVapidKey : null,
    );
    if (token == null) return false;

    await _saveToken(uid, token);
    _listenForRefresh(uid);
    return true;
  }

  /// يُستدعى عند فتح التطبيق لمستخدمة سبق أن منحت الإذن في جلسة سابقة —
  /// فقط يُعيد ربط مستمع تحديث التوكن (لا يطلب إذناً جديداً ولا يعرض أي
  /// نافذة نظام، لأن الإذن ممنوح أصلاً).
  Future<void> resumeTokenSyncIfAlreadyGranted(String uid) async {
    if (!await hasPermission()) return;
    _listenForRefresh(uid);

    // نتأكد أن التوكن الحالي محفوظ فعلاً (يغطي حالة: مُنح الإذن سابقاً على
    // جهاز لم يُشغَّل عليه هذا الكود من قبل، أو تغيّر التوكن أثناء إغلاق
    // التطبيق تماماً فلم يلتقطه onTokenRefresh).
    final webKey = kIsWeb ? await _cachedWebVapidKey() : null;
    if (kIsWeb && (webKey == null || webKey.isEmpty)) return;
    final token = await _messaging.getToken(vapidKey: kIsWeb ? webKey : null);
    if (token != null) await _saveToken(uid, token);
  }

  StreamSubscription<String>? _refreshSub;

  void _listenForRefresh(String uid) {
    _refreshSub?.cancel();
    _refreshSub = _messaging.onTokenRefresh.listen((newToken) {
      _saveToken(uid, newToken);
    });
  }

  Future<void> _saveToken(String uid, String token) async {
    final prefs = await SharedPreferences.getInstance();
    final oldToken = prefs.getString(_lastTokenPrefsKey(uid));

    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('fcmTokens')
        .doc(token);

    final existing = await docRef.get();
    if (existing.exists) {
      await docRef.update({
        'lastSeenAt': FieldValue.serverTimestamp(),
        'platform': _platformName(),
      });
    } else {
      await docRef.set({
        'token': token,
        'platform': _platformName(),
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      });
    }

    // تنظيف التوكن القديم لنفس الجهاز إن تغيّر (تفادي تراكم توكنات فاسدة).
    if (oldToken != null && oldToken != token) {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('fcmTokens')
          .doc(oldToken)
          .delete()
          .catchError((_) {});
    }
    await prefs.setString(_lastTokenPrefsKey(uid), token);
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }

  /// يُستدعى عند تسجيل الخروج — يوقف وصول Push لهذا الجهاز بمجرد خروج
  /// المستخدمة، ويحذف مستند التوكن من Firestore.
  Future<void> deleteCurrentTokenOnSignOut(String uid) async {
    try {
      await _refreshSub?.cancel();
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_lastTokenPrefsKey(uid));
      await _messaging.deleteToken();
      if (token != null) {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('fcmTokens')
            .doc(token)
            .delete();
        await prefs.remove(_lastTokenPrefsKey(uid));
      }
    } catch (_) {
      // فشل تنظيف التوكن لا يجب أن يمنع تسجيل الخروج نفسه.
    }
  }

  // مفتاح Web Push (VAPID) — يُقرأ من Firestore بدل تضمينه في الكود مباشرة،
  // حتى تتمكن المشرفة/المطوّرة من إضافته أو تغييره لاحقاً بلا حاجة لبناء
  // نسخة جديدة من التطبيق. يُخزَّن مرة واحدة في app_config/push (مجموعة
  // app_config الموجودة أصلاً في قواعد الأمان، قراءتها عامة `allow read: if true`).
  Future<String?> _cachedWebVapidKey() async {
    try {
      final doc =
          await _firestore.collection('app_config').doc('push').get();
      return doc.data()?['webVapidKey'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<String?> getWebVapidKey() => _cachedWebVapidKey();
}
