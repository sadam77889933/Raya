import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../domain/entities/student_attendance_summary.dart';

class AttendancePdfGenerator {
  static Future<String> generate({
    required List<StudentAttendanceSummary> summaries,
    required String periodLabel,
    String? mosqueName,
    String? teacherName,
    String? schoolName,
    String? circleName,
  }) async {
    final regularData =
        await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/Amiri-Bold.ttf');
    final font = pw.Font.ttf(regularData);
    final boldFont = pw.Font.ttf(boldData);

    final doc = pw.Document();

    final filterLines = <pw.Widget>[];
    if (mosqueName != null && mosqueName.isNotEmpty) {
      filterLines.add(_filterRow('المسجد', mosqueName, font, boldFont));
    }
    if (teacherName != null && teacherName.isNotEmpty) {
      filterLines.add(_filterRow('المعلمة', teacherName, font, boldFont));
    }
    if (schoolName != null && schoolName.isNotEmpty) {
      filterLines.add(_filterRow('الدار', schoolName, font, boldFont));
    }
    if (circleName != null && circleName.isNotEmpty) {
      filterLines.add(_filterRow('الحلقة', circleName, font, boldFont));
    }

    doc.addPage(
      pw.MultiPage(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'تقرير الحضور والغياب',
              style: pw.TextStyle(fontSize: 20, font: boldFont),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Center(
            child: pw.Text(
              periodLabel,
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            ),
          ),
          if (filterLines.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: filterLines,
              ),
            ),
          ],
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _headerCell('الطالبة', boldFont),
                  _headerCell('أيام الحضور', boldFont),
                  _headerCell('أيام الغياب', boldFont),
                ],
              ),
              ...summaries.map((s) => pw.TableRow(
                    children: [
                      _cell(s.studentName, font),
                      _cell('${s.totalAttendanceDays}', font),
                      _cell('${s.totalAbsenceDays}', font,
                          color: s.totalAbsenceDays >= 10
                              ? PdfColors.red
                              : (s.totalAbsenceDays >= 5
                                  ? PdfColors.orange
                                  : PdfColors.black)),
                    ],
                  )),
            ],
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/تقرير_الحضور_والغياب.pdf');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  static pw.Widget _filterRow(
      String label, String value, pw.Font font, pw.Font boldFont) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('$label:',
              style: pw.TextStyle(font: boldFont, fontSize: 10)),
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: 10)),
        ],
      ),
    );
  }

  static pw.Widget _headerCell(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: font, fontSize: 11)),
    );
  }

  static pw.Widget _cell(String text, pw.Font font, {PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
              font: font, fontSize: 11, color: color ?? PdfColors.black)),
    );
  }
}