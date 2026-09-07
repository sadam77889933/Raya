import 'package:pdf/pdf.dart';

import 'certificate_batch.dart';
import 'certificate_font_family.dart';

/// حقل نصي ديناميكي يمكن أن يظهر داخل قالب شهادة.
///
/// القائمة مفتوحة لتغطية قوالب مستقبلية قد لا يستخدم كل منها كل الحقول —
/// كل قالب يُصرِّح فقط بما يحتاجه فعلياً عبر [CertificateFieldPosition].
enum CertificateField {
  recipientName,
  mosqueName,
  schoolName,
  circleName,
  teacherName,
  supervisorName,
  date,
  academicYear,
  certificateType,
}

/// موضع حقل نصي واحد فوق خلفية القالب — نسخة "ثابتة" مبسَّطة من
/// `CertificateFieldLayout` المرحلة اللاحقة (محرر مواضع الحقول)، بلا أي
/// قابلية تحرير من المستخدم في المرحلة الأولى: القيم مضبوطة في الكود.
class CertificateFieldPosition {
  final CertificateField field;

  /// نسبة أفقية 0.0–1.0 من عرض صورة الخلفية (مركز النص).
  final double dx;

  /// نسبة رأسية 0.0–1.0 من ارتفاع صورة الخلفية (مركز النص).
  final double dy;

  final double fontSize;
  final PdfColor color;
  final bool bold;

  /// نوع الخط — افتراضياً `Amiri` ليطابق تماماً سلوك كل القوالب الأساسية
  /// الحالية قبل إضافة تخصيص الخط (القسم ١٣)؛ لا حاجة لتعديل أي تعريف
  /// قالب موجود عند إضافة هذا الحقل بفضل القيمة الافتراضية.
  final CertificateFontFamily fontFamily;

  /// نسبة أقصى عرض لصندوق النص (من عرض صورة الخلفية) المُتمركِز حول
  /// [dx] — يُستخدَم لتوسيط النص أفقياً حول نقطة الموضع بدل قياس عرض
  /// النص الفعلي (حزمة pdf لا تُتيح ذلك مسبقاً قبل الرسم).
  final double maxWidthRatio;

  const CertificateFieldPosition({
    required this.field,
    required this.dx,
    required this.dy,
    required this.fontSize,
    this.color = PdfColors.black,
    this.bold = false,
    this.fontFamily = CertificateFontFamily.amiri,
    this.maxWidthRatio = 0.35,
  });
}

/// موضع ختم المسجد (صورة، لا نص) فوق خلفية القالب — اختياري، فبعض
/// القوالب المستقبلية قد لا تعرض ختماً إطلاقاً.
class CertificateStampPosition {
  /// نسبة أفقية 0.0–1.0 من عرض صورة الخلفية (مركز الختم).
  final double dx;

  /// نسبة رأسية 0.0–1.0 من ارتفاع صورة الخلفية (مركز الختم).
  final double dy;

  /// نسبة عرض الختم من عرض صورة الخلفية، للحفاظ على تناسب الحجم.
  final double widthRatio;

  const CertificateStampPosition({
    required this.dx,
    required this.dy,
    required this.widthRatio,
  });
}

/// تعريف قالب شهادة أساسي (مُجمَّع داخل التطبيق كـAsset، وليس بيانات
/// Firestore) — صورة خلفية كاملة الصفحة + حقول نص حقيقية وختم اختياري
/// فوقها، بلا أي إعادة رسم بالكود مهما كان القالب مزخرفاً.
///
/// القائمة الكاملة لكل القوالب الأساسية المتاحة تعيش في
/// `certificate_template_registry.dart` كقائمة مفتوحة — إضافة قالب جديد
/// لاحقاً تعني فقط: صورة خلفية جديدة + مصغّرة + هذا التعريف، بلا أي لمس
/// لباقي الميزة.
class CertificateTemplateDefinition {
  final String id;
  final String displayName;

  /// المسار داخل assets/images/certificate_templates/ لصورة الخلفية
  /// كاملة الصفحة (بأعلى دقة متاحة).
  final String backgroundImageAsset;

  /// نسخة مصغّرة من نفس الصورة، لبطاقة الاختيار في الواجهة فقط.
  final String thumbnailAsset;

  /// نوع المستفيد الذي صُمِّم هذا القالب من أجله — بعض القوالب (كهذا
  /// القالب تحديداً) مكتوبة بصياغة نصّية خاصة بنوع واحد فقط (كالمؤنث)،
  /// فلا يصح عرضها لنوع آخر.
  final CertificateRecipientType recipientType;

  final List<CertificateFieldPosition> fixedFields;

  /// موضع ختم المسجد، أو null إن كان القالب لا يعرض ختماً إطلاقاً.
  final CertificateStampPosition? stampPosition;

  /// المسار المحلي (على جهاز المشرفة) لصورة خلفية قالب **مستورَد** — القسم
  /// ٦ من تصميم الميزة (استيراد قوالب). `null` لكل القوالب الأساسية
  /// المُجمَّعة كـAssets داخل التطبيق؛ يُضبَط فقط لقالب مُصنَّع وقت التشغيل
  /// من `ImportedCertificateTemplate.toDefinition()` واحد.
  ///
  /// عند عدم NULL: كل مكان يحمِّل صورة خلفية القالب (بطاقة العرض، قماشة
  /// محرر مواضع الحقول، ومولّد الـPDF) يقرأ الصورة من هذا المسار عبر
  /// `dart:io File` بدل `rootBundle`/`backgroundImageAsset` — القيمة
  /// الأخيرة تبقى فارغة وغير مُستخدَمة في هذه الحالة.
  final String? localBackgroundImagePath;

  const CertificateTemplateDefinition({
    required this.id,
    required this.displayName,
    required this.backgroundImageAsset,
    required this.thumbnailAsset,
    required this.recipientType,
    required this.fixedFields,
    this.stampPosition,
    this.localBackgroundImagePath,
  });
}

/// موضع افتراضي معقول لحقل لا يملك أي موضع مُعرَّف مسبقاً في `fixedFields`
/// الخاصة بقالبه — يحدث هذا في حالتين فقط: (أ) حقل أضافته المشرفة يدوياً
/// عبر زر "إضافة حقل" في محرر مواضع الحقول (القسم ٦، دفعة الحقول
/// اليدوية)، أو (ب) أي حقل مماثل ضمن قالب **مستورَد** لا يملك `fixedFields`
/// إطلاقاً (قائمة فارغة دائماً — انظر `ImportedCertificateTemplate.
/// toDefinition`). مصدر معرفة واحد يستخدمه كل من محرر مواضع الحقول
/// (معاينة + إعادة ضبط) ومولّد الـPDF (`_mergeFieldPositions`) معاً، حتى
/// لا تختلف المعاينة عن الناتج الفعلي أبداً لأي حقل مُضاف يدوياً.
CertificateFieldPosition defaultFieldPosition(CertificateField field) {
  return CertificateFieldPosition(
    field: field,
    dx: 0.5,
    dy: 0.5,
    fontSize: 24,
    color: PdfColors.black,
    maxWidthRatio: 0.5,
  );
}
