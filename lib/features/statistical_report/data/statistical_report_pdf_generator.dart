import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/entities/follow_up_student.dart';
import '../domain/entities/statistical_report_result.dart';
import '../domain/entities/student_period_summary.dart';
import '../domain/performance_rating.dart';

/// يولّد PDF لتقرير إحصائي لأداء حلقة عبر فترة هجرية — بهوية بصرية
/// ملوّنة (أخضر/ذهبي) مطابقة لواجهة التطبيق نفسها، بخلاف مولّد PDF
/// للتقرير الشهري الأصلي (`pdf_generator.dart`) الذي يبقى رمادياً/أبيض
/// وأسود مطابقاً للقالب الورقي — القراران متعمَّدان ومنفصلان (انظر
/// القسم 12 من مستند مواصفات التصميم في مشروع Claude).
class StatisticalReportPdfGenerator {
  StatisticalReportPdfGenerator._();

  static final PdfColor _green = PdfColor.fromInt(0xFF1B6B3A);
  static final PdfColor _lightGreen = PdfColor.fromInt(0xFFE8F5E9);
  static final PdfColor _gold = PdfColor.fromInt(0xFFB8860B);
  static final PdfColor _lightGold = PdfColor.fromInt(0xFFFFF6E5);
  static final PdfColor _border = PdfColor.fromInt(0xFFE3E3E3);
  static final PdfColor _altRow = PdfColor.fromInt(0xFFF6F8F6);
  static final PdfColor _textDark = PdfColor.fromInt(0xFF1F2937);
  static final PdfColor _textGray = PdfColor.fromInt(0xFF6B7280);

