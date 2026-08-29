import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/entities/summer_assignment.dart';
import '../domain/entities/summer_center.dart';
import '../domain/entities/summer_level.dart';
import '../domain/entities/summer_subject.dart';
import '../domain/entities/summer_test.dart';
import '../domain/entities/summer_test_question.dart';

/// طبقة الوصول إلى بيانات المركز الصيفي — 6 مجموعات مسطّحة مستقلة تماماً
/// عن مجموعات نظام الحلقات المعتاد (schools, teaching_circles, reports,
/// roster_students)، كلها ببادئة `summer_` فيستحيل الخلط بينها.
///
/// كل الاستعلامات هنا تُصفّى من طرف السيرفر بـ.where() مباشرة (لا تحميل
/// كامل ثم فلترة في Dart)، ولا تُستخدم .orderBy() مركّبة مع .where() على
/// حقل مختلف (لتفادي الحاجة لفهرس مركّب فوري) — الفرز البسيط يتم في Dart
/// بعد الجلب، بنفس النهج المعتمَد في notification_service.dart.
class SummerCenterRepositoryImpl {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const _centersCollection = 'summer_centers';
  static const _levelsCollection = 'summer_levels';
  static const _subjectsCollection = 'summer_subjects';
  static const _assignmentsCollection = 'summer_assignments';
  static const _testsCollection = 'summer_tests';
  static const _questionsCollection = 'summer_test_questions';

  // ---------------------------------------------------------------------
  // المراكز الصيفية
  // ---------------------------------------------------------------------

  Stream<List<SummerCenter>> watchCentersByMosque(String mosqueId) {
    return _firestore
        .collection(_centersCollection)
        .where('mosqueId', isEqualTo: mosqueId)
        .snapshots()
        .map((snap) {
      final centers = snap.docs
          .map((d) => SummerCenter.fromJson(d.id, d.data()))
          .toList();
      centers.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return centers;
    });
  }

  Stream<SummerCenter?> watchCenter(String centerId) {
    return _firestore
        .collection(_centersCollection)
        .doc(centerId)
        .snapshots()
        .map((doc) =>
            doc.exists ? SummerCenter.fromJson(doc.id, doc.data()!) : null);
  }

