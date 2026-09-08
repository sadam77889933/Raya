import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/entities/certificate_font_family.dart';
import '../../domain/entities/certificate_render_data.dart';
import '../../domain/entities/certificate_template.dart';
import '../../domain/entities/certificate_template_layout.dart';

/// محرِّك رسم واحد مُشترَك لكل القوالب الأساسية دون استثناء: يرسم صورة
/// الخلفية كاملة الصفحة، ثم يغطي أي مناطق في [eraseRegions] بمستطيل
/// مصمت (أداة "مسح نص من القالب" العامة — يُخفي نصاً مطبوعاً ضمن صورة
/// الخلفية نفسها دون تعديل ملف الصورة الأصلي)، ثم يضع فوقها نص كل حقل في
/// [fields] بموضعه المحسوب (بخطه المخصَّص من [regularFonts]/[boldFonts]
/// — القسم ١٣ من تصميم الميزة)، ثم أي عناصر نص حرّ في [customTexts] (لا
/// حقل بيانات مرتبط بها، نص وموضع حرّان بالكامل)، ثم يرسم صورة الختم (إن
/// وُجدت) فوق موضعها.
///
/// لا حاجة لملف رسم منفصل لكل قالب — فقط بيانات مواضع + صورة، بالضبط كما
/// هو موثَّق في تصميم الميزة (القسم ٣-أ).
pw.Widget buildGenericCertificatePage({
  required pw.MemoryImage backgroundImage,
  required List<CertificateFieldPosition> fields,
  required CertificateRenderData recipient,
  required Map<CertificateFontFamily, pw.Font> regularFonts,
  required Map<CertificateFontFamily, pw.Font> boldFonts,
  CertificateStampPosition? stampPosition,
  pw.MemoryImage? stampImage,
  List<CertificateEraseRegion> eraseRegions = const [],
  List<CertificateCustomTextElement> customTexts = const [],
  required double pageWidth,
  required double pageHeight,
}) {
  final children = <pw.Widget>[
    pw.Positioned(
      left: 0,
      top: 0,
      child: pw.SizedBox(
        width: pageWidth,
        height: pageHeight,
        child: pw.Image(backgroundImage, fit: pw.BoxFit.fill),
      ),
    ),
  ];

  // مناطق تغطية النص المطبوع ضمن صورة الخلفية — تُرسَم مباشرة فوق الخلفية
  // وقبل أي حقل/نص آخر، حتى تبقى الحقول والنصوص الحرة مرئية فوقها لو
  // وُضعت عمداً في نفس المكان.
  for (final r in eraseRegions) {
    final boxWidth = r.width * pageWidth;
    final boxHeight = r.height * pageHeight;
    children.add(
      pw.Positioned(
        left: (r.dx * pageWidth) - (boxWidth / 2),
        top: (r.dy * pageHeight) - (boxHeight / 2),
        child: pw.Container(
          width: boxWidth,
          height: boxHeight,
          color: PdfColor.fromInt(r.colorValue),
        ),
      ),
    );
  }

  for (final f in fields) {
    final value = _resolveFieldValue(f.field, recipient);
    if (value == null || value.trim().isEmpty) continue;

    final boxWidth = f.maxWidthRatio * pageWidth;
    final boxHeight = f.fontSize * 1.8;
    final left = (f.dx * pageWidth) - (boxWidth / 2);
    final top = (f.dy * pageHeight) - (boxHeight / 2);

    // حقول تأتي مباشرة بعد تسمية ثابتة على نفس السطر (مثل "مدرسة" قبل
    // اسم الدار، و"بجامع" قبل اسم المسجد) يجب أن تُحاذى إلى يمين صندوقها
    // لا أن تُتوسَّط: القيمة القصيرة تلتصق بالتسمية المجاورة بلا فراغ
    // ظاهر، والقيمة الطويلة تنمو يساراً داخل الفراغ الفعلي المتاح بدل أن
    // تتمدد بالتساوي في الاتجاهين وتصطدم بالتسمية. الحقول الأخرى (كاسم
    // المستفيدة) تقع على سطر مستقل متماثل فلا تحتاج هذا التعديل.
    //
    // FittedBox+scaleDown يبقى شبكة أمان: يصغّر الخط تلقائياً فقط عند
    // الحاجة (اسم طويل جداً حتى بعد توسيع الصندوق) بلا أي قياس يدوي.
    final needsRightAlign = f.field == CertificateField.schoolName ||
        f.field == CertificateField.mosqueName;

    // الخطوط الزخرفية الثلاثة الجديدة (Mirza / Katibeh / Lalezar)
    // خطوط عرض بوزن واحد فقط، فلا نسخة عريضة لها — إن طُلب وزن عريض لخط
    // لا يملكه، نرتدّ تلقائياً لنسخته العادية بدل رمي خطأ أو رسم بخط آخر.
    final resolvedFont = (f.bold ? boldFonts[f.fontFamily] : null) ??
        regularFonts[f.fontFamily] ??
        regularFonts[CertificateFontFamily.amiri]!;

    final textWidget = pw.FittedBox(
      fit: pw.BoxFit.scaleDown,
      child: pw.Text(
        value,
        textDirection: pw.TextDirection.rtl,
        textAlign: pw.TextAlign.center,
        maxLines: 1,
        overflow: pw.TextOverflow.clip,
        style: pw.TextStyle(
          font: resolvedFont,
          fontSize: f.fontSize,
          color: f.color,
        ),
      ),
    );

    children.add(
      pw.Positioned(
        left: left,
        top: top,
        child: pw.SizedBox(
          width: boxWidth,
          height: boxHeight,
          child: needsRightAlign
              ? pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: textWidget,
                )
              : pw.Center(child: textWidget),
        ),
      ),
    );
  }

  // عناصر النص الحرّ: بلا حقل بيانات مرتبط، فتُرسَم بمحاذاة وسط بسيطة
  // دائماً (بخلاف بعض الحقول الثابتة أعلاه التي تحتاج محاذاة يمين خاصة).
  //
  // مهم: النص هنا قد يمتد لأكثر من سطر (فاصل أسطر يدوي "\n" من المستخدم
  // عبر محرِّر متعدد الأسطر، أو التفاف تلقائي لسطر طويل يفوق عرض
  // الصندوق) — لذا لا نفرض `maxLines: 1` كما كان سابقاً. فرض سطر واحد مع
  // صندوق بعرض ثابت كان يُلغي أي تكبير لحجم الخط فعلياً لأي نص طويل بما
  // يكفي ليحتاج تصغيراً: عرضه الطبيعي بسطر واحد يتمدد مع حجم الخط، فمقياس
  // `FittedBox` (عرض الصندوق ÷ العرض الطبيعي) يتقلّص بنفس النسبة تماماً،
  // فيُلغي أحدهما الآخر رياضياً ويبقى الحجم المرسوم فعلياً ثابتاً مهما
  // كبَّرت `fontSize` — وهذا بالضبط ما لاحظته المستخدمة (لم يتغيّر شيء عند
  // رفع الحجم من ٢٤ إلى ٦٨ لنص طويل). بالسماح بالالتفاف لعدة أسطر وحساب
  // ارتفاع الصندوق تبعاً لعدد الأسطر الفعلي المقدَّر، يبقى حجم الخط
  // المُهيّأ هو ما يُرسَم فعلاً، و`FittedBox` يبقى فقط شبكة أمان نادرة
  // الاستخدام (نص طويل جداً حتى بعد الالتفاف على الأسطر المتاحة).
  const customTextMaxWidthRatio = 0.6;
  for (final t in customTexts) {
    if (t.text.trim().isEmpty) continue;

    final boxWidth = customTextMaxWidthRatio * pageWidth;
    final boxHeight =
        _estimateCustomTextBoxHeight(t.text, t.fontSize, boxWidth);
    final left = (t.dx * pageWidth) - (boxWidth / 2);
    final top = (t.dy * pageHeight) - (boxHeight / 2);

    final resolvedFont = regularFonts[t.fontFamily] ??
        regularFonts[CertificateFontFamily.amiri]!;

    children.add(
      pw.Positioned(
        left: left,
        top: top,
        child: pw.SizedBox(
          width: boxWidth,
          height: boxHeight,
          child: pw.Center(
            child: pw.FittedBox(
              fit: pw.BoxFit.scaleDown,
              child: pw.SizedBox(
                width: boxWidth,
                child: pw.Text(
                  t.text,
                  textDirection: pw.TextDirection.rtl,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    font: resolvedFont,
                    fontSize: t.fontSize,
                    color: t.fontColorValue != null
                        ? PdfColor.fromInt(t.fontColorValue!)
                        : PdfColors.black,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  if (stampPosition != null && stampImage != null) {
    final stampWidth = stampPosition.widthRatio * pageWidth;
    // نحافظ على نسبة أبعاد صورة الختم الأصلية بدل تشويهها إلى مربع.
    // أبعاد MemoryImage قد تكون null نظرياً حسب توقيع النوع، فنفترض
    // مربعاً (نسبة ١) فقط في تلك الحالة الاستثنائية غير المتوقعة عملياً.
    final imgWidth = stampImage.width;
    final imgHeight = stampImage.height;
    final aspect = (imgWidth != null && imgHeight != null && imgHeight > 0)
        ? imgWidth / imgHeight
        : 1.0;
    final stampHeight = stampWidth / aspect;
    children.add(
      pw.Positioned(
        left: (stampPosition.dx * pageWidth) - (stampWidth / 2),
        top: (stampPosition.dy * pageHeight) - (stampHeight / 2),
        child: pw.SizedBox(
          width: stampWidth,
          height: stampHeight,
          child: pw.Image(stampImage, fit: pw.BoxFit.contain),
        ),
      ),
    );
  }

  return pw.Stack(children: children);
}

/// يقدِّر ارتفاع الصندوق اللازم لعنصر نص حرّ بعد السماح له بالالتفاف على
/// عدة أسطر (بدل الافتراض القديم بسطر واحد `fontSize * 1.8` دائماً) —
/// يجمع بين أسطر المستخدم اليدوية (فاصل "\n") وتقدير تقريبي لعدد أسطر
/// الالتفاف التلقائي لكل سطر يدوي يفوق طوله عرض الصندوق عند [fontSize]
/// المُعطى (بمتوسط عرض حرف تقريبي، إذ لا تتوفر هنا قياس دقيق لعرض نص
/// حقيقي كما في محرّك عرض Flutter نفسه).
///
/// تقدير تقريبي بقصد لا دقيق: الهدف تفادي حاجة `FittedBox` لتصغير النص
/// (وبالتالي حجم الخط المُهيّأ) حين يكون التقدير صحيحاً أو أعلى قليلاً من
/// الحقيقة، فهامش أمان بسيط (×1.15) أفضل من نقصان التقدير الذي يعيد
/// نفس مشكلة التصغير غير المرغوب فيها من جديد.
double _estimateCustomTextBoxHeight(
    String text, double fontSize, double boxWidth) {
  const avgCharWidthFactor = 0.55;
  final avgCharWidth = fontSize * avgCharWidthFactor;
  final rawCharsPerLine =
      avgCharWidth > 0 ? (boxWidth / avgCharWidth).floor() : 1;
  final charsPerLine = rawCharsPerLine < 1 ? 1 : rawCharsPerLine;

  var totalLines = 0;
  for (final hardLine in text.split('\n')) {
    final len = hardLine.trim().isEmpty ? 1 : hardLine.length;
    final wrapped = (len / charsPerLine).ceil();
    totalLines += wrapped < 1 ? 1 : wrapped;
  }
  if (totalLines < 1) totalLines = 1;

  const lineHeightFactor = 1.35;
  const safetyMargin = 1.15;
  return totalLines * fontSize * lineHeightFactor * safetyMargin;
}

String? _resolveFieldValue(
    CertificateField field, CertificateRenderData recipient) {
  switch (field) {
    case CertificateField.recipientName:
      return recipient.recipientName;
    case CertificateField.mosqueName:
      return recipient.mosqueName;
    case CertificateField.schoolName:
      return recipient.schoolName;
    case CertificateField.circleName:
      return recipient.circleName;
    case CertificateField.teacherName:
      return recipient.teacherName;
    case CertificateField.supervisorName:
      return recipient.supervisorName;
    case CertificateField.date:
      return recipient.date;
    case CertificateField.academicYear:
      return recipient.academicYear;
    case CertificateField.certificateType:
      return recipient.certificateType;
  }
}