  /// [totalStudents]/[activeCount]/[inactiveCount] تُحسَب من ميزة "القوائم"
  /// (Roster) الخاصة بالحلقة، وليس من بيانات التقارير الشهرية نفسها —
  /// تُمرَّر جاهزة من الشاشة لتبقى هذه الدالة منطقاً حسابياً بحتاً بلا أي
  /// اعتماد على Riverpod أو الواجهة.
  static Future<String> generate({
    required StatisticalReportResult result,
    required String circleName,
    required String periodLabel,
    String? mosqueName,
    String? schoolName,
    String? teacherName,
    required int totalStudents,
    required int activeCount,
    required int inactiveCount,
  }) async {
    final regularData =
        await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/Amiri-Bold.ttf');
    final font = pw.Font.ttf(regularData);
    final boldFont = pw.Font.ttf(boldData);

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        pageFormat: PdfPageFormat.a4.copyWith(
          marginLeft: 32,
          marginRight: 32,
          marginTop: 28,
          marginBottom: 28,
        ),
        header: (context) => _buildHeader(
          circleName: circleName,
          periodLabel: periodLabel,
          mosqueName: mosqueName,
          schoolName: schoolName,
          teacherName: teacherName,
          font: font,
          boldFont: boldFont,
          isFirstPage: context.pageNumber == 1,
        ),
        footer: (context) => _buildFooter(context, font),
        build: (context) => [
          _sectionTitle('الملخص التنفيذي', boldFont),
          pw.SizedBox(height: 8),
          _kpiGrid(
            result: result,
            totalStudents: totalStudents,
            activeCount: activeCount,
            inactiveCount: inactiveCount,
            font: font,
            boldFont: boldFont,
          ),
          pw.SizedBox(height: 18),
          _sectionTitle('مؤشرات الأداء', boldFont),
          pw.SizedBox(height: 8),
          _indicatorsBox(result, font, boldFont),
          pw.SizedBox(height: 18),
          _sectionTitle('الأداء العام للحلقة', boldFont),
          pw.SizedBox(height: 8),
          _overallChips(result, font, boldFont),
          pw.SizedBox(height: 18),
          _sectionTitle(
            'طالبات بحاجة إلى متابعة',
            boldFont,
            trailing: result.followUps.isNotEmpty
                ? '${result.followUps.length}'
                : null,
          ),
          pw.SizedBox(height: 8),
          result.followUps.isEmpty
              ? _emptyNote(
                  'لا توجد طالبات بحاجة إلى متابعة حالياً — الأداء ضمن الحدود الطبيعية.',
                  font)
              : _followUpTable(result.followUps, font, boldFont),
          pw.SizedBox(height: 18),
          _sectionTitle('ملخّص أداء الطالبات خلال الفترة', boldFont),
          pw.SizedBox(height: 8),
          _studentsTable(result.students, font, boldFont),
        ],
      ),
    );

    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    final safeCircleName =
        circleName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final file =
        File('${dir.path}/تقرير_إحصائي_$safeCircleName.pdf');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  // ---------------------------------------------------------------------
  // الترويسة والتذييل
  // ---------------------------------------------------------------------

  static pw.Widget _buildHeader({
    required String circleName,
    required String periodLabel,
    required String? mosqueName,
    required String? schoolName,
    required String? teacherName,
    required pw.Font font,
    required pw.Font boldFont,
    required bool isFirstPage,
  }) {
    if (!isFirstPage) {
      // في الصفحات التالية نكتفي بشريط مختصر لتفادي تكرار كل التفاصيل.
      return pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _border, width: 0.8)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('تقرير إحصائي — $circleName',
                style: pw.TextStyle(font: boldFont, fontSize: 9, color: _green)),
            pw.Text(periodLabel,
                style: pw.TextStyle(font: font, fontSize: 8.5, color: _textGray)),
          ],
        ),
      );
    }

    final metaLines = <pw.Widget>[];
    if (mosqueName != null && mosqueName.isNotEmpty) {
      metaLines.add(_metaChip('المسجد', mosqueName, font, boldFont));
    }
    if (schoolName != null && schoolName.isNotEmpty) {
      metaLines.add(_metaChip('الدار', schoolName, font, boldFont));
    }
    if (teacherName != null && teacherName.isNotEmpty) {
      metaLines.add(_metaChip('المعلمة', teacherName, font, boldFont));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Center(
          child: pw.Text(
            'تقرير إحصائي لأداء الحلقة',
            style: pw.TextStyle(font: boldFont, fontSize: 19, color: _green),
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Center(
          child: pw.Text(
            circleName,
            style: pw.TextStyle(font: boldFont, fontSize: 12.5, color: _textDark),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text(
            periodLabel,
            style: pw.TextStyle(font: font, fontSize: 9.5, color: _textGray),
          ),
        ),
        if (metaLines.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Wrap(
            alignment: pw.WrapAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: metaLines,
          ),
        ],
        pw.SizedBox(height: 10),
        pw.Container(height: 1.4, color: _green),
        pw.SizedBox(height: 12),
      ],
    );
  }

  static pw.Widget _metaChip(
      String label, String value, pw.Font font, pw.Font boldFont) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: pw.BoxDecoration(
        color: _lightGreen,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.RichText(
        textDirection: pw.TextDirection.rtl,
        text: pw.TextSpan(children: [
          pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(font: boldFont, fontSize: 8.5, color: _green)),
          pw.TextSpan(
              text: value,
              style: pw.TextStyle(font: font, fontSize: 8.5, color: _textDark)),
        ]),
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _border, width: 0.8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('تطبيق رعاية',
              style: pw.TextStyle(font: font, fontSize: 8, color: _textGray)),
          pw.Text('${context.pageNumber} / ${context.pagesCount}',
              style: pw.TextStyle(font: font, fontSize: 8, color: _textGray)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // عناوين الأقسام
  // ---------------------------------------------------------------------

  static pw.Widget _sectionTitle(String title, pw.Font boldFont,
      {String? trailing}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Row(children: [
          pw.Container(width: 3, height: 13, color: _green),
          pw.SizedBox(width: 6),
          pw.Text(title,
              style:
                  pw.TextStyle(font: boldFont, fontSize: 11.5, color: _textDark)),
        ]),
        if (trailing != null)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: pw.BoxDecoration(
              color: _lightGreen,
              borderRadius: pw.BorderRadius.circular(9),
            ),
            child: pw.Text(trailing,
                style:
                    pw.TextStyle(font: boldFont, fontSize: 9, color: _green)),
          ),
      ],
    );
  }

  static pw.Widget _emptyNote(String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Text(text,
          style: pw.TextStyle(font: font, fontSize: 9, color: _textGray)),
    );
  }

  // ---------------------------------------------------------------------
  // الملخص التنفيذي (شبكة KPI)
  // ---------------------------------------------------------------------

  static pw.Widget _kpiGrid({
    required StatisticalReportResult result,
    required int totalStudents,
    required int activeCount,
    required int inactiveCount,
    required pw.Font font,
    required pw.Font boldFont,
  }) {
    final cells = <_KpiData>[
      _KpiData('$totalStudents', 'إجمالي الطالبات', isHero: true),
      _KpiData(
        result.avgAttendancePercent > 0
            ? '${result.avgAttendancePercent.round()}%'
            : '—',
        'متوسط الحضور',
        isHero: true,
      ),
      _KpiData('$activeCount', 'طالبات نشطات'),
      _KpiData('$inactiveCount', 'طالبات غير نشطات'),
      _KpiData(
        result.avgAbsencePercent > 0
            ? '${result.avgAbsencePercent.round()}%'
            : '—',
        'متوسط الغياب',
      ),
      _KpiData(
        result.avgBehavior > 0
            ? '${result.avgBehavior.toStringAsFixed(1)}/10'
            : '—',
        'متوسط السلوك',
      ),
    ];

    final rows = <pw.Widget>[];
    for (var i = 0; i < cells.length; i += 3) {
      final rowCells = cells.skip(i).take(3).toList();
      rows.add(
        pw.Row(
          children: [
            for (var j = 0; j < rowCells.length; j++) ...[
              if (j > 0) pw.SizedBox(width: 8),
              pw.Expanded(child: _kpiCell(rowCells[j], font, boldFont)),
            ],
          ],
        ),
      );
      if (i + 3 < cells.length) rows.add(pw.SizedBox(height: 8));
    }

    return pw.Column(children: rows);
  }

  static pw.Widget _kpiCell(_KpiData data, pw.Font font, pw.Font boldFont) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: pw.BoxDecoration(
        color: data.isHero ? _lightGreen : PdfColors.white,
        border: pw.Border.all(
            color: data.isHero ? _green : _border, width: data.isHero ? 1 : 0.7),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(data.value,
              style: pw.TextStyle(
                  font: boldFont,
                  fontSize: data.isHero ? 17 : 14,
                  color: data.isHero ? _green : _textDark)),
          pw.SizedBox(height: 3),
          pw.Text(data.label,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: font, fontSize: 8, color: _textGray)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // مؤشرات الأداء (أشرطة تقدّم)
  // ---------------------------------------------------------------------

  static pw.Widget _indicatorsBox(
      StatisticalReportResult result, pw.Font font, pw.Font boldFont) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: _border, width: 0.7),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          _indicatorRow(
            'الحضور',
            result.avgAttendancePercent,
            result.avgAttendancePercent > 0
                ? '${result.avgAttendancePercent.round()}%'
                : '—',
            font,
            boldFont,
          ),
          _indicatorRow(
            'الغياب',
            result.avgAbsencePercent,
            result.avgAbsencePercent > 0
                ? '${result.avgAbsencePercent.round()}%'
                : '—',
            font,
            boldFont,
            isGold: true,
          ),
          _indicatorRow(
            'السلوك',
            result.avgBehavior > 0 ? result.avgBehavior * 10 : 0.0,
            result.avgBehavior > 0 ? result.avgBehavior.toStringAsFixed(1) : '—',
            font,
            boldFont,
          ),
          _indicatorRow(
            'الحفظ',
            PerformanceRating.scoreOf(result.overallMemorizationGrade) * 20.0,
            result.overallMemorizationGrade.isEmpty
                ? '—'
                : result.overallMemorizationGrade,
            font,
            boldFont,
          ),
          _indicatorRow(
            'المراجعة',
            PerformanceRating.scoreOf(result.overallRevisionGrade) * 20.0,
            result.overallRevisionGrade.isEmpty
                ? '—'
                : result.overallRevisionGrade,
            font,
            boldFont,
            isLast: true,
          ),
        ],
      ),
    );
  }

  static pw.Widget _indicatorRow(
    String label,
    double percent,
    String valueLabel,
    pw.Font font,
    pw.Font boldFont, {
    bool isGold = false,
    bool isLast = false,
  }) {
    final color = isGold ? _gold : _green;
    final trackColor = isGold ? _lightGold : _lightGreen;
    // حزمة pdf/widgets لا توفّر ودجت "FractionallySizedBox" (خاص بفلاتر
    // فقط)، لذا نبني الشريط النسبي بتقسيم Row إلى عمودين عبر flex بدل
    // نسبة عرض مباشرة — نفس الأثر البصري بأدوات متاحة فعلاً في المكتبة.
    // percent.clamp(...).round() ينتج int ضمن [0, 100] مباشرةً — بلا حاجة
    // لـ .clamp() ثانية على النتيجة (كانت ستُرجع num بدل int وتكسر Expanded).
    final int filled = percent.clamp(0.0, 100.0).round();
    final int remaining = 100 - filled;
    pw.Widget bar;
    if (filled <= 0) {
      bar = pw.Container(
        height: 6,
        decoration:
            pw.BoxDecoration(color: trackColor, borderRadius: pw.BorderRadius.circular(3)),
      );
    } else if (filled >= 100) {
      bar = pw.Container(
        height: 6,
        decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(3)),
      );
    } else {
      bar = pw.Container(
        height: 6,
        decoration:
            pw.BoxDecoration(color: trackColor, borderRadius: pw.BorderRadius.circular(3)),
        child: pw.Row(
          children: [
            pw.Expanded(
              flex: filled,
              child: pw.Container(
                height: 6,
                decoration:
                    pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(3)),
              ),
            ),
            pw.Expanded(flex: remaining, child: pw.SizedBox()),
          ],
        ),
      );
    }
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(font: boldFont, fontSize: 9, color: _textDark)),
              pw.Text(valueLabel,
                  style: pw.TextStyle(font: boldFont, fontSize: 9, color: color)),
            ],
          ),
          pw.SizedBox(height: 3),
          bar,
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // الأداء العام للحلقة (رقائق)
  // ---------------------------------------------------------------------

  static pw.Widget _overallChips(
      StatisticalReportResult result, pw.Font font, pw.Font boldFont) {
    final chips = [
      _ChipData('الحضور',
          PerformanceRating.ratingFromPercent(result.avgAttendancePercent)),
      _ChipData('السلوك',
          PerformanceRating.ratingFromPercent(result.avgBehavior * 10)),
      _ChipData('الحفظ', result.overallMemorizationGrade),
      _ChipData('المراجعة', result.overallRevisionGrade),
    ];

    final rows = <pw.Widget>[];
    for (var i = 0; i < chips.length; i += 2) {
      final rowChips = chips.skip(i).take(2).toList();
      rows.add(
        pw.Row(
          children: [
            for (var j = 0; j < rowChips.length; j++) ...[
              if (j > 0) pw.SizedBox(width: 8),
              pw.Expanded(child: _chipCell(rowChips[j], font, boldFont)),
            ],
          ],
        ),
      );
      if (i + 2 < chips.length) rows.add(pw.SizedBox(height: 8));
    }
    return pw.Column(children: rows);
  }

  static pw.Widget _chipCell(_ChipData data, pw.Font font, pw.Font boldFont) {
    final isHigh = PerformanceRating.isHigh(data.grade);
    final dotColor = data.grade.isEmpty
        ? _textGray
        : (isHigh ? _green : _gold);
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: _border, width: 0.7),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        children: [
          pw.Container(
            width: 7,
            height: 7,
            decoration: pw.BoxDecoration(color: dotColor, shape: pw.BoxShape.circle),
          ),
          pw.SizedBox(width: 6),
          pw.Text(data.label,
              style: pw.TextStyle(font: boldFont, fontSize: 9, color: _textDark)),
          pw.Spacer(),
          pw.Text(data.grade.isEmpty ? '—' : data.grade,
              style: pw.TextStyle(font: font, fontSize: 9, color: _textGray)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // طالبات بحاجة إلى متابعة
  // ---------------------------------------------------------------------

  static pw.Widget _followUpTable(
      List<FollowUpStudent> followUps, pw.Font font, pw.Font boldFont) {
    return pw.Table(
      border: pw.TableBorder.all(color: _border, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.2),
        1: pw.FlexColumnWidth(3.5),
        2: pw.FlexColumnWidth(1.3),
        3: pw.FlexColumnWidth(1.3),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _lightGold),
          children: [
            _tableHeaderCell('الطالبة', boldFont),
            _tableHeaderCell('سبب المتابعة', boldFont),
            _tableHeaderCell('الحضور', boldFont),
            _tableHeaderCell('السلوك', boldFont),
          ],
        ),
        ...followUps.asMap().entries.map((entry) {
          final index = entry.key;
          final f = entry.value;
          final s = f.summary;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
                color: index.isOdd ? _altRow : PdfColors.white),
            children: [
              _tableCell(s.studentName, font, bold: true, boldFont: boldFont),
              _tableCell(f.reasons.join('، '), font, color: _gold),
              _tableCell(
                s.totalPossibleDays > 0 ? '${s.attendancePercent.round()}%' : '—',
                font,
              ),
              _tableCell(
                s.behaviorAvg > 0 ? s.behaviorAvg.toStringAsFixed(1) : '—',
                font,
              ),
            ],
          );
        }),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // جدول ملخّص أداء الطالبات
  // ---------------------------------------------------------------------

  static pw.Widget _studentsTable(
      List<StudentPeriodSummary> students, pw.Font font, pw.Font boldFont) {
    if (students.isEmpty) {
      return _emptyNote('لا توجد بيانات لهذه الفترة', font);
    }
    return pw.Table(
      border: pw.TableBorder.all(color: _border, width: 0.6),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.4),
        1: pw.FlexColumnWidth(1.6),
        2: pw.FlexColumnWidth(1.6),
        3: pw.FlexColumnWidth(1.2),
        4: pw.FlexColumnWidth(1.2),
        5: pw.FlexColumnWidth(1.2),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _lightGreen),
          children: [
            _tableHeaderCell('الطالبة', boldFont),
            _tableHeaderCell('الحفظ', boldFont),
            _tableHeaderCell('المراجعة', boldFont),
            _tableHeaderCell('السلوك', boldFont),
            _tableHeaderCell('الحضور', boldFont),
            _tableHeaderCell('الغياب', boldFont),
          ],
        ),
        ...students.asMap().entries.map((entry) {
          final index = entry.key;
          final s = entry.value;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
                color: index.isOdd ? _altRow : PdfColors.white),
            children: [
              _tableCell(s.studentName, font, bold: true, boldFont: boldFont),
              _tableCell(s.memorizationGrade.isEmpty ? '—' : s.memorizationGrade, font),
              _tableCell(s.revisionGrade.isEmpty ? '—' : s.revisionGrade, font),
              _tableCell(
                  s.behaviorAvg > 0 ? s.behaviorAvg.toStringAsFixed(1) : '—', font),
              _tableCell(
                  s.totalPossibleDays > 0 ? '${s.attendancePercent.round()}%' : '—',
                  font),
              _tableCell(
                  s.totalPossibleDays > 0 ? '${s.absencePercent.round()}%' : '—',
                  font),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _tableHeaderCell(String text, pw.Font boldFont) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: pw.Text(text,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: boldFont, fontSize: 8.5, color: _textDark)),
    );
  }

  static pw.Widget _tableCell(
    String text,
    pw.Font font, {
    bool bold = false,
    pw.Font? boldFont,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          font: bold && boldFont != null ? boldFont : font,
          fontSize: 8.5,
          color: color ?? _textDark,
        ),
      ),
    );
  }
}

class _KpiData {
  final String value;
  final String label;
  final bool isHero;
  const _KpiData(this.value, this.label, {this.isHero = false});
}

class _ChipData {
  final String label;
  final String grade;
  const _ChipData(this.label, this.grade);
}
