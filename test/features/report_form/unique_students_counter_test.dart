import 'package:flutter_test/flutter_test.dart';
import 'package:quran_circle_report/features/report_form/domain/entities/report_summary.dart';
import 'package:quran_circle_report/features/report_form/domain/services/unique_students_counter.dart';

Map<String, dynamic> _student(String name, [String id = '']) => {
      'name': name,
      if (id.isNotEmpty) 'studentId': id,
    };

List<Map<String, dynamic>> _names(List<String> names) =>
    [for (final name in names) _student(name)];

ReportSummary _report({
  required String circleId,
  required List<Map<String, dynamic>> students,
  String circleName = 'حلقة',
  String month = 'ربيع الآخر',
}) {
  return ReportSummary(
    id: '$circleId-$month',
    teacherName: 'معلمة',
    mosqueId: 'm1',
    circleId: circleId,
    circleName: circleName,
    schoolName: '',
    month: month,
    year: '1448',
    studentsCount: students.length,
    createdAt: DateTime(2026),
    students: students,
    periodKey: 0,
  );
}

void main() {
  group('uniqueStudentsCount - بالاسم (تقارير بلا رقم)', () {
    test('لا يُحسب تقرير فارغ ولا قائمة فارغة', () {
      expect(<ReportSummary>[].uniqueStudentsCount, 0);
      expect([_report(circleId: 'c1', students: [])].uniqueStudentsCount, 0);
    });

    test('الطالبة نفسها في تقارير شهور متعددة لنفس الحلقة تُحسب مرة واحدة', () {
      final reports = [
        _report(circleId: 'c1', students: _names(['سارة', 'ليلى', 'نورة'])),
        _report(
          circleId: 'c1',
          month: 'جمادى الأولى',
          students: _names(['سارة', 'ليلى', 'نورة']),
        ),
      ];
      expect(reports.uniqueStudentsCount, 3);
    });

    test('طالبة جديدة في شهر لاحق تُضاف للعدد', () {
      final reports = [
        _report(circleId: 'c1', students: _names(['سارة', 'ليلى'])),
        _report(
          circleId: 'c1',
          month: 'جمادى الأولى',
          students: _names(['سارة', 'ليلى', 'هند']),
        ),
      ];
      expect(reports.uniqueStudentsCount, 3);
    });

    test('الاسم نفسه في حلقتين مختلفتين يُحسب مرتين', () {
      final reports = [
        _report(circleId: 'c1', students: _names(['فاطمة'])),
        _report(circleId: 'c2', students: _names(['فاطمة'])),
      ];
      expect(reports.uniqueStudentsCount, 2);
    });

    test('فروق الكتابة لا تصنع طالبة جديدة', () {
      final reports = [
        _report(
          circleId: 'c1',
          students: _names(['أحمد  علي', 'فاطمة', 'ليلى']),
        ),
        _report(
          circleId: 'c1',
          month: 'جمادى الأولى',
          students: _names(['احمد علي ', 'فاطمه', 'ليلي']),
        ),
      ];
      expect(reports.uniqueStudentsCount, 3);
    });

    test('الأسماء الفارغة تُهمَل', () {
      final reports = [
        _report(circleId: 'c1', students: _names(['سارة', '', '   '])),
      ];
      expect(reports.uniqueStudentsCount, 1);
    });

    test('التقارير القديمة بلا circleId تُجمَّع باسم الحلقة', () {
      final reports = [
        _report(
          circleId: '',
          circleName: 'رياض الجنة',
          students: _names(['سارة']),
        ),
        _report(
          circleId: '',
          circleName: 'رياض الجنة',
          month: 'جمادى الأولى',
          students: _names(['سارة']),
        ),
        _report(
          circleId: '',
          circleName: 'درب السعادة',
          students: _names(['سارة']),
        ),
      ];
      expect(reports.uniqueStudentsCount, 2);
    });
  });

  group('uniqueStudentsCount - برقم السجل (studentId)', () {
    test('الرقم نفسه باسمين مختلفين (طالبة غُيّر اسمها) يُحسب مرة واحدة', () {
      final reports = [
        _report(circleId: 'c1', students: [_student('فاطمه علي', 's1')]),
        _report(
          circleId: 'c1',
          month: 'جمادى الأولى',
          students: [_student('فاطمة علي الأحمد', 's1')],
        ),
      ];
      expect(reports.uniqueStudentsCount, 1);
    });

    test('الرقم نفسه في حلقتين (طالبة منقولة) يُحسب مرة واحدة', () {
      final reports = [
        _report(circleId: 'c1', students: [_student('هند', 's1')]),
        _report(
          circleId: 'c2',
          month: 'جمادى الأولى',
          students: [_student('هند', 's1')],
        ),
      ];
      expect(reports.uniqueStudentsCount, 1);
    });

    test('رقمان مختلفان بنفس الاسم في الحلقة نفسها طالبتان', () {
      final reports = [
        _report(
          circleId: 'c1',
          students: [_student('فاطمة', 's1'), _student('فاطمة', 's2')],
        ),
      ];
      expect(reports.uniqueStudentsCount, 2);
    });

    test('صف قديم بلا رقم يُربط بطالبة لها رقم في نفس الحلقة عبر الاسم', () {
      final reports = [
        _report(circleId: 'c1', students: _names(['سارة', 'ليلى'])),
        _report(
          circleId: 'c1',
          month: 'جمادى الأولى',
          students: [_student('سارة', 's1'), _student('ليلى', 's2')],
        ),
      ];
      expect(reports.uniqueStudentsCount, 2);
    });

    test('صف قديم بلا رقم لا يُربط بطالبة لها رقم في حلقة أخرى', () {
      final reports = [
        _report(circleId: 'c1', students: _names(['سارة'])),
        _report(
          circleId: 'c2',
          month: 'جمادى الأولى',
          students: [_student('سارة', 's1')],
        ),
      ];
      expect(reports.uniqueStudentsCount, 2);
    });
  });

  group('normalizeStudentName', () {
    test('يوحّد الهمزات والتاء المربوطة والألف المقصورة', () {
      expect(normalizeStudentName('إيمان'), normalizeStudentName('ايمان'));
      expect(normalizeStudentName('آمنة'), normalizeStudentName('امنه'));
      expect(normalizeStudentName('هدى'), normalizeStudentName('هدي'));
    });

    test('يزيل التشكيل والتطويل والمسافات الزائدة', () {
      expect(normalizeStudentName('  مُحَمَّد   علي '), 'محمد علي');
      expect(normalizeStudentName('عـبـدالله'), 'عبدالله');
    });
  });
}
