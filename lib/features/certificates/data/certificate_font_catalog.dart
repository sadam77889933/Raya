import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

import '../domain/entities/certificate_font_family.dart';

/// يحمِّل كل خطوط قوالب الشهادات المُجمَّعة (القسم ١٣ من تصميم الميزة)
/// كـ`pw.Font` جاهزة للاستخدام مباشرة في `pdf`، بمعزل تام عن أي منطق
/// عرض — نقطة مصدر واحدة لمسارات ملفات الخطوط، تُستخدَم من مولّد الـPDF
/// فقط.
///
/// وزن عريض (Bold) متوفر فقط لـ`Amiri`/`Tajawal` (الخطان الأصليان)؛
/// الخطوط الزخرفية الأربعة الأخرى خطوط عرض (Display) بطابع بصري ثابت
/// أصلاً، فلا تحتاج وزناً عريضاً منفصلاً — أي طلب لوزن عريض لخط غير
/// متوفر له يرتدّ تلقائياً إلى نسخته العادية (انظر
/// `certificate_generic_template_renderer.dart`).
///
/// ملاحظة مهمة: كل خط جديد يُضاف هنا **يجب** أن يحتوي تغطية لـ"أشكال
/// العرض العربية" (Arabic Presentation Forms، النطاقان U+FB50–FDFF
/// وU+FE70–FEFF) — مكتبة `pdf` هنا لا تُشكِّل النص عبر GSUB كما يفعل
/// محرّك عرض Flutter نفسه، بل تحوّله يدوياً إلى رموز هذه النطاقات
/// وتبحث عنها مباشرة في الخط؛ خط بلا هذه التغطية (كثير من خطوط
/// Google Fonts الحديثة المصمَّمة لمحرّكات HarfBuzz فقط) يُنتج ارتفاع/
/// عرض صفري للنص فيُسقِط استثناء `height > 0.0` من
/// `package:pdf/src/widgets/geometry.dart` عند التوليد الفعلي. `NotoKufiArabic`
/// أدناه فُحص فعلياً (فحص تغطية رموز حقيقي على ملف الخط قبل تجميعه في
/// التطبيق) ونجح بامتياز — تغطية ٩٨٪ تقريباً من `U+FE70–FEFF` و٩١٪ من
/// `U+FB50–FDFF`، بنفس مستوى (أو أفضل من) `Mirza`/`Katibeh` الشغّالين
/// فعلاً؛ بينما مرشَّحات أخرى (كوفي/رقعة/فارسي Nastaliq حقيقي) فشلت هذا
/// الفحص بالضبط ولذلك لم تُضَف.
class CertificateFontCatalog {
  static const Map<CertificateFontFamily, String> _regularAssets = {
    CertificateFontFamily.amiri: 'assets/fonts/Amiri-Regular.ttf',
    CertificateFontFamily.tajawal: 'assets/fonts/Tajawal-Regular.ttf',
    CertificateFontFamily.mirza: 'assets/fonts/Mirza-Regular.ttf',
    CertificateFontFamily.katibeh: 'assets/fonts/Katibeh-Regular.ttf',
    CertificateFontFamily.lalezar: 'assets/fonts/Lalezar-Regular.ttf',
    CertificateFontFamily.notoKufiArabic:
        'assets/fonts/NotoKufiArabic-Regular.ttf',
  };

  static const Map<CertificateFontFamily, String> _boldAssets = {
    CertificateFontFamily.amiri: 'assets/fonts/Amiri-Bold.ttf',
    CertificateFontFamily.tajawal: 'assets/fonts/Tajawal-Bold.ttf',
  };

  static Future<Map<CertificateFontFamily, pw.Font>> loadRegular() async {
    final result = <CertificateFontFamily, pw.Font>{};
    for (final entry in _regularAssets.entries) {
      final data = await rootBundle.load(entry.value);
      result[entry.key] = pw.Font.ttf(data);
    }
    return result;
  }

  static Future<Map<CertificateFontFamily, pw.Font>> loadBold() async {
    final result = <CertificateFontFamily, pw.Font>{};
    for (final entry in _boldAssets.entries) {
      final data = await rootBundle.load(entry.value);
      result[entry.key] = pw.Font.ttf(data);
    }
    return result;
  }
}
