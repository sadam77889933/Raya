import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../domain/entities/summer_test.dart';
import '../domain/entities/summer_test_question.dart';
import 'summer_test_pdf_generator.dart';

/// يفكّ شعار ترويسة المسجد المحفوظ كنص base64؛ يُعيد null إن لم يوجد شعار أو
/// كان تالفاً (فيُترك مكانه فارغاً بدل أن يفشل التصدير كله).
Uint8List? decodeHeaderLogoBase64(String? base64Logo) {
  if (base64Logo == null || base64Logo.isEmpty) return null;
  try {
    return base64Decode(base64Logo);
  } catch (_) {
    return null;
  }
}

/// اختبار مطلوب تصديره، مع اسمَي مستواه ومادته (يحلّهما المستدعي من
/// القوائم المحمَّلة أصلاً في الشاشة، فلا قراءة إضافية هنا).
class SummerTestsExportItem {
  final SummerTest test;
  final String levelName;
  final String subjectName;

  const SummerTestsExportItem({
    required this.test,
    required this.levelName,
    required this.subjectName,
  });
}

/// تقدّم التصدير: [done] من [total] اختباراً أُضيفت إلى الملف.
class SummerTestsExportProgress extends Equatable {
  final int done;
  final int total;

  /// عنوان الاختبار الجاري تجهيزه (للعرض فقط).
  final String currentTitle;

  const SummerTestsExportProgress({
    required this.done,
    required this.total,
    this.currentTitle = '',
  });

  double get fraction => total == 0 ? 0 : done / total;

  @override
  List<Object?> get props => [done, total, currentTitle];
}

/// ناتج التصدير الناجح.
class SummerTestsExportResult {
  final Uint8List bytes;

  /// عدد الاختبارات التي دخلت الملف فعلاً.
  final int exportedCount;

  /// اختبارات محدَّدة استُبعدت لأنها بلا أسئلة (لا ورقة تُطبَع منها).
  final List<SummerTest> skippedWithoutQuestions;

  const SummerTestsExportResult({
    required this.bytes,
    required this.exportedCount,
    required this.skippedWithoutQuestions,
  });
}

/// رمز إلغاء يمرّره المستدعي ويستدعي [cancel] منه عند ضغط «إلغاء».
class ExportCancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

/// أُلغي التصدير بطلب المستخدمة — ليس خطأً.
class SummerTestsExportCancelled implements Exception {
  const SummerTestsExportCancelled();

  @override
  String toString() => 'تم إلغاء التصدير';
}

/// عدد الاختبارات المحدَّدة يتجاوز [SummerTestsExportService.maxTestsPerExport].
class SummerTestsExportTooManyException implements Exception {
  final int requested;
  final int max;

  const SummerTestsExportTooManyException({
    required this.requested,
    required this.max,
  });

  @override
  String toString() =>
      'الحد الأقصى $max اختبارًا في الملف الواحد (المحدَّد $requested)';
}

/// كل الاختبارات المحدَّدة بلا أسئلة، فلا يوجد ما يُصدَّر.
class SummerTestsExportNothingToExportException implements Exception {
  final List<SummerTest> skippedWithoutQuestions;

  const SummerTestsExportNothingToExportException(this.skippedWithoutQuestions);

  @override
  String toString() => 'الاختبارات المحدَّدة لا تحتوي أي أسئلة';
}

/// قارئ أسئلة اختبار بمعرّفه (يُحقَن للاختبار بدل Firestore).
typedef SummerQuestionsLoader = Future<List<SummerTestQuestion>> Function(
  String testId,
);

/// تصدير عدة اختبارات في ملف PDF واحد، كل اختبار يبدأ بصفحة جديدة
/// بترويسته (مستقلاً عن غيره)، بنفس مولّد الاختبار الواحد تماماً — فتبقى
/// الأسئلة والخيارات وترتيبها وتنسيقها كما في الاختبار الأصلي.
///
/// لا يقرأ الخدمة شيئاً من الواجهة ولا يكتب في أي بيانات؛ هو قراءة فقط.
class SummerTestsExportService {
  /// أقصى عدد اختبارات في ملف واحد، حمايةً للويب والأجهزة الضعيفة.
  static const int maxTestsPerExport = 30;

