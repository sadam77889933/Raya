import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hijri/hijri_calendar.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/quran_constants.dart';
import '../domain/entities/roster_report_group.dart';

/// يولّد ملف PDF لتقرير "قائمة أسماء الطالبات".
///
/// الأسلوب البصري (أبيض/أسود، خط Amiri، جداول محدَّدة بحدود) مطابق عمداً
/// للمخطط (mockup) المعتمَد من المستخدم ولأسلوب قالب التقرير الشهري
/// الرسمي في المشروع. بلا اسم مؤسسة ثابت في الترويسة لأن النطاق قد يشمل
/// أكثر من مسجد دفعة واحدة.
///
/// ملاحظة تقنية مهمة: بعكس Flutter الحقيقي، عناصر Row/Table في حزمة pdf
/// لا "تُقلَب" تلقائياً بسبب textDirection.rtl — ترتيب العناصر داخل
/// children يقابل ترتيبها الفعلي من اليسار لليمين دائماً (نفس السلوك
/// المُثبَت فعلياً في pdf_generator.dart عبر _infoRow وفي
/// attendance_pdf_generator.dart). لذلك كل عنصر هنا وُضع يدوياً بالترتيب
/// المعاكس لما يظهر في مخطط HTML (الذي يُقلَب تلقائياً في المتصفح بسبب
/// dir=rtl)، حتى تُطابق الطباعة الفعلية شكل المخطط المعتمَد تماماً.
class RosterReportPdfGenerator {
  static Future<Uint8List> generate({
    required List<RosterReportGroup> groups,
    required bool showInactive,
    String? mosqueScopeLabel,
    String? schoolScopeLabel,
    String? circleScopeLabel,
  }) async {
    final regularData =
        await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/Amiri-Bold.ttf');
    final font = pw.Font.ttf(regularData);
    final boldFont = pw.Font.ttf(boldData);

    // شهر وسنة هجريَين فقط (بلا رقم يوم) — نفس مستوى الدقة الزمنية
    // المعتمَد في كل التطبيق.
    final today = HijriCalendar.now();
    final todayLabel =
        '${QuranConstants.hijriMonths[today.hMonth - 1]} ${today.hYear}هـ';

    final totalCount =
        groups.fold<int>(0, (sum, g) => sum + g.students.length);

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
                    child: pw.Text(
                      'قائمة أسماء الطالبات',
                      style: pw.TextStyle(fontSize: 12, font: boldFont),
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Container(height: 1.6, color: PdfColors.black),
                  pw.SizedBox(height: 14),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.black),
                    ),
                    child: pw.Column(
                      children: [
                        _metaGridRow(
                          leftLabel: 'الدار: ',
                          leftValue: schoolScopeLabel ?? 'كل الدور',
                          rightLabel: 'المسجد: ',
                          rightValue: mosqueScopeLabel ?? 'كل المساجد',
                          font: font,
                          boldFont: boldFont,
                        ),
                        pw.SizedBox(height: 8),
                        _metaGridRow(
                          leftLabel: 'حالة الطالبات: ',
                          leftValue: showInactive
                              ? 'تشمل غير النشطات'
                              : 'نشطات فقط',
                          rightLabel: 'نطاق الحلقات: ',
                          rightValue: circleScopeLabel ?? 'كل الحلقات',
                          font: font,
                          boldFont: boldFont,
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
                // الترتيب معكوس عمداً: العنصر الأول هنا يظهر فعلياً على
                // اليسار (بلا انعكاس تلقائي)، فيقابل "تاريخ الإصدار" الذي
                // يظهر يساراً في المخطط المعتمَد، بينما "الإجمالي" يظهر
                // يميناً.
                pw.Text('تاريخ الإصدار: $todayLabel',
                    style: pw.TextStyle(font: font, fontSize: 9)),
                pw.Text('إجمالي عدد الطالبات المعروضات: $totalCount',
                    style: pw.TextStyle(font: font, fontSize: 9)),
              ],
            ),
          ],
        ),
        build: (context) => [
          for (final group in groups) ...[
            pw.Container(
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                border: pw.Border(
                  top: pw.BorderSide(color: PdfColors.black),
                  left: pw.BorderSide(color: PdfColors.black),
                  right: pw.BorderSide(color: PdfColors.black),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // نفس منطق الانعكاس اليدوي: "الدار" أولاً كي تظهر يساراً،
                  // و"الحلقة" ثانياً كي تظهر يميناً (كما في المخطط المعتمَد).
                  pw.Text('الدار: ${group.schoolName}',
                      style: pw.TextStyle(font: boldFont, fontSize: 10.5)),
                  pw.Text('الحلقة: ${group.circleName}',
                      style: pw.TextStyle(font: boldFont, fontSize: 10.5)),
                ],
              ),
            ),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.black, width: 0.7),
              // نفس منطق الانعكاس اليدوي: "الحالة" (إن ظهرت) أولاً فتقع
              // يساراً، ثم "الاسم" في المنتصف، ثم "م" أخيراً فيقع يميناً —
              // مطابقةً لترتيب الأعمدة الظاهر في مخطط الـHTML بعد انعكاسه
              // التلقائي هناك بسبب RTL.
              columnWidths: showInactive
                  ? {
                      0: const pw.FlexColumnWidth(1.1),
                      1: const pw.FlexColumnWidth(5),
                      2: const pw.FlexColumnWidth(0.5),
                    }
                  : {
                      0: const pw.FlexColumnWidth(6),
                      1: const pw.FlexColumnWidth(0.5),
                    },
              children: [
                pw.TableRow(
                  decoration:
                      const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    if (showInactive) _headerCell('الحالة', boldFont),
                    _headerCell('اسم الطالبـ/ـة', boldFont),
                    _headerCell('م', boldFont),
                  ],
                ),
                for (var i = 0; i < group.students.length; i++)
                  pw.TableRow(
                    children: [
                      if (showInactive)
                        _cell(
                          group.students[i].isActive ? 'نشطة' : 'غير نشطة',
                          font,
                        ),
                      _cell(group.students[i].name, font, alignRight: true),
                      _cell('${i + 1}', font),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 16),
          ],
        ],
      ),
    );

    return doc.save();
  }

  /// صفٌّ من عنصرين ضمن مربّع بيانات التقرير (مطابق لصفّي meta-grid في
  /// المخطط المعتمَد). الترتيب معكوس يدوياً بنفس منطق الأعمدة أعلاه:
  /// [leftLabel] يظهر فعلياً يساراً و[rightLabel] يظهر يميناً.
  static pw.Widget _metaGridRow({
    required String leftLabel,
    required String leftValue,
    required String rightLabel,
    required String rightValue,
    required pw.Font font,
    required pw.Font boldFont,
  }) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: _metaLabelValue(leftLabel, leftValue, font, boldFont),
        ),
        pw.SizedBox(width: 20),
        pw.Expanded(
          child: _metaLabelValue(rightLabel, rightValue, font, boldFont),
        ),
      ],
    );
  }

  static pw.Widget _metaLabelValue(
      String label, String value, pw.Font font, pw.Font boldFont) {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.RichText(
        textDirection: pw.TextDirection.rtl,
        text: pw.TextSpan(children: [
          pw.TextSpan(
              text: label, style: pw.TextStyle(font: boldFont, fontSize: 10)),
          pw.TextSpan(
              text: value, style: pw.TextStyle(font: font, fontSize: 10)),
        ]),
      ),
    );
  }

  static pw.Widget _headerCell(String text, pw.Font boldFont) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: boldFont, fontSize: 10),
      ),
    );
  }

  static pw.Widget _cell(String text, pw.Font font,
      {bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.center,
        style: pw.TextStyle(font: font, fontSize: 10.5),
      ),
    );
  }
}
