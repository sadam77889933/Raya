import 'package:flutter_test/flutter_test.dart';
import 'package:quran_circle_report/features/report_form/domain/entities/student_record.dart';

Map<String, dynamic> _json({String? studentId}) => {
      'index': 1,
      'name': 'سارة',
      'startSurah': 'البقرة',
      'endSurah': 'آل عمران',
      'grade': 'ممتاز',
      if (studentId != null) 'studentId': studentId,
    };

void main() {
  group('StudentRecord.studentId', () {
    test('التقرير القديم بلا studentId يُقرأ بقيمة فارغة', () {
      expect(StudentRecord.fromJson(_json()).studentId, '');
    });

    test('يُقرأ ويُكتب عبر JSON دون فقدان', () {
      final record = StudentRecord.fromJson(_json(studentId: 'abc123'));
      expect(record.studentId, 'abc123');
      expect(record.toJson()['studentId'], 'abc123');
    });

    test('لا يُكتب الحقل في JSON إن كان فارغاً', () {
      final record = StudentRecord.fromJson(_json());
      expect(record.toJson().containsKey('studentId'), isFalse);
    });

    test('copyWith يحافظ عليه ويسمح بتغييره', () {
      final record = StudentRecord.fromJson(_json(studentId: 'abc123'));
      expect(record.copyWith(grade: 'جيد').studentId, 'abc123');
      expect(record.copyWith(studentId: 'xyz').studentId, 'xyz');
    });
  });
}
