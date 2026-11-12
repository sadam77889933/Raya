import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_circle_report/features/summer_center/data/summer_test_pdf_generator.dart';
import 'package:quran_circle_report/features/summer_center/data/summer_tests_export_service.dart';
import 'package:quran_circle_report/features/summer_center/domain/entities/summer_question_type.dart';
import 'package:quran_circle_report/features/summer_center/domain/entities/summer_test.dart';
import 'package:quran_circle_report/features/summer_center/domain/entities/summer_test_question.dart';

ByteData _fontBytes(String file) {
  final bytes = File('assets/fonts/$file').readAsBytesSync();
  return ByteData.view(Uint8List.fromList(bytes).buffer);
}

final SummerTestPdfFonts _fonts = SummerTestPdfFonts(
  regular: _fontBytes('Amiri-Regular.ttf'),
  bold: _fontBytes('Amiri-Bold.ttf'),
);

final DateTime _now = DateTime(2026, 11, 12);

SummerTest _test(String id, {String title = 'اختبار', String month = 'رجب'}) {
  return SummerTest(
    id: id,
    centerId: 'c1',
    mosqueId: 'm1',
    levelId: 'l1',
    subjectId: 's1',
    teacherId: 'u1',
    teacherName: 'فاطمة محمد',
    title: title,
    hijriMonth: month,
    hijriYear: '1448',
    createdAt: _now,
    updatedAt: _now,
  );
}

SummerTestQuestion _question(String testId, int n) {
  return SummerTestQuestion(
    id: '$testId-$n',
    testId: testId,
    type: SummerQuestionType.trueFalse,
    order: n * 1000.0,
    questionText: 'سؤال رقم $n',
    createdAt: _now,
  );
}

SummerTestsExportItem _item(String id, {String title = 'اختبار'}) {
  return SummerTestsExportItem(
    test: _test(id, title: title),
    levelName: 'المستوى الأول',
    subjectName: 'التجويد',
  );
}

/// عدد صفحات ملف PDF (مفاتيح /Type /Page دون /Pages).
int _pageCount(Uint8List bytes) {
  final text = latin1.decode(bytes);
  return RegExp(r'/Type\s*/Page(?![A-Za-z])').allMatches(text).length;
}

