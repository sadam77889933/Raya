import '../../../roster/domain/entities/roster_student.dart';
import '../entities/student_record.dart';
import 'unique_students_counter.dart';

/// طالبات سجل الحلقة اللاتي لم يرد اسمهن بعد في [reportStudents]، أي من يصحّ
/// إضافتهن إلى تقرير قيد التعديل. النشطات أولاً ثم غير النشطات، مع حفظ ترتيب
/// السجل داخل كل مجموعة.
///
/// - طالبة في التقرير لها studentId: تُستبعد صاحبة الرقم نفسه فقط، فاسم مشابه
///   لطالبة أخرى في السجل لا يُخفيها.
/// - طالبة في تقرير قديم بلا studentId: تُستبعد طالبة السجل التي يطابق اسمها
///   (بعد التطبيع)، لكن فقط إن كان الاسم يخص طالبة واحدة في السجل؛ إن تكرر
///   الاسم لا نخمّن، وتبقى الطالبتان ظاهرتين لتختار المعلمة.
List<RosterStudent> rosterStudentsNotInReport({
  required Iterable<RosterStudent> roster,
  required Iterable<StudentRecord> reportStudents,
}) {
  final idsInReport = <String>{};
  final legacyNamesInReport = <String>{};
  for (final student in reportStudents) {
    if (student.studentId.isNotEmpty) {
      idsInReport.add(student.studentId);
      continue;
    }
    final name = normalizeStudentName(student.name);
    if (name.isNotEmpty) legacyNamesInReport.add(name);
  }

  final rosterList = roster.toList();
  final rosterNameCounts = <String, int>{};
  for (final student in rosterList) {
    rosterNameCounts.update(
      normalizeStudentName(student.name),
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }

  bool isInReport(RosterStudent student) {
    if (idsInReport.contains(student.id)) return true;
    final name = normalizeStudentName(student.name);
    return legacyNamesInReport.contains(name) && rosterNameCounts[name] == 1;
  }

  final available = rosterList.where((s) => !isInReport(s)).toList();
  return [
    ...available.where((s) => s.isActive),
    ...available.where((s) => !s.isActive),
  ];
}

/// تصفية [students] بنص البحث، بنفس تطبيع الأسماء المستخدم في العدّ
/// (يتجاهل التشكيل وأشكال الألف والتاء المربوطة والياء)، فالبحث بـ«فاطمه»
/// يجد «فاطمة». نص البحث الفارغ يُرجع القائمة كما هي.
List<RosterStudent> searchRosterStudents(
  List<RosterStudent> students,
  String query,
) {
  final needle = normalizeStudentName(query);
  if (needle.isEmpty) return students;
  return students
      .where((s) => normalizeStudentName(s.name).contains(needle))
      .toList();
}