  /// كم اختباراً تُقرأ أسئلته معاً (قراءات متوازية صغيرة تسرّع التجهيز دون
  /// إغراق الاتصال).
  static const int _loadBatchSize = 5;

  final SummerQuestionsLoader _loadQuestions;
  final SummerTestPdfFonts? _fonts;

  SummerTestsExportService({
    required SummerQuestionsLoader loadQuestions,
    SummerTestPdfFonts? fonts,
  })  : _loadQuestions = loadQuestions,
        _fonts = fonts;

  /// يصدّر [items] بترتيبها نفسه. يرمي:
  /// - [SummerTestsExportTooManyException] إن زاد العدد عن [maxTestsPerExport]،
  /// - [SummerTestsExportCancelled] عند الإلغاء عبر [cancelToken]،
  /// - [SummerTestsExportNothingToExportException] إن كانت كلها بلا أسئلة.
  Future<SummerTestsExportResult> export({
    required List<SummerTestsExportItem> items,
    required String centerName,
    required String mosqueName,
    String? rightHeaderText,
    String? leftHeaderText,
    Uint8List? headerLogoBytes,
    void Function(SummerTestsExportProgress progress)? onProgress,
    ExportCancelToken? cancelToken,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError.value(items, 'items', 'لا اختبارات للتصدير');
    }
    if (items.length > maxTestsPerExport) {
      throw SummerTestsExportTooManyException(
        requested: items.length,
        max: maxTestsPerExport,
      );
    }

    void throwIfCancelled() {
      if (cancelToken?.isCancelled ?? false) {
        throw const SummerTestsExportCancelled();
      }
    }

    throwIfCancelled();
    final builder = await SummerTestPdfBundleBuilder.create(
      centerName: centerName,
      mosqueName: mosqueName,
      rightHeaderText: rightHeaderText,
      leftHeaderText: leftHeaderText,
      headerLogoBytes: headerLogoBytes,
      fonts: _fonts,
    );

    final total = items.length;
    final skipped = <SummerTest>[];
    onProgress?.call(SummerTestsExportProgress(done: 0, total: total));

    for (var start = 0; start < total; start += _loadBatchSize) {
      throwIfCancelled();
      final batch = items.sublist(start, min(start + _loadBatchSize, total));
      final loaded = await Future.wait(
        batch.map((item) => _loadQuestions(item.test.id)),
      );

      for (var j = 0; j < batch.length; j++) {
        throwIfCancelled();
        final item = batch[j];
        final questions = loaded[j];
        if (questions.isEmpty) {
          skipped.add(item.test);
        } else {
          builder.addTest(SummerTestPdfInput(
            test: item.test,
            questions: questions,
            levelName: item.levelName,
            subjectName: item.subjectName,
          ));
        }
        onProgress?.call(SummerTestsExportProgress(
          done: start + j + 1,
          total: total,
          currentTitle: item.test.title,
        ));
        // يفسح للواجهة لرسم التقدّم بين اختبار وآخر (خيط واحد على الويب).
        await Future<void>.delayed(Duration.zero);
      }
    }

    if (builder.testsCount == 0) {
      throw SummerTestsExportNothingToExportException(skipped);
    }
    throwIfCancelled();

    final bytes = await builder.build();
    return SummerTestsExportResult(
      bytes: bytes,
      exportedCount: builder.testsCount,
      skippedWithoutQuestions: skipped,
    );
  }

  /// اسم ملف المشاركة: عنوان الاختبار إن كان واحداً، وإلا «اختبارات <الشهر>».
  /// تُزال المحارف غير المسموحة في أسماء الملفات.
  static String fileName({
    required List<SummerTest> tests,
    required String periodLabel,
  }) {
    final raw = tests.length == 1
        ? (tests.first.title.trim().isEmpty ? 'اختبار' : tests.first.title)
        : 'اختبارات $periodLabel';
    var name = raw
        .replaceAll(RegExp(r'[\\/:*?"<>|\u0000-\u001f]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (name.isEmpty) name = 'اختبارات';
    if (name.length > 80) name = name.substring(0, 80).trim();
    return '$name.pdf';
  }
}
