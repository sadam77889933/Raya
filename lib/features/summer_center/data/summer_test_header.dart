import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// نمط ترويسة الصفحة الأولى في ورقة اختبار المركز الصيفي.
enum SummerTestHeaderStyle {
  /// الترويسة المدمجة (الافتراضية) — تأخذ نحو 16% من ارتفاع الصفحة.
  compact,

  /// الترويسة القديمة كما كانت تماماً (نحو ثلث الصفحة). محفوظة للرجوع إليها
  /// عند الحاجة بتمرير `headerStyle: SummerTestHeaderStyle.classic`.
  classic,
}

/// بيانات الترويسة — نفسها لكل الاختبارات مهما اختلفت المادة أو الشهر أو
/// المستوى أو المعلمة؛ كل قيمة فيها قادمة من الاختبار نفسه، لا شيء ثابت.
class SummerTestHeaderData {
  final String title;
  final String subjectName;
  final String levelName;
  final String teacherName;
  final String dateLabel;
  final String centerName;
  final String mosqueName;

  /// أسطر النص اليميني (اسم المجمع/الجامع/الجهة) كما أدخلها المسؤول.
  final List<String> rightLines;

  /// أسطر النص اليساري (مثل: القرآن الكريم والعلوم الشرعية، قسم النساء).
  final List<String> leftLines;
  final pw.MemoryImage? logo;

  const SummerTestHeaderData({
    required this.title,
    required this.subjectName,
    required this.levelName,
    required this.teacherName,
    required this.dateLabel,
    required this.centerName,
    required this.mosqueName,
    required this.rightLines,
    required this.leftLines,
    this.logo,
  });

  /// يفصل نصاً متعدد الأسطر إلى أسطر غير فارغة (نص null يعني بلا أسطر).
  static List<String> splitLines(String? text) => (text ?? '')
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
}

/// الترويسة المدمجة لورقة الاختبار: شريط الجهة والشعار، العنوان، جدول بيانات
/// الاختبار، وصف اسم الطالبة والدرجة — بأقل مساحة ممكنة مع بقاء كل المعلومات.
///
/// ترتيب العناصر داخل كل Row هنا بترتيب القراءة العربية (العنصر الأول عند
/// أقصى اليمين)، لأن Row في حزمة pdf يعكس ترتيب أبنائه تلقائياً داخل صفحة
/// RTL كهذه الصفحة.
class SummerTestCompactHeader {
  SummerTestCompactHeader._();

  static const double _orgFontSize = 9;
  static const double _logoHeight = 34;
  static const double _borderWidth = 0.7;

  static pw.Widget build({
    required SummerTestHeaderData data,
    required pw.Font font,
    required pw.Font boldFont,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _orgBand(data, boldFont),
        pw.SizedBox(height: 2),
        _titleBlock(data, font, boldFont),
        pw.SizedBox(height: 2),
        pw.Container(height: 1, color: PdfColors.black),
        pw.SizedBox(height: 4),
        _metaTable(data, font, boldFont),
        _studentRow(boldFont),
        pw.SizedBox(height: 8),
      ],
    );
  }

  /// شريط الجهة: نص اليمين | الشعار | نص اليسار — بخط صغير وأسطر متقاربة.
  static pw.Widget _orgBand(SummerTestHeaderData data, pw.Font boldFont) {
    pw.Widget textBlock(List<String> lines, pw.TextAlign align) => pw.Expanded(
          child: lines.isEmpty
              ? pw.SizedBox()
              : pw.Text(
                  lines.join('\n'),
                  textDirection: pw.TextDirection.rtl,
                  textAlign: align,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: _orgFontSize,
                    // ارتفاع سطر Amiri الطبيعي نحو 1.8 ضعف الخط؛ هذا الإنقاص
                    // يقرّب الأسطر دون أن تتلامس الحروف.
                    lineSpacing: -_orgFontSize * 0.4,
                  ),
                ),
        );

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        textBlock(data.rightLines, pw.TextAlign.right),
        if (data.logo != null)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8),
            child: pw.Image(data.logo!, height: _logoHeight, fit: pw.BoxFit.contain),
          ),
        textBlock(data.leftLines, pw.TextAlign.left),
      ],
    );
  }

  static pw.Widget _titleBlock(
    SummerTestHeaderData data,
    pw.Font font,
    pw.Font boldFont,
  ) {
    return pw.Column(
      children: [
        pw.Text(
          '${data.title} — مادة ${data.subjectName}',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: boldFont, fontSize: 12.5),
        ),
        pw.Text(
          '${data.centerName} — ${data.mosqueName}',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(font: font, fontSize: 8.5, color: PdfColors.grey700),
        ),
      ],
    );
  }

  /// جدول بيانات الاختبار في صف واحد بأربع خلايا متساوية.
  ///
  /// `pw.Table` لا يعكس ترتيب أعمدته في صفحة RTL (على عكس Row)، فالخلايا
  /// مرتبة هنا من اليسار إلى اليمين فعلياً: المعلمة تظهر أقصى اليمين.
  static pw.Widget _metaTable(
    SummerTestHeaderData data,
    pw.Font font,
    pw.Font boldFont,
  ) {
    final cellsLeftToRight = [
      ('التاريخ: ', data.dateLabel),
      ('المستوى: ', data.levelName),
      ('المادة: ', data.subjectName),
      ('المعلمة: ', data.teacherName),
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: _borderWidth),
      children: [
        pw.TableRow(
          children: [
            for (final (label, value) in cellsLeftToRight)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.RichText(
                    textDirection: pw.TextDirection.rtl,
                    text: pw.TextSpan(children: [
                      pw.TextSpan(
                        text: label,
                        style: pw.TextStyle(font: boldFont, fontSize: 9),
                      ),
                      pw.TextSpan(
                        text: value,
                        style: pw.TextStyle(font: font, fontSize: 9),
                      ),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// صف اسم الطالبة (يمين) والدرجة (يسار) أسفل جدول البيانات مباشرة.
  static pw.Widget _studentRow(pw.Font boldFont) {
    const border = pw.BorderSide(color: PdfColors.black, width: _borderWidth);
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: const pw.BoxDecoration(
        border: pw.Border(left: border, right: border, bottom: border),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text('اسم الطالبة: ', style: pw.TextStyle(font: boldFont, fontSize: 9.5)),
          pw.Expanded(
            child: pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 5),
              height: 0.6,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(width: 14),
          pw.Container(
            width: 78,
            padding: const pw.EdgeInsets.symmetric(horizontal: 6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black, width: _borderWidth),
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Text('الدرجة:', style: pw.TextStyle(font: boldFont, fontSize: 9.5)),
          ),
        ],
      ),
    );
  }
}
