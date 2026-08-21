import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../mosques/domain/entities/mosque.dart';
import '../../report_form/domain/entities/circle_report.dart';
import '../../report_form/domain/entities/student_record.dart';

class PdfGenerator {
  PdfGenerator._();
  static final PdfGenerator instance = PdfGenerator._();

  static const _line     = PdfColors.black;
  static const _headerBg = PdfColor(0.851, 0.851, 0.851);
  static const _rowAlt   = PdfColor(0.949, 0.949, 0.949);

  static const double _pageW   = 595.15;
  static const double _pageH   = 842.01;
  static const double _marginH = 7.0;

  static const double _h1      = 57.0;
  static const double _h2      = 15.0;
  static const double _rowH    = 14.0;
  static const int    _perPage = 24;

  static const double _wNotes   = 63;
  static const double _wCurric  = 36;
  static const double _wAbsent  = 28;
  static const double _wAttend  = 29;
  static const double _wBehav   = 35;
  static const double _wRevGrade = 36;
  static const double _wRevTo    = 49;
  static const double _wRevFrom  = 42;
  static const double _wHifGrade = 36;
  static const double _wHifTo    = 43;
  static const double _wHifFrom  = 42;
  static const double _wName     = 121;
  static const double _wNum      = 21;

  static const double _grpReview = _wRevGrade + _wRevTo + _wRevFrom;
  static const double _grpHifz   = _wHifGrade + _wHifTo + _wHifFrom;

  static const Map<int, pw.TableColumnWidth> _cols = {
    0:  pw.FixedColumnWidth(_wNotes),
    1:  pw.FixedColumnWidth(_wCurric),
    2:  pw.FixedColumnWidth(_wAbsent),
    3:  pw.FixedColumnWidth(_wAttend),
    4:  pw.FixedColumnWidth(_wBehav),
    5:  pw.FixedColumnWidth(_wRevGrade),
    6:  pw.FixedColumnWidth(_wRevTo),
    7:  pw.FixedColumnWidth(_wRevFrom),
    8:  pw.FixedColumnWidth(_wHifGrade),
    9:  pw.FixedColumnWidth(_wHifTo),
    10: pw.FixedColumnWidth(_wHifFrom),
    11: pw.FixedColumnWidth(_wName),
    12: pw.FixedColumnWidth(_wNum),
  };

  /// [stampBytes]: صورة ختم المسجد (إن وُجدت)، تُمرَّر جاهزة كبايتات بعد فك
  /// ترميزها من Base64. مرّري null إن لم يكن لهذا المسجد ختم بعد، وستظهر
  /// مساحة فارغة مكانه في التقرير.
  /// [supervisorName]: اسم مشرفة حلقات هذا المسجد تحديداً.
  /// [rightHeaderText]: النص الأيمن لترويسة التقرير الخاص بهذا المسجد.
  /// مرّري null إن لم يُخصِّص هذا المسجد ترويسته إطلاقاً، وسيُستخدم النص
  /// الافتراضي الحالي ([Mosque.defaultRightHeaderText]) تلقائياً — أما نص
  /// فارغ فيُعرَض كما هو (بدون أي نص) لأنه يعني حذفاً متعمَّداً من المسؤول.
  /// [leftHeaderText]: نص أيسر اختياري للترويسة، و[headerLogoBytes]: شعار
  /// اختياري يُرسم في يسار الترويسة. كلاهما null يعني عدم وجود أي منهما،
  /// فتبقى الترويسة مطابقة تماماً لشكلها قبل هذه الميزة.
  /// [monthlyBannerText]: نص شريط عنوان التقرير الشهري أسفل الترويسة،
  /// بدون عبارة "لشهر: ..." التي تُضاف دائماً تلقائياً في نهايته. مرّري
  /// null إن لم يُخصَّص، وسيُستخدم [Mosque.defaultMonthlyBannerText].
  Future<String> generate(
    CircleReport report, {
    Uint8List? stampBytes,
    String? supervisorName,
    String? rightHeaderText,
    String? leftHeaderText,
    Uint8List? headerLogoBytes,
    String? monthlyBannerText,
  }) async {
    final font     = await _loadFont('assets/fonts/Amiri-Regular.ttf');
    final fontBold = await _loadFont('assets/fonts/Amiri-Bold.ttf');
    final stampImage = stampBytes != null ? pw.MemoryImage(stampBytes) : null;
    final headerLogoImage =
        headerLogoBytes != null ? pw.MemoryImage(headerLogoBytes) : null;
    final effectiveRightHeaderText =
        rightHeaderText ?? Mosque.defaultRightHeaderText;
    final effectiveMonthlyBannerText =
        monthlyBannerText ?? Mosque.defaultMonthlyBannerText;

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
    );