void main() {
  group('SummerTestsExportService.export', () {
    test('يُنتج ملف PDF واحداً بصفحة جديدة لكل اختبار وبالترتيب نفسه', () async {
      final loadedIds = <String>[];
      final service = SummerTestsExportService(
        fonts: _fonts,
        loadQuestions: (id) async {
          loadedIds.add(id);
          return [_question(id, 1), _question(id, 2)];
        },
      );

      final result = await service.export(
        items: [_item('a'), _item('b'), _item('c')],
        centerName: 'المركز الصيفي',
        mosqueName: 'جامع الرحمة',
      );

      expect(String.fromCharCodes(result.bytes.take(5)), equals('%PDF-'));
      expect(result.exportedCount, equals(3));
      expect(result.skippedWithoutQuestions, isEmpty);
      expect(_pageCount(result.bytes), equals(3));
      expect(loadedIds, equals(['a', 'b', 'c']));
    });

    test('يستبعد الاختبارات بلا أسئلة ويُبلغ بها', () async {
      final service = SummerTestsExportService(
        fonts: _fonts,
        loadQuestions: (id) async => id == 'empty' ? <SummerTestQuestion>[] : [_question(id, 1)],
      );

      final result = await service.export(
        items: [_item('a'), _item('empty', title: 'بلا أسئلة'), _item('b')],
        centerName: 'المركز',
        mosqueName: 'الجامع',
      );

      expect(result.exportedCount, equals(2));
      expect(result.skippedWithoutQuestions.map((t) => t.id).toList(), equals(['empty']));
      expect(_pageCount(result.bytes), equals(2));
    });

    test('كلها بلا أسئلة: يرمي NothingToExport مع القائمة المستبعدة', () async {
      final service = SummerTestsExportService(
        fonts: _fonts,
        loadQuestions: (_) async => <SummerTestQuestion>[],
      );

      await expectLater(
        service.export(items: [_item('a'), _item('b')], centerName: 'م', mosqueName: 'ج'),
        throwsA(isA<SummerTestsExportNothingToExportException>()),
      );
    });

    test('أكثر من الحد الأقصى: يرمي TooMany دون قراءة أي أسئلة', () async {
      var loads = 0;
      final service = SummerTestsExportService(
        fonts: _fonts,
        loadQuestions: (id) async {
          loads++;
          return [_question(id, 1)];
        },
      );
      final items = [for (var i = 0; i <= SummerTestsExportService.maxTestsPerExport; i++) _item('t$i')];

      await expectLater(
        service.export(items: items, centerName: 'م', mosqueName: 'ج'),
        throwsA(isA<SummerTestsExportTooManyException>()),
      );
      expect(loads, equals(0));
    });

    test('الحد الأقصى بالضبط مسموح', () async {
      final service = SummerTestsExportService(
        fonts: _fonts,
        loadQuestions: (id) async => [_question(id, 1)],
      );
      final items = [for (var i = 0; i < SummerTestsExportService.maxTestsPerExport; i++) _item('t$i')];

      final result = await service.export(items: items, centerName: 'م', mosqueName: 'ج');

      expect(result.exportedCount, equals(SummerTestsExportService.maxTestsPerExport));
      expect(_pageCount(result.bytes), equals(SummerTestsExportService.maxTestsPerExport));
    });

    test('قائمة فارغة: ArgumentError', () async {
      final service = SummerTestsExportService(fonts: _fonts, loadQuestions: (_) async => <SummerTestQuestion>[]);
      await expectLater(
        service.export(items: const [], centerName: 'م', mosqueName: 'ج'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('تقدّم متزايد من 0 إلى العدد الكلي', () async {
      final service = SummerTestsExportService(
        fonts: _fonts,
        loadQuestions: (id) async => [_question(id, 1)],
      );
      final done = <int>[];
      var total = 0;

      await service.export(
        items: [for (var i = 0; i < 7; i++) _item('t$i')],
        centerName: 'م',
        mosqueName: 'ج',
        onProgress: (p) {
          done.add(p.done);
          total = p.total;
        },
      );

      expect(done.first, equals(0));
      expect(done.last, equals(7));
      expect(total, equals(7));
      for (var i = 1; i < done.length; i++) {
        expect(done[i] >= done[i - 1], isTrue);
      }
    });

    test('الإلغاء يوقف التصدير ولا يقرأ الدفعات التالية', () async {
      var loads = 0;
      final token = ExportCancelToken();
      final service = SummerTestsExportService(
        fonts: _fonts,
        loadQuestions: (id) async {
          loads++;
          return [_question(id, 1)];
        },
      );

      await expectLater(
        service.export(
          items: [for (var i = 0; i < 12; i++) _item('t$i')],
          centerName: 'م',
          mosqueName: 'ج',
          cancelToken: token,
          onProgress: (p) {
            if (p.done == 1) token.cancel();
          },
        ),
        throwsA(isA<SummerTestsExportCancelled>()),
      );
      // الدفعة الأولى فقط (5 اختبارات) قُرئت قبل الإلغاء.
      expect(loads, equals(5));
    });

    test('إلغاء قبل البدء لا يقرأ شيئاً', () async {
      var loads = 0;
      final token = ExportCancelToken()..cancel();
      final service = SummerTestsExportService(
        fonts: _fonts,
        loadQuestions: (id) async {
          loads++;
          return [_question(id, 1)];
        },
      );

      await expectLater(
        service.export(items: [_item('a')], centerName: 'م', mosqueName: 'ج', cancelToken: token),
        throwsA(isA<SummerTestsExportCancelled>()),
      );
      expect(loads, equals(0));
    });

    test('خطأ قراءة الأسئلة يصل للمستدعي كما هو', () async {
      final service = SummerTestsExportService(
        fonts: _fonts,
        loadQuestions: (_) async => throw StateError('فشل الاتصال'),
      );

      await expectLater(
        service.export(items: [_item('a')], centerName: 'م', mosqueName: 'ج'),
        throwsA(isA<StateError>()),
      );
    });

    test('شعار تالف أو ترويسة فارغة لا تُسقط التصدير', () async {
      final service = SummerTestsExportService(
        fonts: _fonts,
        loadQuestions: (id) async => [_question(id, 1)],
      );

      final result = await service.export(
        items: [_item('a')],
        centerName: 'م',
        mosqueName: 'ج',
        rightHeaderText: '',
        leftHeaderText: null,
        headerLogoBytes: decodeHeaderLogoBase64('!!ليس-base64!!'),
      );

      expect(result.exportedCount, equals(1));
    });
  });

  group('SummerTestsExportService.fileName', () {
    test('اختبار واحد: عنوانه', () {
      expect(
        SummerTestsExportService.fileName(tests: [_test('a', title: 'الاختبار النهائي')], periodLabel: 'رجب 1448هـ'),
        equals('الاختبار النهائي.pdf'),
      );
    });

    test('عدة اختبارات: اختبارات + الشهر', () {
      expect(
        SummerTestsExportService.fileName(tests: [_test('a'), _test('b')], periodLabel: 'رجب 1448هـ'),
        equals('اختبارات رجب 1448هـ.pdf'),
      );
    });

    test('عنوان فارغ يصير «اختبار»', () {
      expect(
        SummerTestsExportService.fileName(tests: [_test('a', title: '   ')], periodLabel: 'رجب 1448هـ'),
        equals('اختبار.pdf'),
      );
    });

    test('تُزال المحارف غير المسموحة في أسماء الملفات', () {
      expect(
        SummerTestsExportService.fileName(tests: [_test('a', title: 'أ/ب:ج*د?"<>|هـ')], periodLabel: 'x'),
        equals('أ ب ج د هـ.pdf'),
      );
    });

    test('عنوان طويل يُقتطع', () {
      final name = SummerTestsExportService.fileName(
        tests: [_test('a', title: List.filled(200, 'ا').join())],
        periodLabel: 'x',
      );
      expect(name.length <= 84, isTrue);
      expect(name.endsWith('.pdf'), isTrue);
    });
  });

  group('decodeHeaderLogoBase64', () {
    test('null أو فارغ أو تالف = null', () {
      expect(decodeHeaderLogoBase64(null), isNull);
      expect(decodeHeaderLogoBase64(''), isNull);
      expect(decodeHeaderLogoBase64('!!ليس-base64!!'), isNull);
    });

    test('نص صالح يُفكّ إلى بايتات', () {
      expect(decodeHeaderLogoBase64(base64Encode([1, 2, 3])), equals([1, 2, 3]));
    });
  });
}
