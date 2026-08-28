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

  /// إشعارات نقل طالبة بين حلقتين — تُكتب معاً بدفعة واحدة (batch) لتفادي
  /// عدة رحلات شبكة منفصلة، لكن كتابتها ليست جزءاً من معاملة النقل الذرّية
  /// نفسها (`StudentTransferRepositoryImpl.transferStudent`)؛ استدعاؤها من
  /// الشاشة بعد نجاح النقل، ضمن try/catch مستقل خاص بها — فشل الإشعار لا
  /// يجوز أن يُظهر النقل نفسه كفاشل ولا أن يعيد أي شيء، بنفس مبدأ
  /// [notifyReportCreated] عند رفع تقرير.
  ///
  /// التوجيه دقيق لمعلمتين تحديداً (وليس بثاً لعموم معلمات المسجد):
  /// - [fromTeacherUid]: معلمة الحلقة السابقة (تُتجاهَل إن كانت null، أي لا
  ///   توجد معلمة مرتبطة بالحلقة حالياً).
  /// - [toTeacherUid]: معلمة الحلقة الجديدة (تُتجاهَل بنفس الشرط، وأيضاً إن
  ///   كانت نفس معلمة المصدر فلا نُكرِّر لها نفس الإشعار مرتين).
  /// والمشرف العام حصراً (بدون أي مشرفة مسجد) عبر `targetMosqueId: null` —
  /// انظر التوثيق في [watchSupervisorNotifications] لماذا هذا يصل فعلاً
  /// للمشرف العام فقط.
  Future<void> notifyStudentTransfer({
    required String studentName,
    required String performedByName,
    required String fromMosqueId,
    required String fromMosqueName,
    required String fromCircleName,
    required String toMosqueId,
    required String toMosqueName,
    required String toCircleName,
    required String transferHijriMonth,
    required String transferHijriYear,
    String? fromTeacherUid,
    String? toTeacherUid,
  }) async {
    final batch = _firestore.batch();
    final whenText = '$transferHijriMonth ${transferHijriYear}هـ';
    final now = DateTime.now().toIso8601String();

    if (fromTeacherUid != null && fromTeacherUid.isNotEmpty) {
      final ref = _firestore.collection(_collection).doc();
      batch.set(ref, {
        'type': 'student_transfer',
        'audienceRole': 'teacher',
        'targetMosqueId': fromMosqueId,
        'recipientUid': fromTeacherUid,
        'title': 'انتقال طالبة من حلقتك',
        'body':
            'انتقلت الطالبة "$studentName" من حلقتك "$fromCircleName" إلى حلقة "$toCircleName" – $toMosqueName، ابتداءً من $whenText',
        'senderName': performedByName,
        'createdAt': now,
        'readBy': <String>[],
      });
    }

    if (toTeacherUid != null &&
        toTeacherUid.isNotEmpty &&
        toTeacherUid != fromTeacherUid) {
      final ref = _firestore.collection(_collection).doc();
      batch.set(ref, {
        'type': 'student_transfer',
        'audienceRole': 'teacher',
        'targetMosqueId': toMosqueId,
        'recipientUid': toTeacherUid,
        'title': 'انضمام طالبة إلى حلقتك',
        'body':
            'انضمت إليك الطالبة "$studentName" من حلقة "$fromCircleName" – $fromMosqueName، ابتداءً من $whenText',
        'senderName': performedByName,
        'createdAt': now,
        'readBy': <String>[],
      });
    }

    final supervisorRef = _firestore.collection(_collection).doc();
    batch.set(supervisorRef, {
      'type': 'student_transfer',
      'audienceRole': 'supervisor',
      'targetMosqueId': null,
      'title': 'نقل طالبة بين الحلقات',
      'body':
          'نقلت $performedByName الطالبة "$studentName" من "$fromCircleName – $fromMosqueName" إلى "$toCircleName – $toMosqueName" ابتداءً من $whenText',
      'senderName': performedByName,
      'createdAt': now,
      'readBy': <String>[],
    });

    await batch.commit();
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

  /// إشعارات المعلمة — رسائل توجيهية لمسجدها + بث عام + إشعارات نقل طالبة
  /// موجَّهة لها شخصياً (عبر `recipientUid`، بغض النظر عن مسجدها الحالي —
  /// مهم لحالة نقل طالبة إليها من مسجد آخر).
  ///
  /// ملاحظة أداء: هذا النوع يحتمل بثاً عاماً (`targetMosqueId == null`)،
  /// لذلك لا يمكن تضييقه باستعلام `where` واحد فقط. بدل تحميل إشعارات
  /// كل المساجد ثم التصفية في Dart (كما كان سابقاً)، نُشغّل ثلاثة
  /// استعلامات مُصغَّرة فقط (مسجدي + البث العام + الموجَّه لي شخصياً)
  /// ونُدمج نتائجها — كل استعلام يبقى Stream حيّ (`snapshots()`) فلا نفقد
  /// التحديث اللحظي، وكلاهما بشرطَي مساواة فقط بلا `orderBy` مركّب فيتفادى
  /// أي فهرس إضافي (الترتيب يتم في الذاكرة بعد الدمج).
  Stream<List<AppNotification>> watchTeacherNotifications({
    required String mosqueId,
    required String uid,
  }) {
    // ملاحظة حرجة: نُصفّي هنا في Dart بعد الجلب (بلا استعلام Firestore
    // إضافي، فلا قراءات زائدة) لاستبعاد أي مستند `recipientUid` فيه محدَّد
    // لشخص آخر غيري. سبب وجود هذا الشرط: إشعار نقل طالبة موجَّه شخصياً
    // لمعلمة بعينها (`recipientUid`) لا يزال يحمل `targetMosqueId` الحقيقي
    // لمسجدها (لغرض توثيقي)، فبدون هذا الاستبعاد كان سيُطابق استعلام
    // "إشعارات مسجدي" لكل معلمات نفس المسجد، وليس فقط للمعلمة المقصودة —
    // هذا بالضبط ما كان يجعل الإشعار "يصل لكل المعلمات" بدل معلمة واحدة.
    final ownMosqueStream = _firestore
        .collection(_collection)
        .where('audienceRole', isEqualTo: 'teacher')
        .where('targetMosqueId', isEqualTo: mosqueId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppNotification.fromJson(doc.id, doc.data()))
            .where((n) => n.recipientUid == null || n.recipientUid == uid)
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
            .where((n) => n.recipientUid == null || n.recipientUid == uid)
            .toList());

    final personalStream = _firestore
        .collection(_collection)
        .where('audienceRole', isEqualTo: 'teacher')
        .where('recipientUid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AppNotification.fromJson(doc.id, doc.data()))
            .toList());

    return _mergeNotificationLists(
      _mergeNotificationLists(ownMosqueStream, broadcastStream),
      personalStream,
    );
  }

  /// يدمج قائمتَي إشعارات حيّتين (Stream) في قائمة واحدة مُرتَّبة، مع
  /// إعادة الإصدار عند تحديث أي من المصدرَين — بدون أي اعتماد على حزمة
  /// خارجية (لا rxdart ولا async ككائن Stream مساعد)، فقط dart:async.
  ///
  /// يُزيل أيضاً أي تكرار بمعرّف المستند نفسه (`id`) — ضروري الآن لأن
  /// [watchTeacherNotifications] تدمج 3 مصادر قد تتقاطع فعلياً: إشعار نقل
  /// طالبة موجَّه شخصياً (`recipientUid`) لمعلمة، مع `targetMosqueId` يساوي
  /// مسجدها نفسه، يُطابق شرط `ownMosqueStream` أيضاً — فبدون هذا الدمج
  /// كان سيظهر مكرَّراً مرتين في قائمتها.
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
      final byId = <String, AppNotification>{};
      for (final n in [...la, ...lb]) {
        byId[n.id] = n;
      }
      final combined = byId.values.toList()
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