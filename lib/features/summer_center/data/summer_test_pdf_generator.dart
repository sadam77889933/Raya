import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/entities/summer_question_type.dart';
import '../domain/entities/summer_test.dart';
import '../domain/entities/summer_test_question.dart';

/// يولّد ملف PDF لورقة اختبار المركز الصيفي — لا تُطبَع أي إجابة صحيحة
/// على الإطلاق (لا تحديد للخيار الصحيح، لا علامة على صح/خطأ، لا ترتيب
/// العناصر الصحيح، لا الطرف المطابق الصحيح) لأن هذه ورقة تُسلَّم للطالبة
/// لتُجيب عليها، تماماً كما في التصميم المعتمَد.
///
/// نفس ملاحظة انعكاس الترتيب اليدوي المُثبَتة في roster_report_pdf_generator
/// وpdf_generator: عناصر Row/Table في حزمة pdf لا تُقلَب تلقائياً بسبب
/// textDirection.rtl، فكل صفّ ذو عنصرين مُتنافسين على المساحة (وليس
/// Expanded يمتص الباقي) وُضع هنا بالترتيب المعاكس لما يظهر في مخطط الـ
/// HTML المعتمَد (الذي يُقلَب تلقائياً هناك بسبب direction:rtl).
class SummerTestPdfGenerator {
  static Future<String> generate({
    required SummerTest test,
    required List<SummerTestQuestion> questions,
    required String centerName,
    required String mosqueName,
    required String levelName,
    required String subjectName,
  }) async {
    final regularData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/Amiri-Bold.ttf');
    final font = pw.Font.ttf(regularData);
    final boldFont = pw.Font.ttf(boldData);

    final dateLabel = '${test.hijriMonth} ${test.hijriYear}هـ';
    final random = Random();

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        header: (context) => context.pageNumber == 1
            ? pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Center(
                    child: pw.Text('${test.title} — مادة $subjectName',
                        style: pw.TextStyle(font: boldFont, fontSize: 15)),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Center(
                    child: pw.Text('$centerName — $mosqueName',
                        style: pw.TextStyle(font: font, fontSize: 10.5, color: PdfColors.grey700)),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Container(height: 1.6, color: PdfColors.black),
                  pw.SizedBox(height: 10),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
                    child: pw.Column(
                      children: [
                        _metaRow(leftLabel: 'المادة: ', leftValue: subjectName, rightLabel: 'المستوى: ', rightValue: levelName, font: font, boldFont: boldFont),
                        pw.SizedBox(height: 6),
                        _metaRow(leftLabel: 'التاريخ: ', leftValue: dateLabel, rightLabel: 'المعلمة: ', rightValue: test.teacherName, font: font, boldFont: boldFont),
                      ],
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: pw.BoxDecoration(
                      border: pw.Border(
                        left: pw.BorderSide(color: PdfColors.black),
                        right: pw.BorderSide(color: PdfColors.black),
                        bottom: pw.BorderSide(color: PdfColors.black),
                      ),
                    ),
                    child: pw.Row(
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.black),
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text('الدرجة:      ', style: pw.TextStyle(font: boldFont, fontSize: 10.5)),
                        ),
                        pw.SizedBox(width: 20),
                        pw.Expanded(
                          child: pw.Row(
                            children: [
                              pw.Text('اسم الطالبة: ', style: pw.TextStyle(font: boldFont, fontSize: 11)),
                              pw.Expanded(
                                child: pw.Container(
                                  margin: const pw.EdgeInsets.only(top: 10),
                                  decoration: pw.BoxDecoration(
                                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey600, width: 0.7)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 18),
                ],
              )
            : pw.SizedBox(height: 0),
        footer: (context) => pw.Column(
          children: [
            pw.Container(height: 0.7, color: PdfColors.grey400),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('وفّقكنّ الله', style: pw.TextStyle(font: font, fontSize: 9.5, color: PdfColors.grey700)),
                pw.Text('عدد الأسئلة: ${questions.length}', style: pw.TextStyle(font: font, fontSize: 9.5, color: PdfColors.grey700)),
              ],
            ),
          ],
        ),
        build: (context) => [
          for (var i = 0; i < questions.length; i++) ...[
            _questionBlock(questions[i], i + 1, font, boldFont, random),
            pw.SizedBox(height: 16),
          ],
        ],
      ),
    );

    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    final safeTitle = test.title.trim().isEmpty ? 'اختبار' : test.title.trim();
    final file = File('${dir.path}/$safeTitle.pdf');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  static pw.Widget _questionBlock(
    SummerTestQuestion q,
    int number,
    pw.Font font,
    pw.Font boldFont,
    Random random,
  ) {
    switch (q.type) {
      case SummerQuestionType.multipleChoice:
        final options = (q.typeData['options'] as List?)?.cast<String>() ?? const <String>[];
        const letters = ['أ', 'ب', 'ج', 'د', 'ه‍', 'و', 'ز', 'ح', 'ط', 'ي'];
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _qLine(number, q.questionText, boldFont, hint: '(اختاري الإجابة الصحيحة)', font: font),
            pw.SizedBox(height: 4),
            for (var i = 0; i < options.length; i++)
              pw.Padding(
                padding: const pw.EdgeInsets.only(right: 20, bottom: 4),
                child: pw.Text('○  ${letters[i % letters.length]}) ${options[i]}', style: pw.TextStyle(font: font, fontSize: 11.5)),
              ),
          ],
        );

      case SummerQuestionType.trueFalse:
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _qLine(number, '${q.questionText}.', boldFont, hint: '(ضعي علامة على الإجابة الصحيحة)', font: font),
            pw.SizedBox(height: 4),
            pw.Padding(
              padding: const pw.EdgeInsets.only(right: 20),
              child: pw.Row(
                children: [
                  _tfBox('خطأ', font),
                  pw.SizedBox(width: 18),
                  _tfBox('صح', font),
                ],
              ),
            ),
          ],
        );

      case SummerQuestionType.essay:
      case SummerQuestionType.mention:
      case SummerQuestionType.define:
      case SummerQuestionType.explainWhy:
        final lines = q.typeData['answerLines'] as int? ?? 3;
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _qLine(number, q.questionText, boldFont, font: font),
            for (var i = 0; i < lines; i++)
              pw.Container(
                margin: const pw.EdgeInsets.only(right: 8, left: 8, top: 20),
                decoration: pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey500, width: 0.7)),
                ),
              ),
          ],
        );

      case SummerQuestionType.fillBlank:
        final displayText = q.questionText.replaceAll('___', '  ......................  ');
        return _qLine(number, displayText, boldFont, font: font);

      case SummerQuestionType.order:
        final items = (q.typeData['items'] as List?)?.cast<String>() ?? const <String>[];
        final shuffled = List<String>.from(items)..shuffle(random);
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _qLine(number, q.questionText, boldFont, hint: items.isEmpty ? null : '(١–${items.length})', font: font),
            pw.SizedBox(height: 4),
            for (final item in shuffled)
              pw.Padding(
                padding: const pw.EdgeInsets.only(right: 20, bottom: 7),
                child: pw.Row(
                  children: [
                    pw.Expanded(child: pw.Text(item, style: pw.TextStyle(font: font, fontSize: 11.5))),
                    pw.SizedBox(width: 10),
                    pw.Container(
                      width: 28,
                      height: 20,
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey700, width: 0.9)),
                    ),
                  ],
                ),
              ),
          ],
        );

      case SummerQuestionType.match:
        final pairs = (q.typeData['pairs'] as List?)?.cast<Map>() ?? const <Map>[];
        final rightSideShuffled = pairs.map((p) => p['right'] as String? ?? '').toList()..shuffle(random);
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _qLine(number, q.questionText, boldFont, font: font),
            pw.SizedBox(height: 6),
            pw.Padding(
              padding: const pw.EdgeInsets.only(right: 20),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        for (final word in rightSideShuffled)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 9),
                            child: pw.Text('○  $word', style: pw.TextStyle(font: font, fontSize: 11)),
                          ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 40),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < pairs.length; i++)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(bottom: 9),
                            child: pw.Text('${i + 1})  ${pairs[i]['left'] as String? ?? ''}  ○', style: pw.TextStyle(font: font, fontSize: 11)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      default:
        return _qLine(number, q.questionText, boldFont, font: font);
    }
  }

  static pw.Widget _qLine(int number, String text, pw.Font boldFont, {String? hint, required pw.Font font}) {
    return pw.RichText(
      textDirection: pw.TextDirection.rtl,
      text: pw.TextSpan(children: [
        pw.TextSpan(text: '$number. $text', style: pw.TextStyle(font: boldFont, fontSize: 12.5)),
        if (hint != null) pw.TextSpan(text: '  $hint', style: pw.TextStyle(font: font, fontSize: 9.5, color: PdfColors.grey600)),
      ]),
    );
  }

  static pw.Widget _tfBox(String label, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey700, width: 0.9), borderRadius: pw.BorderRadius.circular(3)),
      child: pw.Text(label, style: pw.TextStyle(font: font, fontSize: 11)),
    );
  }

  static pw.Widget _metaRow({
    required String leftLabel,
    required String leftValue,
    required String rightLabel,
    required String rightValue,
    required pw.Font font,
    required pw.Font boldFont,
  }) {
    return pw.Row(
      children: [
        pw.Expanded(child: _metaLabelValue(leftLabel, leftValue, font, boldFont)),
        pw.SizedBox(width: 20),
        pw.Expanded(child: _metaLabelValue(rightLabel, rightValue, font, boldFont)),
      ],
    );
  }

  static pw.Widget _metaLabelValue(String label, String value, pw.Font font, pw.Font boldFont) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.RichText(
        textDirection: pw.TextDirection.rtl,
        text: pw.TextSpan(children: [
          pw.TextSpan(text: label, style: pw.TextStyle(font: boldFont, fontSize: 10.5)),
          pw.TextSpan(text: value, style: pw.TextStyle(font: font, fontSize: 10.5)),
        ]),
      ),
    );
  }
}
