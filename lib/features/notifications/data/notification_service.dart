import 'dart:async';

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

  /// إشعارات المشرفات (تلقائية عند رفع تقرير) — مُصفّاة بمسجد إن وُجد.
  ///
  /// ملاحظة أداء: عند تمرير [restrictToMosqueId] (حالة مشرفة المسجد)،
  /// تُضاف `where('targetMosqueId', isEqualTo: ...)` في الاستعلام نفسه
  /// بدل تحميل إشعارات كل المساجد ثم تصفيتها في Dart. حالة المشرفة
  /// العامة (restrictToMosqueId == null) تبقى بلا فلترة عمداً، لأنها
  /// بحاجة فعلية لرؤية إشعارات كل المساجد.
  ///
  /// ملاحظة تقنية مهمة: نتعمَّد **عدم** إضافة `.orderBy('createdAt')`
  /// على مستوى استعلام Firestore عندما يوجد شرطا تساوٍ معاً (audienceRole
  /// + targetMosqueId) — هذا التوليف الجديد (شرطا == مع ترتيب على حقل
  /// ثالث) قد يتطلب فهرساً مُركَّباً (Composite Index) غير موجود بعد في
  /// المشروع، وإضافته تلقائياً قد تُفشل الاستعلام فوراً بخطأ
  /// FAILED_PRECONDITION لدى مشرفة المسجد. لتفادي أي احتمال لكسر هذه
  /// الميزة، نُرتِّب النتيجة في Dart بعد الجلب بدل الاعتماد على ترتيب
  /// Firestore نفسه في هذه الحالة (فرق ضئيل، حجم البيانات هنا صغير أصلاً
  /// بعد التصفية بالمسجد).
  Stream<List<AppNotification>> watchSupervisorNotifications({
    String? restrictToMosqueId,
  }) {
    Query<Map<String, dynamic>> query =
        _firestore.collection(_collection).where('audienceRole', isEqualTo: 'supervisor');

    if (restrictToMosqueId == null) {
      query = query.orderBy('createdAt', descending: true);
      return query.snapshots().map((snapshot) => snapshot.docs
          .map((doc) => AppNotification.fromJson(doc.id, doc.data()))
          .toList());
    }

    query = query.where('targetMosqueId', isEqualTo: restrictToMosqueId);
    return query.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => AppNotification.fromJson(doc.id, doc.data()))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// إشعارات المعلمات (رسائل توجيهية) — لمسجد معيّن أو للكل.
  ///
  /// ملاحظة أداء: هذا النوع يحتمل بثاً عاماً (`targetMosqueId == null`)،
  /// لذلك لا يمكن تضييقه باستعلام `where` واحد فقط. بدل تحميل إشعارات
  /// كل المساجد ثم التصفية في Dart (كما كان سابقاً)، نُشغّل استعلامَين
  /// مُصغَّرين فقط (مسجدي + البث العام) ونُدمج نتيجتيهما — كل استعلام
  /// يبقى Stream حيّ (`snapshots()`) فلا نفقد التحديث اللحظي.
  Stream<List<AppNotification>> watchTeacherNotifications({
    required String mosqueId,
  }) {
    final ownMosqueStream = _firestore
        .collection(_collection)
        .where('audienceRole', isEqualTo: 'teacher')
        .where('targetMosqueId', isEqualTo: mosqueId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppNotification.fromJson(doc.id, doc.data()))
            .toList());

    final broadcastStream = _firestore
        .collection(_collection)
        .where('audienceRole', isEqualTo: 'teacher')
        // ملاحظة مهمة: .where('targetMosqueId', isEqualTo: null) لا يعمل!
        // حزمة cloud_firestore تتحقق داخلياً من `if (isEqualTo != null)`
        // قبل إضافة الشرط، فتمرير null صريح يُعامَل كعدم تمرير أي شرط
        // إطلاقاً (يُرجع كل المستندات بلا فلترة). الطريقة الصحيحة لمطابقة
        // القيمة null فعلياً هي معامل `isNull` المخصص لهذا الغرض.
        .where('targetMosqueId', isNull: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppNotification.fromJson(doc.id, doc.data()))
            .toList());

    return _mergeNotificationLists(ownMosqueStream, broadcastStream);
  }

  /// يدمج قائمتَي إشعارات حيّتين (Stream) في قائمة واحدة مُرتَّبة، مع
  /// إعادة الإصدار عند تحديث أي من المصدرَين — بدون أي اعتماد على حزمة
  /// خارجية (لا rxdart ولا async ككائن Stream مساعد)، فقط dart:async.
  Stream<List<AppNotification>> _mergeNotificationLists(
    Stream<List<AppNotification>> a,
    Stream<List<AppNotification>> b,
  ) {
    late StreamController<List<AppNotification>> controller;
    List<AppNotification>? latestA;
    List<AppNotification>? latestB;
    StreamSubscription<List<AppNotification>>? subA;
    StreamSubscription<List<AppNotification>>? subB;

    void emitIfReady() {
      final la = latestA;
      final lb = latestB;
      if (la == null || lb == null) return;
      final combined = [...la, ...lb]
        ..sort((x, y) => y.createdAt.compareTo(x.createdAt));
      controller.add(combined);
    }

    controller = StreamController<List<AppNotification>>.broadcast(
      onListen: () {
        subA = a.listen((v) {
          latestA = v;
          emitIfReady();
        }, onError: controller.addError);
        subB = b.listen((v) {
          latestB = v;
          emitIfReady();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await subA?.cancel();
        await subB?.cancel();
      },
    );
    return controller.stream;
  }

  Future<void> markAsRead(String notificationId, String uid) async {
    await _firestore.collection(_collection).doc(notificationId).update({
      'readBy': FieldValue.arrayUnion([uid]),
    });
  }
}