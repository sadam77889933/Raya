import 'package:flutter_test/flutter_test.dart';
import 'package:quran_circle_report/features/report_form/data/attendance_aggregator.dart';
import 'package:quran_circle_report/features/report_form/domain/entities/report_summary.dart';
import 'package:quran_circle_report/features/statistical_report/data/statistical_report_aggregator.dart';

ReportSummary _report({
  required String teacherId,
  required String teacherName,
  String month = 'ربيع الآخر',
}) {
  return ReportSummary(
    id: '$teacherId-$month',
    teacherName: teacherName,
    teacherId: teacherId,
    mosqueId: 'm1',
    circleId: 'c1',
    circleName: 'حلقة',
    schoolName: 'دار',
    month: month,
    year: '1448',
    studentsCount: 1,
    createdAt: DateTime(2026),
    students: [
      {
        'index': 1,
        'name': 'سارة',
        'attendanceDays': 20,
        'absenceDays': 2,
        'behaviorScore': 9,
        'grade': 'ممتاز',
        'reviewGrade': 'ممتاز',
      },
    ],
    periodKey: 0,
  );
}

void main() {
  // المعلمة t1 غُيّر اسمها بين الشهرين، والمعلمة t2 معلمة أخرى.
  final reports = [
    _report(teacherId: 't1', teacherName: 'مريم'),
    _report(
      teacherId: 't1',
      teacherName: 'مريم أحمد',
      month: 'جمادى الأولى',
    ),
    _report(teacherId: 't2', teacherName: 'هند'),
  ];

  int statisticalCount(String? teacherId) {
    return StatisticalReportAggregator.aggregate(
      allReports: reports,
      fromMonth: 'ربيع الآخر',
      fromYear: '1448',
      toMonth: 'جمادى الأولى',
      toYear: '1448',
      teacherIdFilter: teacherId,
    ).reportsCount;
  }

  int attendanceReportsCount(String? teacherId) {
    return AttendanceAggregator.aggregate(
      allReports: reports,
      fromMonth: 'ربيع الآخر',
      fromYear: '1448',
      toMonth: 'جمادى الأولى',
      toYear: '1448',
      teacherIdFilter: teacherId,
    ).fold<int>(0, (sum, s) => sum + s.reportsCount);
  }

  group('الفلترة بالمعلمة في التقرير الإحصائي', () {
    test('تُحسب كل تقارير المعلمة رغم تغيّر اسمها بين الشهور', () {
      expect(statisticalCount('t1'), 2);
    });

    test('معلمة أخرى لا تختلط تقاريرها', () {
      expect(statisticalCount('t2'), 1);
    });

    test('بلا فلتر تُحسب كل التقارير، ومعرّف غير موجود لا يطابق شيئاً', () {
      expect(statisticalCount(null), 3);
      expect(statisticalCount('غير-موجود'), 0);
    });
  });

  group('الفلترة بالمعلمة في تقرير الحضور', () {
    test('تُحسب كل تقارير المعلمة رغم تغيّر اسمها بين الشهور', () {
      expect(attendanceReportsCount('t1'), 2);
    });

    test('معلمة أخرى لا تختلط تقاريرها', () {
      expect(attendanceReportsCount('t2'), 1);
    });

    test('بلا فلتر تُحسب كل التقارير، ومعرّف غير موجود لا يطابق شيئاً', () {
      expect(attendanceReportsCount(null), 3);
      expect(attendanceReportsCount('غير-موجود'), 0);
    });
  });

  group('ReportSummary.teacherId', () {
    test('يُقرأ من مستند Firestore', () {
      final summary = ReportSummary.fromFirestore({
        'id': 'r1',
        'teacherId': 't1',
        'month': 'محرم',
        'year': '1448',
        'periodKey': 1,
      });
      expect(summary.teacherId, 't1');
    });

    test('يكون فارغاً إن لم يوجد في المستند، ويحافظ عليه copyWith', () {
      final summary = ReportSummary.fromFirestore({
        'id': 'r1',
        'month': 'محرم',
        'year': '1448',
        'periodKey': 1,
      });
      expect(summary.teacherId, '');
      expect(summary.copyWith(teacherId: 't9').teacherId, 't9');
      expect(summary.copyWith(circleName: 'أخرى').teacherId, '');
    });
  });
}