    final total     = report.circleInfo.studentsCount;
    final pageCount = (total / _perPage).ceil().clamp(1, 999);

    for (int p = 0; p < pageCount; p++) {
      final start = p * _perPage;
      final end   = ((p + 1) * _perPage).clamp(0, total);
      pdf.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(_pageW, _pageH),
          margin: pw.EdgeInsets.zero,
          build: (ctx) => _page(
            report, font, fontBold, stampImage, supervisorName,
            rightHeaderText: effectiveRightHeaderText,
            leftHeaderText: leftHeaderText,
            headerLogoImage: headerLogoImage,
            monthlyBannerText: effectiveMonthlyBannerText,
            start: start, end: end,
            page: p + 1, pages: pageCount,
          ),
        ),
      );
    }

    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/${report.suggestedFileName}');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  pw.Widget _page(
    CircleReport report,
    pw.Font font,
    pw.Font bold,
    pw.MemoryImage? stampImage,
    String? supervisorName, {
    required String rightHeaderText,
    String? leftHeaderText,
    pw.MemoryImage? headerLogoImage,
    required String monthlyBannerText,
    required int start,
    required int end,
    required int page,
    required int pages,
  }) {
    final i = report.circleInfo;
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: _marginH, vertical: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _orgHeader(font, bold, rightHeaderText, leftHeaderText, headerLogoImage),
          pw.SizedBox(height: 4),
          _monthBanner(i.month, i.year, monthlyBannerText, font, bold),
          _infoRow(
            leftLabel: 'مدرسة/ دار: ', leftValue: i.schoolName,
            rightLabel: 'المسجد: ',    rightValue: i.mosqueName,
            font: font, bold: bold,
          ),
          _infoRow(
            leftLabel: 'معلمـ/ــة الحلقة: ', leftValue: i.teacherName,
            rightLabel: 'اسم الحلقة: ',      rightValue: i.circleName,
            font: font, bold: bold,
          ),
          _countRow(i.studentsCount, font, bold),
          pw.SizedBox(height: 5),
          pw.Stack(
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _tableHeader(bold),
                  _dataTable(report.students, font, start: start, end: end),
                ],
              ),
              _curriculumOverlay(
                i.companionCurriculums,
                font,
                bold,
                rowsCount: end - start,
              ),
            ],
          ),
          pw.Spacer(),
          _footer(i.teacherName, font, bold, stampImage, supervisorName,
              page: page, pages: pages),
          pw.SizedBox(height: 4),
        ],
      ),
    );
  }

  /// ترويسة التقرير: نص أيمن (اسم المؤسسة) دائماً موجود، ونص أيسر + شعار
  /// اختياريان يظهران فقط إن خصَّص المسجد أحدهما. عندما لا يُخصِّص المسجد
  /// أي شيء (rightHeaderText يطابق [Mosque.defaultRightHeaderText]
  /// تماماً، ولا نص أيسر ولا شعار)، تُرسَم الترويسة حرفياً بنفس الأسطر
  /// وأحجام الخطوط التي كانت مكتوبة يدوياً هنا قبل هذه الميزة — فلا يظهر
  /// أي فرق بصري إطلاقاً على أي مسجد لم يفتح شاشة الإعدادات من الأساس.
  ///
  /// عند وجود شعار و/أو نص أيسر: الشعار يُرسم في مُنتصف الترويسة تماماً
  /// (بين عمودين متساويي العرض للنص الأيسر والنص الأيمن، فيتوسّط بصرياً
  /// بصرف النظر عن طول كل نص)، والنصان الأيمن والأيسر بنفس حجم ووزن
  /// الخط تماماً (Bold 11) ليبدوا متناسقين بدل اختلاف واضح بينهما.
  pw.Widget _orgHeader(
    pw.Font font,
    pw.Font bold,
    String rightHeaderText,
    String? leftHeaderText,
    pw.MemoryImage? logoImage,
  ) {
    final isDefaultRightText = rightHeaderText == Mosque.defaultRightHeaderText;
    final rightLines = rightHeaderText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final leftLines = (leftHeaderText ?? '')
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final hasLeftContent = logoImage != null || leftLines.isNotEmpty;

    final rightBlock = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: isDefaultRightText
          ? [
              _rtl('مجمع آيات بينات لتعليم القرآن', bold, 11),
              _rtl('الكريم وعلومه', bold, 11),
              _rtl('شبوة- عتق', bold, 12),
            ]
          : rightLines.map((l) => _rtl(l, bold, 11)).toList(),
    );

    if (!hasLeftContent) {
      // لا شعار ولا نص أيسر: نفس التخطيط الأصلي بعرض كامل الصفحة تماماً.
      return pw.Align(alignment: pw.Alignment.centerRight, child: rightBlock);
    }

    final leftBlock = leftLines.isEmpty
        ? null
        : pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            // نفس حجم ووزن خط النص الأيمن بالضبط، بدل خط أصغر وأخف كان
            // يبدو غير متناسق بجانبه.
            children: leftLines.map((l) => _rtl(l, bold, 11)).toList(),
          );

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(
          child: leftBlock == null
              ? pw.SizedBox()
              // إبعاد النص عن الشعار إلى الركن الأيسر تماماً — يقابل بشكل
              // متماثل النص الأيمن الذي يقف عند الركن الأيمن (centerRight)،
              // بدل أن يبقى ملاصقاً للشعار في المنتصف.
              : pw.Align(
                  alignment: pw.Alignment.centerLeft, child: leftBlock),
        ),
        if (logoImage != null)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8),
            child: pw.Container(
              width: 42,
              height: 42,
              child: pw.Image(logoImage, fit: pw.BoxFit.contain),
            ),
          )
        else
          pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Align(
            alignment: pw.Alignment.centerRight,
            child: rightBlock,
          ),
        ),
      ],
    );
  }

 pw.Widget _monthBanner(
    String month, String year, String bannerText, pw.Font font, pw.Font bold) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _line, width: 0.6)),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          _rtl('$year هـ', bold, 9),
          pw.SizedBox(width: 10),
          // "لشهر: $month" تُضاف دائماً تلقائياً في النهاية — لا تُخزَّن
          // ضمن bannerText نفسه لأنها تتغيّر مع كل تقرير.
          _rtl('$bannerText لشهر: $month', font, 9),
        ],
      ),
    );
  }
  pw.Widget _infoRow({
    required String leftLabel,
    required String leftValue,
    required String rightLabel,
    required String rightValue,
    required pw.Font font,
    required pw.Font bold,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left:   pw.BorderSide(color: _line, width: 0.6),
          right:  pw.BorderSide(color: _line, width: 0.6),
          bottom: pw.BorderSide(color: _line, width: 0.6),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(child: _labelValue(leftLabel,  leftValue,  font, bold)),
          pw.Container(width: 0.6, height: 20, color: _line),
          pw.Expanded(child: _labelValue(rightLabel, rightValue, font, bold)),
        ],
      ),
    );
  }

  pw.Widget _labelValue(String label, String value, pw.Font font, pw.Font bold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.RichText(
          textDirection: pw.TextDirection.rtl,
          text: pw.TextSpan(children: [
            pw.TextSpan(text: label,
                style: pw.TextStyle(font: bold, fontSize: 9)),
            pw.TextSpan(text: value,
                style: pw.TextStyle(font: font, fontSize: 9)),
          ]),
        ),
      ),
    );
  }

  pw.Widget _countRow(int count, pw.Font font, pw.Font bold) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left:   pw.BorderSide(color: _line, width: 0.6),
          right:  pw.BorderSide(color: _line, width: 0.6),
          bottom: pw.BorderSide(color: _line, width: 0.6),
        ),
      ),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.RichText(
          textDirection: pw.TextDirection.rtl,
          text: pw.TextSpan(children: [
            pw.TextSpan(text: 'عدد الطلاب ',
                style: pw.TextStyle(font: bold, fontSize: 9)),
            pw.TextSpan(text: '( $count )',
                style: pw.TextStyle(font: bold, fontSize: 9)),
            pw.TextSpan(text: '   وقت الحلقة: عصراً',
                style: pw.TextStyle(font: font, fontSize: 9)),
          ]),
        ),
      ),
    );
  }

  pw.Widget _tableHeader(pw.Font bold) {
    const totalH = _h1 + _h2;
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _tall('ملاحظات', bold, _wNotes, totalH),
        _tallML(['المنهج', 'المصاحب'], bold, _wCurric, totalH),
        _tall('غ', bold, _wAbsent, totalH),
        _tall('ح', bold, _wAttend, totalH),
        _tallML(['السلوك', 'والانضباط'], bold, _wBehav, totalH),
        _group('المراجعة', bold, _grpReview,
            [_wRevGrade, _wRevTo, _wRevFrom]),
        _group('الحفظ', bold, _grpHifz,
            [_wHifGrade, _wHifTo, _wHifFrom]),
        _tall('اسم الطالبـ/ـة', bold, _wName, totalH),
        _tall('م', bold, _wNum, totalH),
      ],
    );
  }

  pw.Widget _group(String title, pw.Font bold, double width, List<double> subs) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: width,
          height: _h1,
          decoration: pw.BoxDecoration(
            color: _headerBg,
            border: pw.Border.all(color: _line, width: 0.6),
          ),
          child: pw.Center(child: _rtl(title, bold, 9)),
        ),
        pw.Row(children: [
          _sub('التقدير', bold, subs[0]),
          _sub('إلى',     bold, subs[1]),
          _sub('من',      bold, subs[2]),
        ]),
      ],
    );
  }

  pw.Widget _tall(String text, pw.Font bold, double w, double h) {
    return pw.Container(
      width: w, height: h,
      decoration: pw.BoxDecoration(
        color: _headerBg,
        border: pw.Border.all(color: _line, width: 0.6),
      ),
      child: pw.Center(child: _rtl(text, bold, 9)),
    );
  }

  pw.Widget _tallML(List<String> lines, pw.Font bold, double w, double h) {
    return pw.Container(
      width: w, height: h,
      decoration: pw.BoxDecoration(
        color: _headerBg,
        border: pw.Border.all(color: _line, width: 0.6),
      ),
      child: pw.Center(
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: lines.map((l) => _rtl(l, bold, 7)).toList(),
        ),
      ),
    );
  }

  pw.Widget _sub(String text, pw.Font bold, double w) {
    return pw.Container(
      width: w, height: _h2,
      decoration: pw.BoxDecoration(
        color: _headerBg,
        border: pw.Border.all(color: _line, width: 0.6),
      ),
      child: pw.Center(child: _rtl(text, bold, 8)),
    );
  }

  pw.Widget _dataTable(
    List<StudentRecord> students,
    pw.Font font, {
    required int start,
    required int end,
  }) {
    return pw.Table(
      columnWidths: _cols,
      border: pw.TableBorder.all(color: _line, width: 0.6),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: List.generate(end - start, (i) {
        final n = start + i + 1;
        final s = (start + i) < students.length ? students[start + i] : null;
        return _dataRow(n, s, font);
      }),
    );
  }

  pw.TableRow _dataRow(int n, StudentRecord? s, pw.Font font) {
    final bg = n.isEven ? _rowAlt : PdfColors.white;
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: bg),
      children: [
        _cell(s?.notes ?? '', font),
        // خلية فارغة هيكلياً فقط: العمود الفعلي "المنهج المصاحب" يُرسم
        // كصندوق واحد مدموج فوق كل صفوف الطالبات (انظر _curriculumOverlay)
        // بدل تكرار نفس القيمة نصياً في كل صف على حدة.
        _cell('', font),
        _cell(s == null ? '' : (s.absenceDays > 0 ? '${s.absenceDays}' : '-'), font),
        _cell(s == null ? '' : (s.attendanceDays > 0 ? '${s.attendanceDays}' : ''), font),
        _cell(s == null ? '' : '${s.behaviorScore}', font),
        _cell(s?.reviewGrade ?? '', font),
        _cell(s?.reviewEndSurah ?? '', font),
        _cell(s?.reviewStartSurah ?? '', font),
        _cell(s?.grade ?? '', font),
        _cell(s?.endSurah ?? '', font),
        _cell(s?.startSurah ?? '', font),
        _cell(s?.name ?? '', font, right: true),
        _cell('$n', font),
      ],
    );
  }

  /// يرسم عمود "المنهج المصاحب" كخلية واحدة مدمجة عمودياً تمتد على طول
  /// كل صفوف الطالبات في هذه الصفحة، بدل تكرار نفس القيمة نصياً في كل
  /// صف — مطابقةً لشكل العمود المدموج في نموذج التقرير الأصلي.
  ///
  /// السبب التقني: مكتبة PDF المستخدمة لا تدعم دمج خلايا الجدول
  /// (rowSpan) مباشرة، لذلك نرسم صندوقاً منفصلاً بخلفية بيضاء فوق
  /// المكان الذي يشغله هذا العمود بالضبط داخل الجدول.
  ///
  /// مهم بخصوص الارتفاع: الوضع الطبيعي (الغالب) هو تحديد ارتفاع الصندوق
  /// عبر `top` + `bottom: 0` (وليس برقم ثابت محسوب يدوياً) حتى يتطابق
  /// تماماً مع الحافة السفلية الحقيقية للجدول أياً كانت، فلا يبقى أي
  /// فجوة أو خط غير مغلق أسفل آخر صف. وبدل تكبير الصندوق عند قلة عدد
  /// الطالبات، نُصغّر حجم الخط تلقائياً ليتّسع للنص كاملاً.
  ///
  /// لكن للخط حد أدنى مقروء (5)، فلو كان عدد الطالبات قليلاً جداً مع
  /// عدد كبير من بنود المنهج المصاحب، قد لا يكفي التصغير وحده لعرض كل
  /// البنود فيختفي آخرها بصمت — وهذا أخطر من تجاوز بصري بسيط للجدول.
  /// في هذه الحالة الاستثنائية فقط، نسمح للصندوق بتجاوز الحافة السفلية
  /// الحقيقية للجدول (ارتفاع صريح بدل bottom:0) لضمان ظهور كل بند
  /// اختارته المعلمة دون قصّ، حتى لو امتدّ قليلاً إلى المساحة الفارغة
  /// أسفل الجدول في تلك الصفحة.
  pw.Widget _curriculumOverlay(
    List<String> items,
    pw.Font font,
    pw.Font bold, {
    required int rowsCount,
  }) {
    const double minFontSize = 5.0;
    const double maxFontSize = 7.0;
    final double availableHeight = rowsCount * _rowH;
    final int lineCount = items.isEmpty ? 0 : items.length * 2 - 1;

    double fontSize = maxFontSize;
    double? overflowHeight;
    if (lineCount > 0) {
      final double fitFontSize = (availableHeight - 6) / lineCount - 3;
      if (fitFontSize >= minFontSize) {
        fontSize = fitFontSize.clamp(minFontSize, maxFontSize);
      } else {
        // حتى بأصغر خط مقروء، البنود لا تتّسع ضمن صفوف هذه الصفحة —
        // نستخدم أصغر خط ونكبّر الصندوق بدل قصّ آخر بند بصمت.
        fontSize = minFontSize;
        final double needed = lineCount * (minFontSize + 3) + 6;
        overflowHeight = needed > availableHeight ? needed : availableHeight;
      }
    }

    return pw.Positioned(
      left: _wNotes,
      top: _h1 + _h2,
      bottom: overflowHeight == null ? 0.0 : null,
      child: pw.Container(
        width: _wCurric,
        height: overflowHeight,
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(color: _line, width: 0.6),
        ),
        child: items.isEmpty
            ? null
            : pw.Center(
                child: pw.Column(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: _curriculumLines(items, font, bold, fontSize),
                ),
              ),
      ),
    );
  }

  List<pw.Widget> _curriculumLines(
    List<String> items,
    pw.Font font,
    pw.Font bold,
    double fontSize,
  ) {
    final widgets = <pw.Widget>[];
    for (var idx = 0; idx < items.length; idx++) {
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 1),
          child: pw.Text(
            items[idx],
            textDirection: pw.TextDirection.rtl,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(font: font, fontSize: fontSize),
          ),
        ),
      );
      if (idx != items.length - 1) {
        widgets.add(
          pw.Text('+',
              style: pw.TextStyle(font: bold, fontSize: fontSize + 1)),
        );
      }
    }
    return widgets;
  }

  pw.Widget _cell(String text, pw.Font font, {bool right = false}) {
    final isNumeric = RegExp(r'^[0-9\-]*$').hasMatch(text);
    return pw.SizedBox(
      height: _rowH,
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3),
        child: pw.Align(
          alignment: right ? pw.Alignment.centerRight : pw.Alignment.center,
          child: pw.Text(
            text,
            textDirection: isNumeric ? pw.TextDirection.ltr : pw.TextDirection.rtl,
            style: pw.TextStyle(font: font, fontSize: 8),
            textAlign: right ? pw.TextAlign.right : pw.TextAlign.center,
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
          ),
        ),
      ),
    );
  }

