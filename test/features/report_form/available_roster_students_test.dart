import 'package:flutter_test/flutter_test.dart';
import 'package:quran_circle_report/features/report_form/domain/entities/student_record.dart';
import 'package:quran_circle_report/features/report_form/domain/services/available_roster_students.dart';
import 'package:quran_circle_report/features/roster/domain/entities/roster_student.dart';

RosterStudent _roster(String id, String name, {bool isActive = true}) =>
    RosterStudent(
      id: id,
      name: name,
      circleId: 'circle-1',
      isActive: isActive,
      createdAt: DateTime(2026, 1, 1),
    );

StudentRecord _record(String name, {String studentId = ''}) =>
    StudentRecord.empty(1).copyWith(name: name, studentId: studentId);

List<String> _ids(List<RosterStudent> students) =>
    students.map((s) => s.id).toList();

void main() {
  group('الطالبات المتاحة للإضافة إلى تقرير', () {
    test('كل السجل متاح حين يكون التقرير بلا طالبات', () {
      final roster = [_roster('a', 'فاطمة'), _roster('b', 'نور')];

      final result =
          rosterStudentsNotInReport(roster: roster, reportStudents: const []);

      expect(_ids(result), ['a', 'b']);
    });

    test('تُستبعد من لها رقم (studentId) في التقرير', () {
      final roster = [_roster('a', 'فاطمة'), _roster('b', 'نور')];

      final result = rosterStudentsNotInReport(
        roster: roster,
        reportStudents: [_record('فاطمة', studentId: 'a')],
      );

      expect(_ids(result), ['b']);
    });

    test('تُستبعد بالرقم حتى لو تغيّر اسمها في السجل بعد حفظ التقرير', () {
      final roster = [_roster('a', 'فاطمة محمد'), _roster('b', 'نور')];

      final result = rosterStudentsNotInReport(
        roster: roster,
        reportStudents: [_record('فاطمة', studentId: 'a')],
      );

      expect(_ids(result), ['b']);
    });

    test('الاسم المشابه لا يُخفي طالبة أخرى لها رقم مختلف', () {
      final roster = [_roster('a', 'فاطمة'), _roster('b', 'فاطمة')];

      final result = rosterStudentsNotInReport(
        roster: roster,
        reportStudents: [_record('فاطمة', studentId: 'a')],
      );

      expect(_ids(result), ['b']);
    });

    test('صف قديم بلا رقم يستبعد طالبة السجل المطابقة اسماً بعد التطبيع', () {
      final roster = [_roster('a', 'فاطمة'), _roster('b', 'نور')];

      final result = rosterStudentsNotInReport(
        roster: roster,
        reportStudents: [_record('فاطمه')],
      );

      expect(_ids(result), ['b']);
    });

    test('صف قديم بلا رقم لا يخمّن حين يتكرر الاسم في السجل', () {
      final roster = [_roster('a', 'فاطمة'), _roster('b', 'فاطمة')];

      final result = rosterStudentsNotInReport(
        roster: roster,
        reportStudents: [_record('فاطمة')],
      );

      expect(_ids(result), ['a', 'b']);
    });

    test('البطاقة الفارغة (بلا اسم) لا تستبعد أحداً', () {
      final roster = [_roster('a', 'فاطمة')];

      final result = rosterStudentsNotInReport(
        roster: roster,
        reportStudents: [_record('')],
      );

      expect(_ids(result), ['a']);
    });

    test('النشطات أولاً ثم غير النشطات مع حفظ ترتيب السجل', () {
      final roster = [
        _roster('a', 'أمل', isActive: false),
        _roster('b', 'نور'),
        _roster('c', 'سارة', isActive: false),
        _roster('d', 'ريم'),
      ];

      final result =
          rosterStudentsNotInReport(roster: roster, reportStudents: const []);

      expect(_ids(result), ['b', 'd', 'a', 'c']);
    });
  });

  group('البحث في طالبات السجل', () {
    final students = [
      _roster('a', 'فاطمة'),
      _roster('b', 'أمل'),
      _roster('c', 'نور'),
    ];

    test('النص الفارغ أو المسافات تُرجع القائمة كما هي', () {
      expect(searchRosterStudents(students, ''), students);
      expect(searchRosterStudents(students, '   '), students);
    });

    test('يتجاهل اختلاف الألف والتاء المربوطة', () {
      expect(_ids(searchRosterStudents(students, 'فاطمه')), ['a']);
      expect(_ids(searchRosterStudents(students, 'امل')), ['b']);
    });

    test('يطابق جزءاً من الاسم، ولا نتيجة عند عدم التطابق', () {
      expect(_ids(searchRosterStudents(students, 'نو')), ['c']);
      expect(searchRosterStudents(students, 'سعاد'), isEmpty);
    });
  });
}
