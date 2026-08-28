import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hijri/hijri_calendar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants/quran_constants.dart';
import '../domain/entities/roster_report_group.dart';

/// يولّد ملف PDF لتقرير "قائمة أسماء الطالبات".
///
/// الأسلوب البصري (أبيض/أسود، خط Amiri، جداول محدَّدة بحدود) مطابق عمداً
/// لأسلوب قالب التقرير الشهري الرسمي المعتمد في المشروع — هذا كشف رسمي
/// وليس تقريراً تحليلياً، فلا يستخدم الهوية الملوّنة المستخدمة في التقرير
/// الإحصائي. بلا اسم مؤسسة ثابت في الترويسة (بناءً على طلب صريح)، لأن
/// النطاق قد يشمل أكثر من مسجد دفعة واحدة.
class RosterReportPdfGenerator {
  static Future<String> generate({
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

    // نكتفي بشهر وسنة هجريَين (بلا رقم يوم) — نفس مستوى الدقة الزمنية
    // المعتمَد في كل التطبيق (لا يوجد أي مكان آخر يُخزِّن أو يعرض يوماً
    // هجرياً مفرداً، فقط شهر + سنة).
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
                      style: pw.TextStyle(fontSize: 18, font: boldFont),
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Container(height: 1.4, color: PdfColors.black),
                  pw.SizedBox(height: 14),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.black),
                    ),
                    child: pw.Wrap(
                      spacing: 26,
                      runSpacing: 6,
                      children: [
                        _metaItem(
                            'المسجد', mosqueScopeLabel ?? 'كل المساجد', font, boldFont),
                        _metaItem(
                            'الدار', schoolScopeLabel ?? 'كل الدور', font, boldFont),
                        _metaItem('نطاق الحلقات',
                            circleScopeLabel ?? 'كل الحلقات', font, boldFont),
                        _metaItem(
                            'حالة الطالبات',
                            showInactive ? 'تشمل غير النشطات' : 'نشطات فقط',
                            font,
                            boldFont),
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
                pw.Text('إجمالي عدد الطالبات المعروضات: $totalCount',
                    style: pw.TextStyle(font: font, fontSize: 9)),
                pw.Text('تاريخ الإصدار: $todayLabel',
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
                border: pw.Border.all(color: PdfColors.black),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('الحلقة: ${group.circleName}',
                      style: pw.TextStyle(font: boldFont, fontSize: 11)),
                  pw.Text('الدار: ${group.schoolName}',
                      style: pw.TextStyle(font: boldFont, fontSize: 11)),
                ],
              ),
            ),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.black, width: 0.7),
              columnWidths: showInactive
                  ? {
                      0: const pw.FlexColumnWidth(0.5),
                      1: const pw.FlexColumnWidth(3),
                      2: const pw.FlexColumnWidth(1.3),
                    }
                  : {
                      0: const pw.FlexColumnWidth(0.5),
                      1: const pw.FlexColumnWidth(3),
                    },
              children: [
                for (var i = 0; i < group.students.length; i++)
                  pw.TableRow(
                    children: [
                      _cell('${i + 1}', font),
                      _cell(group.students[i].name, font, alignRight: true),
                      if (showInactive)
                        _cell(
                          group.students[i].isActive ? 'نشطة' : 'غير نشطة',
                          font,
                        ),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 16),
          ],
        ],
      ),
    );

    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/قائمة_أسماء_الطالبات.pdf');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  static pw.Widget _metaItem(
      String label, String value, pw.Font font, pw.Font boldFont) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text('$label: ', style: pw.TextStyle(font: boldFont, fontSize: 10)),
        pw.Text(value, style: pw.TextStyle(font: font, fontSize: 10)),
      ],
    );
  }

  static pw.Widget _cell(String text, pw.Font font, {bool alignRight = false}) {
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
