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

  /// تحديث بيانات تقرير محفوظ مسبقاً (تعديل طالبات موجودات أو إضافة طالبة جديدة)
  ///
  /// لا يُغيّر تاريخ الإنشاء الأصلي للتقرير (createdAt)، فقط يستبدل
  /// قائمة الطالبات وعددها.
  Future<void> updateReportStudents(
    String reportId,
    List<Map<String, dynamic>> students, {
    List<String>? companionCurriculums,
  }) async {
    await _firestore.collection(_collection).doc(reportId).update({
      'students': students,
      'studentsCount': students.length,
      if (companionCurriculums != null)
        'companionCurriculums': companionCurriculums,
    });
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

  /// جلب تقارير حلقة واحدة فقط ضمن فترة هجرية محددة — مُصفّاة من جهة
  /// السيرفر بـ `circleId` + `periodKey` بدل تحميل كل تقارير كل الحلقات
  /// ثم التصفية في Dart (كما في `watchAllReports()`). تُستخدم في التقرير
  /// الإحصائي، حيث اختيار الحلقة إلزامي دائماً قبل عرض أي بيانات.
  ///
  /// ملاحظة تقنية مهمة: بلا `.orderBy()` هنا عمداً — إضافته مع فلترة
  /// المساواة على `circleId` تتطلب فهرساً مُركَّباً إضافياً لا داعي له،
  /// خصوصاً أن لا شيء في `StatisticalReportAggregator` يعتمد على ترتيب
  /// ورود المستندات (يُعيد بناء كل نتائجه من الصفر عبر Map مُجمَّع).
  ///
  /// **يتطلب فهرساً مركّباً (composite index) في Firestore على
  /// (circleId, periodKey)** — إن لم يكن موجوداً بعد، ستفشل هذه
  /// الاستعلامات بخطأ `FAILED_PRECONDITION` يحوي رابطاً مباشراً لإنشاء
  /// الفهرس بضغطة واحدة في Firebase Console عند أول استخدام فعلي.
  ///
  /// أيضاً: التقارير القديمة التي رُفعت قبل إضافة حقل `periodKey` (قبل هذا
  /// التحديث) لن تظهر في نتيجة هذا الاستعلام إطلاقاً — Firestore يستثني
  /// أي مستند لا يملك الحقل المُستخدَم في فلتر مدى (`>=`/`<=`) تلقائياً.
  Stream<List<Map<String, dynamic>>> watchReportsByCircleAndPeriod({
    required String circleId,
    required int fromPeriodKey,
    required int toPeriodKey,
  }) {
    return _firestore
        .collection(_collection)
        .where('circleId', isEqualTo: circleId)
        .where('periodKey', isGreaterThanOrEqualTo: fromPeriodKey)
        .where('periodKey', isLessThanOrEqualTo: toPeriodKey)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }
}