  Future<String> addCenter({
    required String name,
    required String mosqueId,
    required String hijriYear,
    String? periodLabel,
  }) async {
    final ref = await _firestore.collection(_centersCollection).add({
      'name': name.trim(),
      'mosqueId': mosqueId,
      'hijriYear': hijriYear.trim(),
      if (periodLabel != null && periodLabel.trim().isNotEmpty)
        'periodLabel': periodLabel.trim(),
      'isActive': true,
      'testsEnabledForTeachers': true,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return ref.id;
  }

  Future<void> setCenterActive(String centerId, bool isActive) async {
    await _firestore
        .collection(_centersCollection)
        .doc(centerId)
        .update({'isActive': isActive});
  }

  Future<void> setTestsEnabled(String centerId, bool enabled) async {
    await _firestore
        .collection(_centersCollection)
        .doc(centerId)
        .update({'testsEnabledForTeachers': enabled});
  }

  // ---------------------------------------------------------------------
  // المستويات
  // ---------------------------------------------------------------------

  Stream<List<SummerLevel>> watchLevelsByCenter(String centerId) {
    return _firestore
        .collection(_levelsCollection)
        .where('centerId', isEqualTo: centerId)
        .snapshots()
        .map((snap) {
      final levels =
          snap.docs.map((d) => SummerLevel.fromJson(d.id, d.data())).toList();
      levels.sort((a, b) => a.order.compareTo(b.order));
      return levels;
    });
  }

  Future<void> addLevel(String centerId, String mosqueId, String name, int order) async {
    await _firestore.collection(_levelsCollection).add({
      'centerId': centerId,
      'mosqueId': mosqueId,
      'name': name.trim(),
      'order': order,
      'isActive': true,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateLevelName(String levelId, String name) async {
    await _firestore
        .collection(_levelsCollection)
        .doc(levelId)
        .update({'name': name.trim()});
  }

  Future<void> setLevelActive(String levelId, bool isActive) async {
    await _firestore
        .collection(_levelsCollection)
        .doc(levelId)
        .update({'isActive': isActive});
  }

  // ---------------------------------------------------------------------
  // المواد
  // ---------------------------------------------------------------------

  Stream<List<SummerSubject>> watchSubjectsByCenter(String centerId) {
    return _firestore
        .collection(_subjectsCollection)
        .where('centerId', isEqualTo: centerId)
        .snapshots()
        .map((snap) {
      final subjects = snap.docs
          .map((d) => SummerSubject.fromJson(d.id, d.data()))
          .toList();
      subjects.sort((a, b) => a.order.compareTo(b.order));
      return subjects;
    });
  }

  Future<void> addSubject(String centerId, String mosqueId, String name, int order) async {
    await _firestore.collection(_subjectsCollection).add({
      'centerId': centerId,
      'mosqueId': mosqueId,
      'name': name.trim(),
      'order': order,
      'isActive': true,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateSubjectName(String subjectId, String name) async {
    await _firestore
        .collection(_subjectsCollection)
        .doc(subjectId)
        .update({'name': name.trim()});
  }

  Future<void> setSubjectActive(String subjectId, bool isActive) async {
    await _firestore
        .collection(_subjectsCollection)
        .doc(subjectId)
        .update({'isActive': isActive});
  }

  // ---------------------------------------------------------------------
  // إسناد المعلمات
  // ---------------------------------------------------------------------

  /// كل إسنادات مركز صيفي واحد (لشاشة "توزيع المعلمات" عند المشرفة)
  Stream<List<SummerAssignment>> watchAssignmentsByCenter(String centerId) {
    return _firestore
        .collection(_assignmentsCollection)
        .where('centerId', isEqualTo: centerId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => SummerAssignment.fromJson(d.id, d.data())).toList());
  }

  /// إسنادات معلمة واحدة داخل مركز واحد (لشاشة "اختباراتي" عند المعلمة) —
  /// هذا الاستعلام هو كل ما تحتاجه شاشة المعلمة لمعرفة مستوياتها ومودها،
  /// بلا أي علاقة بحلقاتها أو assignedCircleIds.
  Stream<List<SummerAssignment>> watchAssignmentsByTeacher(
      String centerId, String teacherId) {
    return _firestore
        .collection(_assignmentsCollection)
        .where('centerId', isEqualTo: centerId)
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => SummerAssignment.fromJson(d.id, d.data())).toList());
  }

  /// إسناد معلمة لعدة (مستوى+مادة) دفعة واحدة من شاشة "إسناد جديد".
  /// كل عنصر في [pairs] خريطة بمفتاحين: 'levelId' و'subjectId'.
  /// يتجاهل أي زوج (مستوى+مادة) مُسنَد لها مسبقاً بالفعل (تُمرَّر
  /// [existingKeys] كمجموعة "levelId|subjectId" محسوبة من الإسنادات
  /// المحمَّلة أصلاً في الشاشة، فلا حاجة لقراءة إضافية للتحقق).
  Future<void> addAssignmentsBulk({
    required String centerId,
    required String mosqueId,
    required String teacherId,
    required String teacherName,
    required List<Map<String, String>> pairs,
    required Set<String> existingKeys,
  }) async {
    final batch = _firestore.batch();
    final now = DateTime.now().toIso8601String();
    for (final pair in pairs) {
      final levelId = pair['levelId']!;
      final subjectId = pair['subjectId']!;
      final key = '$levelId|$subjectId';
      if (existingKeys.contains(key)) continue;
      final ref = _firestore.collection(_assignmentsCollection).doc();
      batch.set(ref, {
        'centerId': centerId,
        'mosqueId': mosqueId,
        'levelId': levelId,
        'subjectId': subjectId,
        'teacherId': teacherId,
        'teacherName': teacherName,
        'createdAt': now,
      });
    }
    await batch.commit();
  }

  Future<void> deleteAssignment(String assignmentId) async {
    await _firestore.collection(_assignmentsCollection).doc(assignmentId).delete();
  }

  // ---------------------------------------------------------------------
  // الاختبارات
  // ---------------------------------------------------------------------

  /// اختبارات معلمة واحدة ضمن (مستوى+مادة) محدَّدين فقط — هذا الاستعلام
  /// المحدود هو ما تراه المعلمة في "قائمة اختباراتي"، فلا تُحمَّل أبداً
  /// اختبارات معلمات أخريات ولا مستويات/مواد أخرى.
  Stream<List<SummerTest>> watchTeacherTests({
    required String teacherId,
    required String levelId,
    required String subjectId,
  }) {
    return _firestore
        .collection(_testsCollection)
        .where('teacherId', isEqualTo: teacherId)
        .where('levelId', isEqualTo: levelId)
        .where('subjectId', isEqualTo: subjectId)
        .snapshots()
        .map((snap) {
      final tests =
          snap.docs.map((d) => SummerTest.fromJson(d.id, d.data())).toList();
      tests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return tests;
    });
  }

  /// اختبارات مركز صيفي كامل بفلاتر اختيارية (لشاشة المشرفة) — يُشترَط
  /// تمرير [centerId] دائماً (لا استعلام بلا نطاق مركز محدَّد على الإطلاق).
  Stream<List<SummerTest>> watchTestsFiltered({
    required String centerId,
    String? levelId,
    String? subjectId,
    String? teacherId,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection(_testsCollection)
        .where('centerId', isEqualTo: centerId);
    if (levelId != null) query = query.where('levelId', isEqualTo: levelId);
    if (subjectId != null) {
      query = query.where('subjectId', isEqualTo: subjectId);
    }
    if (teacherId != null) {
      query = query.where('teacherId', isEqualTo: teacherId);
    }
    return query.snapshots().map((snap) {
      final tests =
          snap.docs.map((d) => SummerTest.fromJson(d.id, d.data())).toList();
      tests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return tests;
    });
  }

  Stream<SummerTest?> watchTest(String testId) {
    return _firestore
        .collection(_testsCollection)
        .doc(testId)
        .snapshots()
        .map((doc) =>
            doc.exists ? SummerTest.fromJson(doc.id, doc.data()!) : null);
  }

  Future<String> addTest({
    required String centerId,
    required String mosqueId,
    required String levelId,
    required String subjectId,
    required String teacherId,
    required String teacherName,
    required String title,
    required String hijriMonth,
    required String hijriYear,
  }) async {
    final now = DateTime.now().toIso8601String();
    final ref = await _firestore.collection(_testsCollection).add({
      'centerId': centerId,
      'mosqueId': mosqueId,
      'levelId': levelId,
      'subjectId': subjectId,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'title': title.trim(),
      'hijriMonth': hijriMonth,
      'hijriYear': hijriYear,
      'questionsCount': 0,
      'auditLog': <Map<String, dynamic>>[],
      'createdAt': now,
      'updatedAt': now,
    });
    return ref.id;
  }

  Future<void> updateTestTitle(String testId, String title) async {
    await _firestore.collection(_testsCollection).doc(testId).update({
      'title': title.trim(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  // ---------------------------------------------------------------------
  // أسئلة الاختبار
  // ---------------------------------------------------------------------

  /// لا orderBy مركّب مع where(testId) لتفادي فهرس مركّب فوري — الفرز
  /// بحقل [SummerTestQuestion.order] يتم في Dart بعد الجلب.
  Stream<List<SummerTestQuestion>> watchQuestions(String testId) {
    return _firestore
        .collection(_questionsCollection)
        .where('testId', isEqualTo: testId)
        .snapshots()
        .map((snap) {
      final questions = snap.docs
          .map((d) => SummerTestQuestion.fromJson(d.id, d.data()))
          .toList();
      questions.sort((a, b) => a.order.compareTo(b.order));
      return questions;
    });
  }

  /// إضافة سؤال جديد + زيادة عدّاد الاختبار معاً في عملية واحدة ذرّية.
  Future<void> addQuestion({
    required String testId,
    required String type,
    required double order,
    required String questionText,
    required Map<String, dynamic> typeData,
  }) async {
    final batch = _firestore.batch();
    final qRef = _firestore.collection(_questionsCollection).doc();
    batch.set(qRef, {
      'testId': testId,
      'type': type,
      'order': order,
      'questionText': questionText.trim(),
      'typeData': typeData,
      'createdAt': DateTime.now().toIso8601String(),
    });
    batch.update(_firestore.collection(_testsCollection).doc(testId), {
      'questionsCount': FieldValue.increment(1),
      'updatedAt': DateTime.now().toIso8601String(),
    });
    await batch.commit();
  }

  /// تعديل سؤال — [auditedBy]/[auditedByName] غير null فقط عندما تكون
  /// من عدّلته مشرفة (مراجعة)، فيُسجَّل ذلك في auditLog ليظهر للمعلمة.
  /// تعديل المعلمة لسؤالها الخاص لا يُسجَّل (audited* تبقى null).
  Future<void> updateQuestion({
    required String testId,
    required String questionId,
    required String type,
    required String questionText,
    required Map<String, dynamic> typeData,
    String? auditedByUid,
    String? auditedByName,
  }) async {
    final batch = _firestore.batch();
    batch.update(
      _firestore.collection(_questionsCollection).doc(questionId),
      {
        'type': type,
        'questionText': questionText.trim(),
        'typeData': typeData,
      },
    );
    final testUpdate = <String, dynamic>{
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (auditedByUid != null && auditedByName != null) {
      testUpdate['auditLog'] = FieldValue.arrayUnion([
        {
          'action': 'edited',
          'questionSnapshot': questionText.trim(),
          'byUid': auditedByUid,
          'byName': auditedByName,
          'at': DateTime.now().toIso8601String(),
        }
      ]);
    }
    batch.update(_firestore.collection(_testsCollection).doc(testId), testUpdate);
    await batch.commit();
  }

  /// حذف سؤال + إنقاص عدّاد الاختبار، مع تسجيل من حذف ومتى دائماً
  /// (بعكس التعديل، الحذف يُسجَّل دوماً بغض النظر عن الفاعل).
  Future<void> deleteQuestion({
    required String testId,
    required String questionId,
    required String questionSnapshot,
    required String byUid,
    required String byName,
  }) async {
    final batch = _firestore.batch();
    batch.delete(_firestore.collection(_questionsCollection).doc(questionId));
    batch.update(_firestore.collection(_testsCollection).doc(testId), {
      'questionsCount': FieldValue.increment(-1),
      'updatedAt': DateTime.now().toIso8601String(),
      'auditLog': FieldValue.arrayUnion([
        {
          'action': 'deleted',
          'questionSnapshot': questionSnapshot,
          'byUid': byUid,
          'byName': byName,
          'at': DateTime.now().toIso8601String(),
        }
      ]),
    });
    await batch.commit();
  }

  /// تحديث ترتيب سؤال واحد فقط (نقل لأعلى/لأسفل) — تبديل حقل [order] مع
  /// جاره، بلا أي تعديل على بقية الأسئلة.
  Future<void> updateQuestionOrder(String questionId, double newOrder) async {
    await _firestore
        .collection(_questionsCollection)
        .doc(questionId)
        .update({'order': newOrder});
  }
}