pw.Widget _footer(String teacher, pw.Font font, pw.Font bold,
      pw.MemoryImage? stampImage, String? supervisorName,
      {required int page, required int pages}) {
    return pw.Column(children: [
      pw.SizedBox(height: 6),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _rtl('التوقيع:...........................', font, 9),
          if (pages > 1) _rtl('$page / $pages', font, 8),
          // الختم بجانب المشرفة (يظهر فارغاً إن لم يكن لهذا المسجد ختم بعد)
          pw.Row(
            children: [
              if (stampImage != null)
                pw.Image(stampImage, width: 80, height: 80)
              else
                pw.SizedBox(width: 80, height: 80),
              pw.SizedBox(width: 6),
              if (supervisorName != null && supervisorName.trim().isNotEmpty)
                pw.RichText(
                  textDirection: pw.TextDirection.rtl,
                  text: pw.TextSpan(children: [
                    pw.TextSpan(text: 'مشرفـ/ـة الحلقات: ',
                        style: pw.TextStyle(font: bold, fontSize: 9)),
                    pw.TextSpan(text: supervisorName,
                        style: pw.TextStyle(font: font, fontSize: 9)),
                  ]),
                ),
            ],
          ),
          pw.RichText(
            textDirection: pw.TextDirection.rtl,
            text: pw.TextSpan(children: [
              pw.TextSpan(text: 'معلمـ/ـة الحلقة: ',
                  style: pw.TextStyle(font: bold, fontSize: 9)),
              pw.TextSpan(text: teacher,
                  style: pw.TextStyle(font: font, fontSize: 9)),
            ]),
          ),
        ],
      ),
    ]);
  }
  pw.Widget _rtl(String text, pw.Font font, double size) {
    return pw.Text(
      text,
      textDirection: pw.TextDirection.rtl,
      style: pw.TextStyle(font: font, fontSize: size),
      textAlign: pw.TextAlign.center,
    );
  }

  Future<pw.Font> _loadFont(String path) async {
    final data = await rootBundle.load(path);
    return pw.Font.ttf(data);
  }
}