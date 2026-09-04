import 'package:pdf/pdf.dart';

import '../../domain/entities/certificate_batch.dart';
import '../../domain/entities/certificate_template.dart';

/// قائمة مفتوحة بكل القوالب الأساسية المتاحة في التطبيق — تبدأ بعنصر
/// واحد فقط عند إطلاق المرحلة الأولى (قالب "شهادة شكر" الذي اعتمدته
/// المستخدمة). إضافة قالب أساسي جديد لاحقاً (بما فيها نسخة للمعلمات) لا
/// تحتاج أي تعديل على أي شاشة أو منطق آخر في الميزة — فقط صورة خلفية +
/// مصغّرة جديدتان + عنصر جديد هنا.
///
/// لون الحبر التقريبي المستخدَم في تصميم الشهادة نفسها (رمادي-بنّي داكن)،
/// لمطابقة النصوص المُضافة برمجياً مع النص الثابت المطبوع على الصورة.
const PdfColor _inkColor = PdfColor(0.2902, 0.2392, 0.2588); // #4A3D42

final List<CertificateTemplateDefinition> certificateTemplateRegistry = [
  CertificateTemplateDefinition(
    id: 'thanks_certificate_student',
    displayName: 'شهادة شكر — طالبات',
    backgroundImageAsset:
        'assets/images/certificate_templates/thanks_certificate_student_bg.png',
    thumbnailAsset:
        'assets/images/certificate_templates/thanks_certificate_student_thumb.png',
    recipientType: CertificateRecipientType.student,
    fixedFields: const [
      // الفراغ بعد "مدرسة" — اسم الدار
      // ملاحظة مهمة: dy: 0.510 (محاولة سابقة) كانت خطأ — القياس على
      // الشهادة الفعلية أثبت أن dy: 0.458 الأصلية كانت مُحاذاة بشكل صحيح
      // فعلاً مع سطر "يسر مدرسة"، والمشكلة الوحيدة كانت صِغَر الخط لا
      // موضعه. رفع dy زاد الأمر سوءاً (تداخل مع السطر التالي)، فأُعيد
      // لقيمته الصحيحة وبقي تكبير الخط فقط.
      //
      // تحديث لاحق مع القالب الجديد (بعد توسعة المسافة بين "بجامع"
      // و"مدرسة"): dx وmaxWidthRatio أُعيد حسابهما هندسياً بدل التخمين.
      // الفراغ الفعلي المتاح لاسم المدرسة محصور بين نهاية "بجامع" (يمين)
      // ونهاية "مدرسة" (يسار) — قِيس بدقة بالبكسل على الصورة الجديدة:
      // يمتد من نسبة 0.343 إلى 0.6325 من عرض الصورة. اعتُمد صندوق بعرض
      // هذا الفراغ كاملاً (ناقص هامش أمان صغير) مع محاذاة النص إلى يمين
      // الصندوق بدل توسيطه (انظر المحرِّك): القيمة القصيرة تلتصق بكلمة
      // "مدرسة" مباشرة، والطويلة تنمو يساراً داخل كامل الفراغ الحقيقي
      // بدل الاصطدام بالتسمية من الجهتين كما كان يحدث مع التوسيط.
      CertificateFieldPosition(
        field: CertificateField.schoolName,
        dx: 0.487,
        dy: 0.458,
        fontSize: 20,
        color: _inkColor,
        bold: true,
        maxWidthRatio: 0.27,
      ),
      // الفراغ بعد "بجامع" — اسم المسجد (نفس سطر اسم المدرسة أعلاه)
      // نفس منهج القياس أعلاه: "بجامع" ينتهي (يسار الكلمة) عند نسبة
      // 0.28، والفراغ يمتد يساراً حتى حافة الإطار الزخرفي الآمنة قرب
      // نسبة 0.045. الصندوق بعرض هذا الفراغ كاملاً مع محاذاة يمين، بنفس
      // منطق اسم المدرسة أعلاه.
      CertificateFieldPosition(
        field: CertificateField.mosqueName,
        dx: 0.16,
        dy: 0.458,
        fontSize: 20,
        color: _inkColor,
        bold: true,
        maxWidthRatio: 0.22,
      ),
      // السطر المنقّط بعد "هذه الشهادة لـطالبة/" — اسم الطالبة
      // كانت dy: 0.577 تتقاطع مع النقاط، ورفعها إلى 0.625 (المحاولة
      // السابقة) كان خطأً في الاتجاه — dy الأكبر يعني موضعاً أسفل الصفحة
      // لا أعلاها، فتداخل مع فقرة "على إتمامها..." تحتها. الاتجاه الصحيح
      // لرفع النص فوق النقاط هو تصغير dy لا تكبيره.
      CertificateFieldPosition(
        field: CertificateField.recipientName,
        dx: 0.50,
        dy: 0.545,
        fontSize: 26,
        color: _inkColor,
        bold: true,
        maxWidthRatio: 0.60,
      ),
    ],
    // تحت "مشرفة المدرسة:" مباشرة — يُقرأ من Mosque.stampBase64
    stampPosition: const CertificateStampPosition(
      dx: 0.26,
      dy: 0.855,
      widthRatio: 0.09,
    ),
  ),
  // قالب "شهادة تقدير" الخاص بالمعلمات — نفس منهج القياس بالبكسل
  // المعتمَد أعلاه لقالب الطالبات، مطبَّق على تصميم قالب المعلمات
  // الجديد (تخطيط مختلف قليلاً: اسم الدار واسم المسجد على سطر أعلى من
  // اسم المستفيدة، لا على نفس السطر كما في قالب الطالبات).
  CertificateTemplateDefinition(
    id: 'thanks_certificate_teacher',
    displayName: 'شهادة تقدير — معلمات',
    backgroundImageAsset:
        'assets/images/certificate_templates/thanks_certificate_teacher_bg.png',
    thumbnailAsset:
        'assets/images/certificate_templates/thanks_certificate_teacher_thumb.png',
    recipientType: CertificateRecipientType.teacher,
    fixedFields: const [
      // اسم الدار
      CertificateFieldPosition(
        field: CertificateField.schoolName,
        dx: 0.4605,
        dy: 0.362,
        fontSize: 20,
        color: _inkColor,
        bold: true,
        maxWidthRatio: 0.28,
      ),
      // اسم المسجد
      CertificateFieldPosition(
        field: CertificateField.mosqueName,
        dx: 0.167,
        dy: 0.362,
        fontSize: 20,
        color: _inkColor,
        bold: true,
        maxWidthRatio: 0.15,
      ),
      // اسم المعلمة المستفيدة
      CertificateFieldPosition(
        field: CertificateField.recipientName,
        dx: 0.50,
        dy: 0.4674,
        fontSize: 24,
        color: _inkColor,
        bold: true,
        maxWidthRatio: 0.50,
      ),
    ],
    stampPosition: const CertificateStampPosition(
      dx: 0.371,
      dy: 0.8465,
      widthRatio: 0.09,
    ),
  ),
];

/// القوالب المتاحة لنوع مستفيد معيّن فقط — تُستخدم في خطوة اختيار القالب
/// بالمعالج، حتى لا يظهر قالب مكتوب بصياغة غير مناسبة لنوع المستفيد
/// المختار.
List<CertificateTemplateDefinition> certificateTemplatesFor(
    CertificateRecipientType recipientType) {
  return certificateTemplateRegistry
      .where((t) => t.recipientType == recipientType)
      .toList();
}

CertificateTemplateDefinition? certificateTemplateById(String id) {
  for (final t in certificateTemplateRegistry) {
    if (t.id == id) return t;
  }
  return null;
}
