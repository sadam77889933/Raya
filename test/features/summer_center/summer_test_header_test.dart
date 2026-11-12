import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:quran_circle_report/features/summer_center/data/summer_test_header.dart';

/// أقصى حصة مطلوبة للترويسة المدمجة من ارتفاع الصفحة.
const double _maxHeaderShare = 0.20;

// صورة PNG بحجم بكسل واحد تكفي لاختبار مكان الشعار في التخطيط.
final Uint8List _logoBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

pw.Font _font(String file) {
  final bytes = File('assets/fonts/$file').readAsBytesSync();
  return pw.Font.ttf(ByteData.view(Uint8List.fromList(bytes).buffer));
}

SummerTestHeaderData _data({
  String teacherName = 'فاطمة محمد علي',
  String title = 'الاختبار النهائي',
  List<String> rightLines = const [
    'مجمع آيات بينات لتعليم القرآن',
    'الكريم وعلومه',
    'شبوة- عتق',
  ],
  List<String> leftLines = const ['القرآن الكريم والعلوم الشرعية', 'قسم النساء'],
  bool withLogo = true,
}) {
  return SummerTestHeaderData(
    title: title,
    subjectName: 'العلوم الشرعية',
    levelName: 'المستوى الثاني',
    teacherName: teacherName,
    dateLabel: 'ربيع الآخر 1448هـ',
    centerName: 'المركز الصيفي',
    mosqueName: 'جامع الرحمة',
    rightLines: rightLines,
    leftLines: leftLines,
    logo: withLogo ? pw.MemoryImage(_logoBytes) : null,
  );
}

/// يخطّط الترويسة فعلياً داخل صفحة A4 بنفس الهامش واتجاه RTL كما في المولّد،
/// ويُرجع ارتفاعها بوحدة pt.
Future<double> _measureHeaderHeight(SummerTestHeaderData data) async {
  final font = _font('Amiri-Regular.ttf');
  final boldFont = _font('Amiri-Bold.ttf');
  double? height;

  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      textDirection: pw.TextDirection.rtl,
      theme: pw.ThemeData.withFont(base: font, bold: boldFont),
      build: (context) {
        final header = SummerTestCompactHeader.build(
          data: data,
          font: font,
          boldFont: boldFont,
        );
        header.layout(
          context,
          pw.BoxConstraints(maxWidth: PdfPageFormat.a4.width - 72),
        );
        height = header.box!.height;
        return pw.SizedBox();
      },
    ),
  );
  await doc.save();
  return height!;
}

void main() {
  group('الترويسة المدمجة لورقة الاختبار', () {
    final maxHeight = PdfPageFormat.a4.height * _maxHeaderShare;

    test('لا تتجاوز 20% من ارتفاع الصفحة ببيانات عادية', () async {
      final height = await _measureHeaderHeight(_data());
      expect(height, lessThanOrEqualTo(maxHeight));
    });

    test('تبقى ضمن الحد نفسه بلا شعار وبلا نص أيسر', () async {
      final height = await _measureHeaderHeight(
        _data(withLogo: false, leftLines: const []),
      );
      expect(height, lessThanOrEqualTo(maxHeight));
    });

    test('تبقى ضمن الحد نفسه مع نصوص طويلة تلتف على أكثر من سطر', () async {
      final height = await _measureHeaderHeight(
        _data(
          teacherName: 'فاطمة عبد الله محمد أحمد الحداد السقاف',
          title: 'الاختبار النهائي للفصل الدراسي الثاني من العام الدراسي الجديد',
          rightLines: const [
            'مجمع آيات بينات لتعليم القرآن الكريم وعلومه التابع لجمعية الإحسان الخيرية',
            'شبوة- عتق',
          ],
        ),
      );
      expect(height, lessThanOrEqualTo(maxHeight));
    });
  });

  group('أسطر نص الترويسة', () {
    test('تُفصل بالسطر الجديد وتُقصّ المسافات وتُحذف الأسطر الفارغة', () {
      expect(
        SummerTestHeaderData.splitLines('  مجمع آيات  \n\n  شبوة- عتق \n'),
        ['مجمع آيات', 'شبوة- عتق'],
      );
    });

    test('النص null أو الفارغ يعطي قائمة فارغة', () {
      expect(SummerTestHeaderData.splitLines(null), isEmpty);
      expect(SummerTestHeaderData.splitLines(''), isEmpty);
    });
  });
}
